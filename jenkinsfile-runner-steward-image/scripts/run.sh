#!/bin/bash
set -eu -o pipefail

HERE=$(cd "$(dirname "$BASH_SOURCE")" && pwd) || {
  echo >&2 "error: failed to determine script location"
  exit 1
}
declare -r HERE

declare -r PARAM_VARS_MANDATORY=(
  'PIPELINE_GIT_URL'
  'PIPELINE_GIT_REVISION'
  'PIPELINE_FILE'
  'PIPELINE_PARAMS_JSON'
  'RUN_NAMESPACE'
)

declare -r PARAM_VARS_OPTIONAL=(
  'PIPELINE_LOG_ELASTICSEARCH_INDEX_URL'
  'PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET'
  'PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET'
  'PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON'
  'PIPELINE_LOG_FLUENTD_HOST'
  'PIPELINE_LOG_FLUENTD_PORT'
  'PIPELINE_LOG_FLUENTD_TAG'
  'JOB_NAME'
  'RUN_NUMBER'
  'RUN_CAUSE'
  'TERMINATION_LOG_PATH'
)

declare -r _JENKINS_APP_DIR="/app/jenkins"
declare -r _JENKINS_CASC_D="${_JENKINS_APP_DIR}/WEB-INF/jenkins.yaml.d"
declare -r _JENKINS_HOME="/jenkins_home"

declare -r TERMINATION_LOG_PATH=${TERMINATION_LOG_PATH:-/run/termination-log}


function main() {
  local -r casc_yml="${_JENKINS_CASC_D}/casc.yml"
  local -r build_xml="${_JENKINS_HOME}/jobs/${JOB_NAME:-job}/builds/${RUN_NUMBER:-1}/build.xml"
  local host_addr
  host_addr=$(get_host_addr)
  truncate -c -s 0 "${TERMINATION_LOG_PATH}"
  check_required_env_vars "${PARAM_VARS_MANDATORY[@]}"

  echo "Cloning pipeline repository $PIPELINE_GIT_URL"
  with_termination_log git clone "$PIPELINE_GIT_URL" .
  echo "Checking out pipeline from revision $PIPELINE_GIT_REVISION"
  with_termination_log git checkout "$PIPELINE_GIT_REVISION"
  echo "Delete pipeline git clone credentials"
  with_termination_log rm -f ~/.git-credentials

  with_termination_log sed -i "s/0.0.0.0/$host_addr/g" "$casc_yml"
  with_termination_log sed -i "s/xxx/$RUN_NAMESPACE/" "$casc_yml"
  with_termination_log configure_log_elasticsearch

  with_termination_log mkdir -p "${_JENKINS_HOME}"

  export -n "${PARAM_VARS_MANDATORY[@]}" "${PARAM_VARS_OPTIONAL[@]}"  # do not pass to subprocesses
  local -a JFR_PIPELINE_PARAM_ARGS
  make_jfr_pipeline_param_args JFR_PIPELINE_PARAM_ARGS
  local jfr_err_log
  jfr_err_log=$(mktemp 'error-log-XXXXXX')

  export JAVA_OPTS="${JAVA_OPTS:+$JAVA_OPTS }-Dhudson.TcpSlaveAgentListener.hostName=$host_addr"

  # Temporary workaround for https://github.com/SAP/stewardci-jenkinsfilerunner-image/issues/62
  # Should be removed once the issue is fixed
  (
    ___LOCAL_BUILD_LOG_FILE_PATH="${_JENKINS_HOME}/jobs/${JOB_NAME:-job}/builds/${RUN_NUMBER:-1}/log"
    mkdir -p "$(dirname "$___LOCAL_BUILD_LOG_FILE_PATH")"
    touch "$___LOCAL_BUILD_LOG_FILE_PATH"
  )
  # End of workaround
  
  local jfr_cmd=(
    /app/bin/jenkinsfile-runner
      -w "$_JENKINS_APP_DIR"
      -p /usr/share/jenkins/ref/plugins
      --runHome "${_JENKINS_HOME}"
      --no-sandbox
      ${JOB_NAME:+--job-name "${JOB_NAME}"}
      ${RUN_NUMBER:+--build-number "${RUN_NUMBER}"}
      ${RUN_CAUSE:+--cause "${RUN_CAUSE}"}
      -f "$PIPELINE_FILE"
      "${JFR_PIPELINE_PARAM_ARGS[@]}"
  )
  local jfr_rc=0
  with_error_log "$jfr_err_log" "${jfr_cmd[@]}" || jfr_rc=$?
  if [[ ! -f $build_xml ]]; then
    log_failed_command_to_termination_log "$jfr_err_log" "$jfr_rc" "${jfr_cmd[@]}" || {
      echo >&2 "error: could not log failed command to termination log"
    }
    rm -f "$jfr_err_log" &> /dev/null || true
    exit 1
  fi
  rm -f "$jfr_err_log" &> /dev/null || true

  #TODO: Define proper exit codes
  #TODO: Do not rely on exit codes but return something more structured. E.g. copy builds folder out of container and evaluate further.
  local completed result
  completed=$(with_termination_log xmlstarlet sel -t -v /flow-build/completed "$build_xml")
  result=$(with_termination_log xmlstarlet sel -t -v /flow-build/result "$build_xml")
  if [[ $completed != "true" ]]; then
    echo "Pipeline not completed" | tee -a "${TERMINATION_LOG_PATH}" || true
    exit "$jfr_rc"
  fi
  if [[ ! $result ]]; then
    echo "No pipeline result in build.xml" | tee -a "${TERMINATION_LOG_PATH}" || true
    exit "$jfr_rc"
  fi
  echo "Pipeline completed with result: $result" | tee -a "${TERMINATION_LOG_PATH}" || true
  if [[ $result != "SUCCESS" ]]; then
    exit 1
  fi
  exit 0
}

function check_required_env_vars() {
  local rc=0 var
  for var in "$@"; do
    if [[ ! ${!var-} ]]; then
      message="error: environment variable not set or empty: $var"
      echo "$message" >&2
      echo "$message" >> "${TERMINATION_LOG_PATH}"
      rc=1
    fi
  done
  return "$rc"
}

function with_error_log() {
  local err_log=$1
  local cmd=("${@:2}")

  # use coprocess to capture error log stream to file
  coproc TEE_COPROC { exec tee -a "$err_log" >&2; }

  # we don't read stdout of TEE_COPROC -> close fd
  exec {TEE_COPROC[0]}<&- || { kill -s SIGKILL %; return 1; }

  # run command with stderr redirected to TEE_COPROC
  "${cmd[@]}" 2>&${TEE_COPROC[1]}
  local rc="$?"

  # EOF on TEE_COPROC's stdin
  exec {TEE_COPROC[1]}>&- || { kill -s SIGKILL %; return 1; }

  # wait until TEE_COPROC has terminated
  wait %

  return "$rc"
}

function with_termination_log() {
  local cmd=("$@")

  local tmp_err_log
  tmp_err_log=$(mktemp -t 'error-log-XXXXXX')

  # capture command's error stream while still writing to our stdout/strerr
  local rc=0
  with_error_log "$tmp_err_log" "${cmd[@]}" || rc=$?
  if [[ $rc != 0 ]]; then
    log_failed_command_to_termination_log "$tmp_err_log" "$rc" "${cmd[@]}" || {
      echo >&2 "error: could not log failed command to termination log"
    }
  fi
  rm -f "$tmp_err_log" &> /dev/null || true
  return "$rc"
}

function log_failed_command_to_termination_log() {
  local err_log=$1 rc=$2
  local cmd=("${@:3}")

  {
    echo "Command [${cmd[@]@Q}] failed with exit code $rc"
    echo "Error output:"
    cat "$err_log"
  } >> "${TERMINATION_LOG_PATH}"
}

function make_jfr_pipeline_param_args() {
  local -n dest_arr=$1  # alias to named target variable

  local tmp_arr=()
  local args_base64
  args_base64=$(
    with_termination_log \
        jq \
            --raw-output \
            'keys[] as $k | @base64 "\("-a")", @base64 "\($k + "=" + .[$k])"' \
    <<<"$PIPELINE_PARAMS_JSON"
  )
  if [[ $args_base64 ]]; then
    readarray -t tmp_arr <<<"$args_base64"
  fi
  dest_arr=()
  for val_base64 in "${tmp_arr[@]}"; do
    dest_arr+=( "$(base64 -d <<<"$val_base64")" )
  done
}

function configure_log_elasticsearch() {
  jq -n -S -f "${HERE}/elasticsearch-log-config.jq" \
      >"${_JENKINS_CASC_D}/log-elasticsearch.yml"
}

function get_host_addr() {
  hostname -i | sed -e '1!d; s/[[:space:]].*//'
}


main "$@"

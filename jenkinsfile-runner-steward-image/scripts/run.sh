#!/bin/bash
set -u -o pipefail

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
)

declare -r _JENKINS_APP_DIR="/app/jenkins"
declare -r _JENKINS_CASC_D="${_JENKINS_APP_DIR}/WEB-INF/jenkins.yaml.d"
declare -r _JENKINS_HOME="/jenkins_home"

# This is only usable with tekton 0.11.x if running in non root mode.
# See https://github.com/tektoncd/pipeline/issues/2131
#_TERMINATION_LOG_PATH="/tekton/results/termination-log"

declare -r _TERMINATION_LOG_PATH="/run/termination-log"


function main() {
  local -r casc_yml="${_JENKINS_CASC_D}/casc.yml"
  local -r build_xml="${_JENKINS_HOME}/jobs/${JOB_NAME:-job}/builds/${RUN_NUMBER:-1}/build.xml"

  truncate -c -s 0 "${_TERMINATION_LOG_PATH}" || exit 1
  check_required_env_vars "${PARAM_VARS_MANDATORY[@]}" || exit 1

  echo "Cloning pipeline repository $PIPELINE_GIT_URL"
  with_termination_log git clone "$PIPELINE_GIT_URL" . || exit 1
  echo "Checking out pipeline from revision $PIPELINE_GIT_REVISION"
  with_termination_log git checkout "$PIPELINE_GIT_REVISION" || exit 1
  echo "Delete pipeline git clone credentials"
  with_termination_log rm -f ~/.git-credentials || exit 1

  with_termination_log sed -i "s/0.0.0.0/$(hostname -i)/g" "$casc_yml" || exit 1
  with_termination_log sed -i "s/xxx/$RUN_NAMESPACE/" "$casc_yml" || exit 1
  with_termination_log configure_log_elasticsearch || exit 1

  with_termination_log mkdir -p "${_JENKINS_HOME}" || exit 1

  export -n "${PARAM_VARS_MANDATORY[@]}" "${PARAM_VARS_OPTIONAL[@]}" || exit 1 # do not pass to subprocesses
  local -a JFR_PIPELINE_PARAM_ARGS
  make_jfr_pipeline_param_args JFR_PIPELINE_PARAM_ARGS || exit 1
  local jfr_err_log
  jfr_err_log=$(mktempfile "error-" ".log") || exit 1

  export JAVA_OPTS="${JAVA_OPTS:+$JAVA_OPTS }-Dhudson.TcpSlaveAgentListener.hostName=$(hostname -i)"

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
  with_error_log "$jfr_err_log" "${jfr_cmd[@]}" || exit 1
  local jfr_rc=$?
  if [[ ! -f $build_xml ]]; then
    log_failed_command_to_termination_log "$jfr_err_log" "$jfr_rc" "${jfr_cmd[@]}" || {
      echo >&2 "error: could not log failed command to termination log"
    }
    rm -f "$jfr_err_log" &> /dev/null
    exit 1
  fi
  rm -f "$jfr_err_log" &> /dev/null

  #TODO: Define proper exit codes
  #TODO: Do not rely on exit codes but return something more structured. E.g. copy builds folder out of container and evaluate further.
  local completed result
  completed=$(with_termination_log xmlstarlet sel -t -v /flow-build/completed "$build_xml") || exit 1
  result=$(with_termination_log xmlstarlet sel -t -v /flow-build/result "$build_xml") || exit 1
  if [[ $completed != "true" ]]; then
    echo "Pipeline not completed" | tee -a "${_TERMINATION_LOG_PATH}"
    exit "$jfr_rc"
  fi
  if [[ ! $result ]]; then
    echo "No pipeline result in build.xml" | tee -a "${_TERMINATION_LOG_PATH}"
    exit "$jfr_rc"
  fi
  echo "Pipeline completed with result: $result" | tee -a "${_TERMINATION_LOG_PATH}"
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
      echo "$message" >> "${_TERMINATION_LOG_PATH}"
      rc=1
    fi
  done
  return "$rc"
}

function with_error_log() {
  local err_log=$1
  local cmd=("${@:2}")

  # use coprocess to capture error log stream to file
  coproc TEE_COPROC { exec tee -a "$err_log" >&2; } || return 1

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
  tmp_err_log=$(mktempfile "error-" ".log") || return 1

  # capture command's error stream while still writing to our stdout/strerr
  with_error_log "$tmp_err_log" "${cmd[@]}" || return 1
  local rc="$?"
  if [[ $rc != 0 ]]; then
    log_failed_command_to_termination_log "$tmp_err_log" "$rc" "${cmd[@]}" || {
      echo >&2 "error: could not log failed command to termination log"
    }
  fi
  rm -f "$tmp_err_log" &> /dev/null
  return "$rc"
}

function log_failed_command_to_termination_log() {
  local err_log=$1 rc=$2
  local cmd=("${@:3}")

  {
    echo "Command [${cmd[@]@Q}] failed with exit code $rc"
    echo "Error output:"
    cat "$err_log"
  } >> "${_TERMINATION_LOG_PATH}"
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
  ) || return 1
  if [[ $args_base64 ]]; then
    readarray -t tmp_arr <<<"$args_base64" || return 1
  fi
  dest_arr=()
  for val_base64 in "${tmp_arr[@]}"; do
    dest_arr+=( "$(base64 -d <<<"$val_base64")" ) || return 1
  done
}

function mktempfile() {
  local prefix=${1-} suffix=${2-}

  local tmp_file
  tmp_file="${TMP:-/tmp}/${prefix}$(random_alnum 8)${suffix}" || return 1
  touch "$tmp_file" >/dev/null || return 1
  echo "$tmp_file"
}

function random_alnum() {
  local len=$1

  local chars=""
  while (( ${#chars} < $len )); do
    chars+=$(head -c "$(( $len * 3 ))" /dev/urandom | tr -dc 'a-zA-Z0-9') || return $?
  done
  echo "${chars:0:$len}"
}

function configure_log_elasticsearch() {
  {
    if [[ ${PIPELINE_LOG_ELASTICSEARCH_INDEX_URL-} ]]; then
      jq -n -f "${HERE}/elasticsearch-log-config.jq"
    else
      if [[ -n "${PIPELINE_LOG_FLUENTD_HOST:-}" ]]; then
        jq -n -f "${HERE}/fluentd-log-config.jq"
      fi
      echo "{}"
    fi
  } >"${_JENKINS_CASC_D}/log-elasticsearch.yml" || return 1
}


main "$@"

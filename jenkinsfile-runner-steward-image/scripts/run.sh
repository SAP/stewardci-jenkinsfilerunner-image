#!/bin/bash
set -u -o pipefail

HERE=$(cd "$(dirname "$BASH_SOURCE")"; pwd)

PARAM_VARS_MANDATORY=(
  'PIPELINE_GIT_URL'
  'PIPELINE_GIT_REVISION'
  'PIPELINE_FILE'
  'PIPELINE_PARAMS_JSON'
  'RUN_NAMESPACE'
)

PARAM_VARS_OPTIONAL=(
  'PIPELINE_LOG_ELASTICSEARCH_INDEX_URL'
  'PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET'
  'PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET'
  'PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON'
  'JOB_NAME'
  'RUN_NUMBER'
  'RUN_CAUSE'
)

_JENKINS_APP_DIR="/app/jenkins"
_JENKINS_CASC_D="${_JENKINS_APP_DIR}/WEB-INF/jenkins.yaml.d"
_JENKINS_HOME="/jenkins_home"

# This is only usable with tekton 0.11.x if running in non root mode.
# See https://github.com/tektoncd/pipeline/issues/2131
#_TERMINATION_LOG_PATH="/tekton/results/termination-log"

_TERMINATION_LOG_PATH="/run/termination-log"

function check_required_env_vars() {
  local rc=0 var
  for var in "$@"; do
    if [[ -z ${!var-} ]]; then
      message="error: environment variable not set or empty: $var"
      echo "$message" >&2
      echo "$message" >> "${_TERMINATION_LOG_PATH}"
      rc=1
    fi
  done
  return $rc
}

function with_error_log() {
  local err_log; local -a cmd
  err_log=$1 || exit 1
  shift; cmd=("$@")

  coproc TEE_COPROC { exec tee -a "$err_log" >&2; }
  exec {TEE_COPROC[0]}<&- || exit 1  # we don't read stdout of TEE_COPROC -> close fd
  "${cmd[@]}" 2>&${TEE_COPROC[1]} # run command with stderr redirected to TEE_COPROC
  local rc="$?"
  exec {TEE_COPROC[1]}>&- || exit 1  # EOF on TEE_COPROC's stdin
  wait %  # wait until TEE_COPROC has terminated
  return "$rc"
}

function with_termination_log() {
  local -a cmd=("$@")

  local tmp_err_log
  tmp_err_log=$(mktempfile "error-" ".log") || exit 1

  # capture command's error stream while still writing to our stdout/strerr
  with_error_log "$tmp_err_log" "${cmd[@]}"
  local rc="$?"
  if [[ $rc != 0 ]]; then
    log_failed_command_to_termination_log "$tmp_err_log" "$rc" "${cmd[@]}"
  fi
  rm -f "$tmp_err_log" &> /dev/null
  return "$rc"
}

function log_failed_command_to_termination_log() {
  local err_log rc; local -a cmd
  err_log=$1 || exit 1
  rc=$2 || exit 1
  shift 2; cmd=("$@")

  {
    echo "Command [${cmd[@]@Q}] failed with exit code $rc"
    echo "Error output:"
    cat "$err_log"
  } >> "${_TERMINATION_LOG_PATH}"
}

function make_jfr_pipeline_param_args() {
  local -n dest_arr=$1  # alias to named target variable
  local -a tmp_arr=()
  local args_base64
  args_base64=$(
    <<<"$PIPELINE_PARAMS_JSON" \
    with_termination_log \
    jq \
    --raw-output \
    'keys[] as $k | @base64 "\("-a")", @base64 "\($k + "=" + .[$k])"'
  ) || return 1
  if [[ -n $args_base64 ]]; then
    readarray -t tmp_arr <<<"$args_base64" || return 1
  fi
  dest_arr=()
  for val_base64 in "${tmp_arr[@]}"; do
    dest_arr+=( "$(base64 -d <<<"$val_base64")" ) || return 1
  done
}

function mktempfile() {
  local prefix suffix
  prefix=${1-} || exit 1  # optional
  suffix=${2-} || exit 1  # optional

  local tmp_file
  tmp_file="${TMP:-/tmp}/${prefix}$(random_alnum 8)${suffix}" || return 1
  touch "$tmp_file" >/dev/null || return 1
  echo "$tmp_file"
}

function random_alnum() {
  local len=$1

  local chars=""
  while (( ${#chars} < $len )); do
    chars+=$(head -c "$(( $len * 3 ))" /dev/urandom | tr -dc 'a-zA-Z0-9') || exit $?
  done
  echo "${chars:0:$len}"
}

function configure_log_elasticsearch() {
  with_termination_log python3 -b -B -E -I "${HERE}/create_elasticsearch_log_config.py" > "${_JENKINS_CASC_D}/log-elasticsearch.yml" || return 1
}

casc_yml="${_JENKINS_CASC_D}/casc.yml"
build_xml="${_JENKINS_HOME}/jobs/${JOB_NAME:-job}/builds/${RUN_NUMBER:-1}/build.xml"

truncate -c -s 0 "${_TERMINATION_LOG_PATH}" || exit 1
check_required_env_vars "${PARAM_VARS_MANDATORY[@]}" || exit 1

echo "Cloning pipeline repository $PIPELINE_GIT_URL"
with_termination_log git clone "$PIPELINE_GIT_URL" . || exit 1
echo "Checking out pipeline from revision $PIPELINE_GIT_REVISION"
with_termination_log git checkout "$PIPELINE_GIT_REVISION" || exit 1

with_termination_log sed -i "s/0.0.0.0/$(hostname -i)/g" "$casc_yml" || exit 1
with_termination_log sed -i "s/xxx/$RUN_NAMESPACE/" "$casc_yml" || exit 1
configure_log_elasticsearch || exit 1

with_termination_log mkdir -p "${_JENKINS_HOME}" || exit 1

export -n "${PARAM_VARS_MANDATORY[@]}" "${PARAM_VARS_OPTIONAL[@]}" || exit 1 # do not pass to subprocesses
make_jfr_pipeline_param_args JFR_PIPELINE_PARAM_ARGS || exit 1
jfr_err_log=$(mktempfile "error-" ".log") || exit 1
export JAVA_OPTS="-Dhudson.TcpSlaveAgentListener.hostName=$(hostname -i)"

# The following is a workaround until this PR is released: https://github.com/jenkinsci/kubernetes-plugin/pull/628
# Jenkinsfile Runner does not expose a UI, so this URL is fake...
export JAVA_OPTS="${JAVA_OPTS} -DKUBERNETES_JENKINS_URL=http://jenkinsfilerunner/"

jfr_cmd=(
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
with_error_log "$jfr_err_log" "${jfr_cmd[@]}"
jfr_rc=$?
if [[ ! -f $build_xml ]]; then
  log_failed_command_to_termination_log "$jfr_err_log" "$jfr_rc" "${jfr_cmd[@]}"
  rm -f "$jfr_err_log" &> /dev/null
  exit 1
fi
rm -f "$jfr_err_log" &> /dev/null

#TODO: Define proper exit codes
#TODO: Do not rely on exit codes but return something more structured. E.g. copy builds folder out of container and evaluate further.
completed=$(with_termination_log xmlstarlet sel -t -v /flow-build/completed "$build_xml") || exit 1
result=$(with_termination_log xmlstarlet sel -t -v /flow-build/result "$build_xml") || exit 1
if [[ $completed != "true" ]]; then
  echo "Pipeline not completed" | tee -a "${_TERMINATION_LOG_PATH}"
  exit "$jfr_rc"
fi
if [[ -z $result ]]; then
  echo "No pipeline result in build.xml" | tee -a "${_TERMINATION_LOG_PATH}"
  exit "$jfr_rc"
fi
echo "Pipeline completed with result: $result" | tee -a "${_TERMINATION_LOG_PATH}"
if [[ $result != "SUCCESS" ]]; then
  exit 1
fi
exit 0

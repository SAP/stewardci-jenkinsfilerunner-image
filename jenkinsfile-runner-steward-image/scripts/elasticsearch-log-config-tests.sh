#!/bin/bash
set -eu -o pipefail

HERE=$(cd "$(dirname "$BASH_SOURCE")" && pwd) || {
  echo >&2 "error: failed to determine script location"
  exit 1
}
declare -r HERE


#
# Main
#

function main() {
  _define_testdata

  if _run_all_tests; then
    echo; echo "SUCCESS"
    return 0
  else
    echo; echo "FAILURE"
    return 1
  fi
}

#
# Test data
#

function _define_testdata() {
  #
  # Parameter sets
  #

  declare -gr PARAM_NAME_LEADING_FLUENTD="PIPELINE_LOG_FLUENTD_HOST"
  declare -gr PARAM_NAME_LEADING_ES="PIPELINE_LOG_ELASTICSEARCH_INDEX_URL"

  declare -grA PARAMS_FLUENTD_MANDATORY=(
    [PIPELINE_LOG_FLUENTD_HOST]="fluentdHost1"
    [PIPELINE_LOG_FLUENTD_PORT]="111"
    [PIPELINE_LOG_FLUENTD_TAG]="fluentdTag1"
  )

  declare -gA PARAMS_FLUENTD_FULL=(
    # no optional params so far
  )
  array_merge PARAMS_FLUENTD_FULL PARAMS_FLUENTD_MANDATORY
  declare -r PARAMS_FLUENTD_FULL

  declare -grA PARAMS_ES_MANDATORY=(
    [PIPELINE_LOG_ELASTICSEARCH_INDEX_URL]="esURL1"
  )

  declare -gA PARAMS_ES_FULL=(
    [PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET]="esTrustedCertsSecret1"
    [PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET]="esAuthSecret1"
  )
  array_merge PARAMS_ES_FULL PARAMS_ES_MANDATORY
  declare -r PARAMS_ES_FULL

  declare -grA PARAMS_COMMON_MANDATORY=(
    [PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON]='{"key1":"value1"}'
  )

  declare -gA PARAMS_COMMON_FULL=(
    # no optional parameter so far
  )
  array_merge PARAMS_COMMON_FULL PARAMS_COMMON_MANDATORY
  declare -r PARAMS_COMMON_FULL

  #
  # Results
  #

  # order of JSON object keys doesn't matter

  declare -gr EXPECTED_FLUENTD_MANDATORY=$(cat <<"EOF"
{
  "unclassified": {
    "elasticSearchLogs": {
      "elasticSearch": {
        "elasticsearchWriteAccess": {
          "fluentd": {
            "bufferCapacity": 1098304,
            "bufferRetentionTimeMillis": 1000,
            "host": "fluentdHost1",
            "maxRetries": 30,
            "maxWaitSeconds": 30,
            "port": "111",
            "retryMillis": 1000,
            "tag": "fluentdTag1",
            "timeoutMillis": 3000
          }
        },
        "runIdProvider": {
          "json": {
            "jsonSource": {
              "string": {
                "jsonString": "{\"key1\":\"value1\"}"
              }
            }
          }
        },
        "saveAnnotations": false,
        "writeAnnotationsToLogFile": false
      }
    }
  }
}
EOF
  )

  declare -gr EXPECTED_FLUENTD_FULL=$EXPECTED_FLUENTD_MANDATORY

  declare -gr EXPECTED_ES_MANDATORY=$(cat <<"EOF"
{
  "unclassified": {
    "elasticSearchLogs": {
      "elasticSearch": {
        "certificateId": null,
        "credentialsId": null,
        "elasticsearchWriteAccess": "esDirectWrite",
        "runIdProvider": {
          "json": {
            "jsonSource": {
              "string": {
                "jsonString": "{\"key1\":\"value1\"}"
              }
            }
          }
        },
        "saveAnnotations": false,
        "url": "esURL1",
        "writeAnnotationsToLogFile": false
      }
    }
  }
}
EOF
  )
  declare -gr EXPECTED_ES_FULL=$(cat <<"EOF"
{
  "unclassified": {
    "elasticSearchLogs": {
      "elasticSearch": {
        "certificateId": "esTrustedCertsSecret1",
        "credentialsId": "esAuthSecret1",
        "elasticsearchWriteAccess": "esDirectWrite",
        "runIdProvider": {
          "json": {
            "jsonSource": {
              "string": {
                "jsonString": "{\"key1\":\"value1\"}"
              }
            }
          }
        },
        "saveAnnotations": false,
        "url": "esURL1",
        "writeAnnotationsToLogFile": false
      }
    }
  }
}
EOF
  )
}


#
# Test cases
#

function test_leading_param_missing() {
  # SETUP
  local -A params=()

  # EXERCISE
  local result
  result=$(_excercise params)

  # VERIFY
  assert_result_equals "" "$result"
}

function test_leading_param_precedence() {
  # SETUP
  local -A params=()
  array_merge params \
      PARAMS_FLUENTD_MANDATORY \
      PARAMS_ES_MANDATORY \
      PARAMS_COMMON_MANDATORY

  # EXERCISE
  local result
  result=$(_excercise params)

  # VERIFY
  assert_result_equals "$EXPECTED_FLUENTD_MANDATORY" "$result"
}

function test_fluentd_mandatory() {
  # SETUP
  local -A params=()
  array_merge params \
      PARAMS_FLUENTD_MANDATORY \
      PARAMS_COMMON_MANDATORY

  # EXERCISE
  local result
  result=$(_excercise params)

  # VERIFY
  assert_result_equals "$EXPECTED_FLUENTD_MANDATORY" "$result"
}

function test_fluentd_full() {
  # SETUP
  local -A params=()
  array_merge params \
      PARAMS_FLUENTD_FULL \
      PARAMS_COMMON_FULL

  # EXERCISE
  local result
  result=$(_excercise params)

  # VERIFY
  assert_result_equals "$EXPECTED_FLUENTD_FULL" "$result"
}

function test_es_mandatory() {
  # SETUP
  local -A params=()
  array_merge params \
      PARAMS_ES_MANDATORY \
      PARAMS_COMMON_MANDATORY

  # EXERCISE
  local result
  result=$(_excercise params)

  # VERIFY
  assert_result_equals "$EXPECTED_ES_MANDATORY" "$result"
}

function test_es_full() {
  # SETUP
  local -A params=()
  array_merge params \
      PARAMS_ES_FULL \
      PARAMS_COMMON_FULL

  # EXERCISE
  local result
  result=$(_excercise params)

  # VERIFY
  assert_result_equals "$EXPECTED_ES_FULL" "$result"
}

function test_fluentd_fail_on_missing_param() {
  # SETUP
  local -A mandatory_params=()
  array_merge mandatory_params \
      PARAMS_FLUENTD_MANDATORY \
      PARAMS_COMMON_MANDATORY

  # SUBTESTS
  for param_to_omit in "${!PARAMS_FLUENTD_MANDATORY[@]}"; do
    [[ $param_to_omit != "$PARAM_NAME_LEADING_FLUENTD" ]] || continue

    echo "====== $param_to_omit"

    # a parameter can be an emtpy string or not set at all (null)

    # SETUP
    local -A params=()
    array_merge params mandatory_params
    array_remove_keys params "$param_to_omit"

    # EXERCISE + VERIFY
    echo "========= param not set"
    _excercise_and_verify_param_missing "$param_to_omit"

    # SETUP
    params=()
    array_merge params mandatory_params
    params[$param_to_omit]=""

    # EXERCISE + VERIFY
    echo "========= param set but empty"
    _excercise_and_verify_param_missing "$param_to_omit"
  done
}

function test_es_fail_on_missing_param() {
  # SETUP
  local -A mandatory_params=()
  array_merge mandatory_params \
      PARAMS_ES_MANDATORY \
      PARAMS_COMMON_MANDATORY

  # SUBTESTS
  for param_to_omit in "${!PARAMS_ES_MANDATORY[@]}"; do
    [[ $param_to_omit != "$PARAM_NAME_LEADING_ES" ]] || continue

    echo "====== $param_to_omit"

    # a parameter can be an emtpy string or not set at all (null)

    # SETUP
    local -A params=()
    array_merge params mandatory_params
    array_remove_keys params "$param_to_omit"

    # EXERCISE + VERIFY
    echo "========= param not set"
    _excercise_and_verify_param_missing "$param_to_omit"

    # SETUP
    params=()
    array_merge params mandatory_params
    params[$param_to_omit]=""

    # EXERCISE + VERIFY
    echo "========= param set but empty"
    _excercise_and_verify_param_missing "$param_to_omit"
  done
}

function test_common_fail_on_missing_param() {
  # SETUP
  local -A mandatory_params=()
  array_merge mandatory_params \
      PARAMS_FLUENTD_MANDATORY \
      PARAMS_COMMON_MANDATORY

  # SUBTESTS
  for param_to_omit in "${!PARAMS_COMMON_MANDATORY[@]}"; do
    echo "====== $param_to_omit"

    # a parameter can be an emtpy string or not set at all (null)

    # SETUP
    local -A params=()
    array_merge params mandatory_params
    array_remove_keys params "$param_to_omit"

    # EXERCISE + VERIFY
    echo "========= param not set"
    _excercise_and_verify_param_missing "$param_to_omit"

    # SETUP
    params=()
    array_merge params mandatory_params
    params[$param_to_omit]=""

    # EXERCISE + VERIFY
    echo "========= param set but empty"
    _excercise_and_verify_param_missing "$param_to_omit"
  done
}

function _excercise_and_verify_param_missing() {
  local param_to_omit=$1

  local err_out
  err_out=$(_excercise_expecting_error params)
  [[ "$err_out" =~ "env var $param_to_omit must be specified" ]] || {
    echo "unexpected error:"
    echo "+++"
    echo "$err_out"
    echo "+++"
  }
}

function test_invalid_RUNID_JSON() {
  # SETUP
  local p_name="PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON"
  local -A params=()
  array_merge params \
      PARAMS_FLUENTD_MANDATORY \
      PARAMS_COMMON_MANDATORY
  params[$p_name]=AAA

  # EXERCISE + VERIFY
  _excercise_and_verify_invalid_param_value "$p_name" "${params[$p_name]}"
}

function _excercise_and_verify_invalid_param_value() {
  local p_name=$1 p_value=$2

  local err_out
  err_out=$(_excercise_expecting_error params)
  [[ "$err_out" =~ "env var $p_name: invalid value '$p_value': " ]] || {
    echo "unexpected error:"
    echo "+++"
    echo "$err_out"
    echo "+++"
  }
}


#
# Test helpers
#

function _run_all_tests() {
  local failed=0
  for test in $(_get_all_tests); do
    echo "=== $test"
    "$test" || {
      failed=1
      echo "FAILED"
    }
  done
  return "$failed"
}

function _get_all_tests() {
  declare -F 2>&1 | sed -e 's/^declare -f //; s/[^[:alnum:]_]//; /^test_/!d'
}

function _excercise() {
  local -n env_arr=$1

  (
    for name in "${!env_arr[@]}"; do
      export "$name"="${env_arr[$name]}"
    done
    jq -n -f "${HERE}/elasticsearch-log-config.jq"
  )
}

# Fails if SuT does NOT fail. SuT's stderr is provided on stdout.
function _excercise_expecting_error() {
  local env_arr=$1

  local rc=0
  _excercise params 2>&1 1>/dev/null || rc=$?
  if (( $rc == 0 )); then
    echo "SuT was expected to fail but did not"
    return 1
  fi
}

function assert_result_equals() {
  local expected=$1 actual=$2

  local diff
  diff=$(diff <(jq -S . <<<"$expected") <(jq -S . <<<"$actual")) || {
    if (( $? == 1 )); then
      echo "Unexpected result:"
      echo "$diff"
    fi
    return 1
  }
}

function _missing_test_impl() {
  echo >&2 "test implementation is missing"
  return 1
}


#
# arrays
#

# Returns true if the array variable with name $1 contains a value (not key) $2.
# Both indexed and associative arrays are supported.
function array_contains_value() {
  local -n haystack=$1
  local needle=$2
  local key value
  for key in "${!haystack[@]}"; do
    value="${haystack[$key]}"
    if [[ $value == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

# Removes all values (not keys) from the array variable with name $1 which are
# not in $2, $3, ... Both indexed and associative arrays are supported.
# The original keys are kept stable.
#
# Example 1 - indexed array:
#   a1=(a b c d a b)
#   echo "${a1[@]@A}"
#   # -> declare -a a1=([0]="a" [1]="b" [2]="c" [3]="d" [4]="a" [5]="b")
#   array_keep_values a1 a c
#   echo "${a1[@]@A}"
#   # -> declare -a a1=([0]="a" [2]="c" [4]="a")
#
# Example 2 - associative array:
#   declare -A a2=([k1]=a [k2]=b [k3]=c [k4]=d [k5]=a [k6]=b)
#   echo "${a2[@]@A}"
#   # -> declare -A a2=([k4]="d" [k5]="a" [k6]="b" [k1]="a" [k2]="b" [k3]="c" )
#   array_keep_values a2 a c
#   echo "${a2[@]@A}"
#   # -> declare -A a2=([k5]="a" [k1]="a" [k3]="c" )
#
function array_keep_values() {
  local -n array=$1
  local toKeep=("${@:2}")
  local key value
  for key in "${!array[@]}"; do
    value="${array[$key]}"
    if ! array_contains_value toKeep "$value"; then
      unset -v "array[$key]"
    fi
  done
}

function array_keep_keys() {
  local -n array=$1
  local toKeep=("${@:2}")
  local key
  for key in "${!array[@]}"; do
    if ! array_contains_value toKeep "$key"; then
      unset -v "array[$key]"
    fi
  done
}

# Removes the values (not keys) $2, $3, ... from the array variable with name $1.
# Both indexed and associative arrays are supported.
# The original keys are kept stable.
#
# Example 1 - Indexed array:
#   a1=(a b c d a b)
#   echo "${a1[@]@A}"
#   # -> declare -a a1=([0]="a" [1]="b" [2]="c" [3]="d" [4]="a" [5]="b")
#   array_remove_values a1 a c
#   echo "${a1[@]@A}"
#   # -> declare -a a1=([1]="b" [3]="d" [5]="b")
#
# Example 2 - Associative array:
#   declare -A a2=([k1]=a [k2]=b [k3]=c [k4]=d [k5]=a [k6]=b)
#   echo "${a2[@]@A}"
#   # -> declare -A a2=([k4]="d" [k5]="a" [k6]="b" [k1]="a" [k2]="b" [k3]="c" )
#   array_remove_values a2 a c
#   echo "${a2[@]@A}"
#   # -> declare -A a2=([k4]="d" [k6]="b" [k2]="b" )
#
function array_remove_values() {
  local -n array=$1
  local toRemove=("${@:2}")
  local key value
  for key in "${!array[@]}"; do
    value="${array[$key]}"
    if array_contains_value toRemove "$value"; then
      unset -v "array[$key]"
    fi
  done
}

function array_remove_keys() {
  local -n array=$1
  local toRemove=("${@:2}")
  local key
  for key in "${!array[@]}"; do
    if array_contains_value toRemove "$key"; then
      unset -v "array[$key]"
    fi
  done
}

function array_merge() {
  local -n to_array=$1
  local from_arrays=("${@:2}")
  local key
  for from_array_name in "${from_arrays[@]}"; do
    local -n from_array=$from_array_name
    for key in "${!from_array[@]}"; do
      to_array[$key]=${from_array[$key]}
    done
  done
}


main "$@"

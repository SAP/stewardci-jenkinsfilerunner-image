#!/bin/bash
set -u -o pipefail

function die() {
  if (( ${#@} > 0 )); then
    echo "$@" >&2
  fi
  echo
  echo "FAILED"
  exit 1
}

PROJECT_ROOT=$(cd "$(dirname "$BASH_SOURCE")"; pwd)

cd ${PROJECT_ROOT}/jenkinsfile-runner-base-image
./build.sh || die

cd ${PROJECT_ROOT}/jenkinsfile-runner-steward-image
./build.sh "$@" || die

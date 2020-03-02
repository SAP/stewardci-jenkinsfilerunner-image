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

name=stewardci-jenkinsfile-runner
tagPrefix="${5-}"

cd "$(dirname "$BASH_SOURCE")" || die

git rev-parse --git-dir
if [[ $? == 128 ]]; then
  # not in a Git checkout
  tag="localbuild-$(date +%y%m%d)" || die
elif [[ -n "${tagPrefix}" ]]; then
  tag="${tagPrefix}_$(date +%y%m%d)_$(git log --format='%h' -n 1)" || die
else
  tag="$(date +%y%m%d)_$(git log --format='%h' -n 1)" || die
fi


echo "Building ${name}-local image"
docker build . -t ${name}-local || die


if [[ ${1-} == "--push" ]]; then
  docker_repo="${2-}"
  [[ -n $docker_repo ]] || die "error: --push needs an argument"
  if [[ $docker_repo == *"gcr.io"* ]]; then
    docker login -u _json_key -p "$(cat "${GOOGLE_APPLICATION_CREDENTIALS}")" "${docker_repo}" || die
  else
    user="${3-}"
    password="${4-}"
    if [[ -n $user ]]; then
        [[ -n $password ]] || die "error: password parameter missing"
        docker login -u "$user" -p "$password"
    fi
  fi

  echo "Pushing ${docker_repo}/$name:$tag"
  docker tag "${name}-local" "${docker_repo}/$name:$tag" || die
  docker push "${docker_repo}/$name:$tag" || die
fi

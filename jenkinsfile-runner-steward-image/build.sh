#!/bin/bash
set -eu -o pipefail

function die() {
  if (( ${#@} > 0 )); then
    echo "$@" >&2
  fi
  echo
  echo "FAILED"
  exit 1
}

function print_usage() {
    cat >&2 <<EOF
Usage
    $(printf "%q" "$(basename "$BASH_SOURCE")") OPTIONS
    Builds the jenkinsfile-runner-steward-image and pushes it to
    a docker registry if --push is specified
OPTIONS
    -h, --help
        Print help and quit without doing anything. The exit code is 0.
    --tag-prefix string (optional)
        TODO
    --push (optional)
        TODO
    --docker-org string (mandatory for --push)
        TODO
    --docker-creds string string (mandatory for --push)
        TODO
EOF
}

# set from args/options
unset P_TAG_PREFIX
unset P_PUSH
unset P_DOCKER_ORG
unset P_USERNAME
unset P_PASSWORD

function parse_args() {
    while (( $# > 0 )); do
        case $1 in
            "-h" | "--help" )
                print_usage
                exit 0
                ;;
            "--push" )
                P_PUSH="--push"
                ;;
            "--docker-org" )
                [[ ${2-} ]] || die "error: option $1 requires a non-empty argument"
                P_DOCKER_ORG="$2"
                shift
                ;;
            "--docker-creds" )
                [[ ${2-} && ${3-} ]] || die "error: option $1 requires two non-empty arguments"
                P_USERNAME="$2"
                P_PASSWORD="$3"
                shift 2
                ;;
            "--tag-prefix" )
                [[ ${2-} ]] || die "error: option $1 requires a non-empty argument"
                P_TAG_PREFIX="$2"
                shift
                ;;
            * )
                die "error: invalid command line option '$1'"
        esac
        shift
    done
}

function check_args() {
    if [[ ${P_PUSH-} ]]; then
      if [[ ! ${P_DOCKER_ORG-} ]]; then
          print_usage
          die "error: docker org must be specified"
      fi
      if [[ ! ${P_USERNAME-} ]]; then
          print_usage
          die "error: docker user must be specified"
      fi
      if [[ ! ${P_PASSWORD-} ]]; then
          print_usage
          die "error: docker password must be specified"
      fi
    fi
}

function calculate_tag() {
  TAG=""
  git rev-parse --git-dir
  if [[ $? == 128 ]]; then
    # not in a Git checkout
    TAG="localbuild-$(date +%y%m%d)" || die
  elif [[ -n "${P_TAG_PREFIX-}" ]]; then
    TAG="${P_TAG_PREFIX}_$(date +%y%m%d)_$(git log --format='%h' -n 1)" || die
  else
    TAG="$(date +%y%m%d)_$(git log --format='%h' -n 1)" || die
  fi
}

function print_params() {
  echo "IMAGE_NAME: ${IMAGE_NAME-}"
  echo "TAG:        ${TAG-}"
  echo "TAG_PREFIX: ${P_TAG_PREFIX-}"
  echo "PUSH:       ${P_PUSH-}"
  echo "DOCKER_ORG: ${P_DOCKER_ORG-}"
  echo "USER:       ${P_USERNAME-}"
}

parse_args "$@"
check_args
calculate_tag

IMAGE_NAME=stewardci-jenkinsfile-runner

cd "$(dirname "$BASH_SOURCE")" || die

print_params


echo "Building ${IMAGE_NAME}-local image"
docker build . -t ${IMAGE_NAME}-local || die


if [[ ${P_PUSH-} == "--push" ]]; then

  if [[ $P_DOCKER_ORG == *"gcr.io"* ]]; then
    docker login -u _json_key -p "$(cat "${GOOGLE_APPLICATION_CREDENTIALS}")" "${P_DOCKER_ORG}" || die
  else
    if [[ -n $P_USERNAME ]]; then
        [[ -n $P_PASSWORD ]] || die "error: password parameter missing"
        docker login -u "$P_USERNAME" -p "$P_PASSWORD"
    fi
  fi

  echo "Pushing ${P_DOCKER_ORG}/${IMAGE_NAME}:$TAG"
  docker tag "${IMAGE_NAME}-local" "${P_DOCKER_ORG}/${IMAGE_NAME}:$TAG" || die
  docker push "${P_DOCKER_ORG}/${IMAGE_NAME}:$TAG" || die
  echo "${P_DOCKER_ORG}/${IMAGE_NAME}:$TAG" > deployInfo.txt || die
fi

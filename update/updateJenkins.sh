#!/bin/bash
set -eu -o pipefail
exec <&-

PROJECT_ROOT=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd) || {
    echo >&2 "failed to determine script location"
    exit 1
}

packagerConfig="${PROJECT_ROOT}/jenkinsfile-runner-base-image/packager-config.yml"


function main() {
    echo "This is not automated yet - update packager-config.yml manually!"

    printLatestLTSVersion
    printCurrentBase
}

function printLatestLTSVersion() {
    local s
    s=$(curl -sL 'https://www.jenkins.io/changelog-stable/') || {
        echo >&2 "failed to download Jenkins LTS changelog"
        exit 1
    }
    s=$(<<<"$s" grep "^What's new in" -m1) || {
        echo >&2 "failed to extract version from Jenkins LTS changelog"
        exit 1
    }
    <<<"$s" sed -e 's/.*in /Latest LTS: /g'
}

function printCurrentBase() {
    local s
    s=$(grep -e "base:" "$packagerConfig") || {
        echo >&2 "failed to extract base version from $packagerConfig"
        exit 1
    }
    <<<"$s" sed -e 's/.*base: /Current base: /'
}


main "$@"

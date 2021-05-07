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

    printLatestVersion true
    printCurrentBase
}

function printLatestVersion() {
    #local url='https://www.jenkins.io/changelog-stable/' #LTS
    local url='https://www.jenkins.io/changelog/'
    local s
    s=$(curl -sL "$url") || {
        echo >&2 "failed to download Jenkins changelog from $url"
        exit 1
    }
    s=$(<<<"$s" grep "^What's new in" -m1) || {
        echo >&2 "failed to extract version from Jenkins changelog ($url)"
        exit 1
    }
    <<<"$s" sed -e 's/.*in /Latest: /g'
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

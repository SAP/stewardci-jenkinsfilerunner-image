#!/bin/bash
set -eu -o pipefail
exec <&-

#changelogUrl needs to be in sync with updateCenterUrl in generate.groovy!
changelogUrl='https://www.jenkins.io/changelog-stable/' #LTS
#changelogUrl='https://www.jenkins.io/changelog/'       #LATEST

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
    local s
    s=$(curl -sL "$changelogUrl") || {
        echo >&2 "failed to download Jenkins changelog from $changelogUrl"
        exit 1
    }
    s=$(<<<"$s" grep "^What's new in" -m1) || {
        echo >&2 "failed to extract version from Jenkins changelog ($changelogUrl)"
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

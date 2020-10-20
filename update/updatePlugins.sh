#!/bin/bash
set -eu -o pipefail
exec <&-

declare -r PROJECT_ROOT=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd) || {
    echo >&2 "failed to determine script location"
    exit 1
}

declare -r TEMP_DIR=$(mktemp -d) || {
    echo >&2 "failed to create temporary directory"
    exit 1
}
trap "rm -rf \"$TEMP_DIR\" &>/dev/null || true" EXIT

packagerConfig="${PROJECT_ROOT}/jenkinsfile-runner-base-image/packager-config.yml"
pluginList="${PROJECT_ROOT}/jenkinsfile-runner-base-image/plugins.txt"


function main() {
    local tempPackagerConfig="$TEMP_DIR/packager-config.yaml"

    # Remove outdated plugins list
    sed -e "/^##PLUGINS-START/,/^##PLUGINS-END/d" "${packagerConfig}" >"$tempPackagerConfig"

    # Generate new plugins list
    {
        echo "##PLUGINS-START (do not remove!)"
        runGroovy "${PROJECT_ROOT}/update/generate.groovy" "${pluginList}" -cwp --skip-optional || {
            echo >&2 "generate.groovy failed"
            exit 1
        }
        echo "##PLUGINS-END (do not remove!)"
    } >> "${tempPackagerConfig}"

    cp "$tempPackagerConfig" "$packagerConfig"
    echo "Updated plugins in ${packagerConfig}"
}

# The Groovy start script for *nix prints error messages to stdout instead
# of stderr. In case of a non-zero exit code and empty error output we
# send its stdout to our stderr.
function runGroovy() {
    local err_file out_file rc=0
    err_file=$(mktemp -p "$TEMP_DIR")
    out_file=$(mktemp -p "$TEMP_DIR")

    groovy "$@" 2>"$err_file" | tee "$out_file" || rc=$?
    if [[ -s $err_file ]]; then
        cat "$err_file" >&2
    else
        if [[ $rc != "0" ]]; then
            # exit code indicates error but no error output
            cat "$out_file" >&2
        fi
    fi
    return "$rc"
}


main "$@"

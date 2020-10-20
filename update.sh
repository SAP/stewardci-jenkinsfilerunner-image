#!/bin/bash
set -eu -o pipefail

declare -r PROJECT_ROOT=$(cd "$(dirname "$BASH_SOURCE")" && pwd) || {
    echo >&2 "failed to determine script location"
    exit 1
}

echo -e "\n### Updating plugins ###########\n"
"$PROJECT_ROOT/update/updatePlugins.sh"

echo -e "\n\n### Updating Jenkins LTS version ###########\n"
"$PROJECT_ROOT/update/updateJenkins.sh"

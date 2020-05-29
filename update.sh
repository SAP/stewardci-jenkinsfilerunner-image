#!/bin/bash
set -eu -o pipefail

printf "### Updating plugins ###########\n"
./update/updatePlugins.sh

printf "\n\n### Updating Jenkins LTS version ###########\n"
./update/updateJenkins.sh

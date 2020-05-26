#!/bin/bash

printf "Updating plugins\n"
./update/updatePlugins.sh

printf "\nUpdating Jenkins LTS version\n"
printf "(not automated yet - update packager-config.yml manually)\n"

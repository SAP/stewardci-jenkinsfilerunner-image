#!/bin/bash

PROJECT_ROOT=$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)
packagerConfig="${PROJECT_ROOT}/jenkinsfile-runner-base-image/packager-config.yml"
pluginList="${PROJECT_ROOT}/jenkinsfile-runner-base-image/plugins.txt"

# Remove outdated plugins list
sed -e "/^##PLUGINS-START/,/^##PLUGINS-END/d" "${packagerConfig}" > "${packagerConfig}.tmp"
mv "${packagerConfig}.tmp" "${packagerConfig}"

# Generate new plugins list
echo "##PLUGINS-START (do not remove!)" >> "${packagerConfig}"
groovy "${PROJECT_ROOT}/update/generate.groovy" "${pluginList}" -cwp --skip-optional >> "${packagerConfig}"
echo "##PLUGINS-END (do not remove!)" >> "${packagerConfig}"

echo "Updated plugins in ${packagerConfig}"

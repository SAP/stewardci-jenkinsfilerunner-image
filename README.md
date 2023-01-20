[![REUSE status](https://api.reuse.software/badge/github.com/SAP/stewardci-jenkinsfilerunner-image)](https://api.reuse.software/info/github.com/SAP/stewardci-jenkinsfilerunner-image)

## Description

This repo provides a Jenkinsfile Runner Docker image which is able
to execute Jenkins pipelines on a [project "Steward"](https://github.com/SAP/stewardci-core) instance.

Here the [Development & Build Process](README-DEV.md) is documented.

## Requirements

- Docker
- Git repo with a Jenkinsfile

## Download and Installation
Prebuild image versions can be found in [dockerhub](https://hub.docker.com/r/stewardci/stewardci-jenkinsfile-runner).
To test the image using docker call:
```sh
# Test the image (e.g. with our example Jenkinsfile)
docker run \
  -e PIPELINE_GIT_URL=https://github.com/SAP-samples/stewardci-example-pipelines \
  -e PIPELINE_GIT_REVISION=master \
  -e PIPELINE_FILE=success/Jenkinsfile \
  -e PIPELINE_PARAMS_JSON={} \
  -e RUN_NAMESPACE=anything \
  -v "/workspace" \
  -w "/workspace" \
  stewardci/stewardci-jenkinsfile-runner:191031_07973f6
```

To build and test from sources execute the following commands:
```sh
# Build the image
./build.sh

# Test the image (e.g. with our example Jenkinsfile)
docker run \
  -e PIPELINE_GIT_URL=https://github.com/SAP-samples/stewardci-example-pipelines \
  -e PIPELINE_GIT_REVISION=master \
  -e PIPELINE_FILE=success/Jenkinsfile \
  -e PIPELINE_PARAMS_JSON={} \
  -e RUN_NAMESPACE=anything \
  -v "/workspace" \
  -w "/workspace" \
  stewardci-jenkinsfile-runner-local
```

## Configuration

See [Download and Installation](#download-and-installation)

## Limitations

no limitations known

## Known Issues

no issues known

## How to obtain support

Please create issues on this repository to contact us.

## To-Do (upcoming changes)

see GitHub issues for planned changes

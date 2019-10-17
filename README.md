## Description

This repo provides a very basic example Jenkinsfile Runner Docker image which is able
to execute a simple hello world pipeline on a [project "Steward"](https://github.com/SAP/stewardci-core) instance.

## Requirements

- Docker
- Git repo with a Jenkinsfile

## Download and Installation

```sh
docker build . -t jenkinsfilerunner

export PIPELINE_GIT_URL=<gitRepoWithJenkinsfile>
export PIPELINE_GIT_REVISION=<branch>
export PIPELINE_FILE=<relativePathToJenkinsfile>
export PIPELINE_PARAMS_JSON={}
export RUN_NAMESPACE=<anything> # only relevant for Kubernetes use

docker run jenkinsfilerunner
```

## Configuration

See [Download and Installation](#download-and-installation)

## Limitations

Does not support Docker steps yet.

## Known Issues

The Dockerfile provided here only supports simple hello world pipelines. 

To support the Kubernetes plugin, configuration as code, writing logs to Elasticsearch
a more elaborated image is required. We will provide this here to the Open Source community soon.

## How to obtain support

Please create issues on this repository to contact us.

## Contributing

You are welcome to contribute to this project via Pull Requests.

## To-Do (upcoming changes)

More elaborate image soon

## License

Copyright (c) 2019 SAP SE or an SAP affiliate company. All rights reserved.
This project is licensed under "Apache Software License, v. 2" except as noted otherwise in the LICENSE file.


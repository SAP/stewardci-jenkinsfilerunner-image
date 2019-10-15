# This produces a very basic example image which is able
# to execute a simple hello world pipeline - not more.

# Source: https://github.com/jenkinsci/jenkinsfile-runner
FROM alxsap/jenkinsfile-runner:1.0-beta-10

RUN apt update -y 
RUN apt install -y jq python3 xmlstarlet

COPY scripts/ /scripts

RUN mkdir /workspace
WORKDIR /workspace

ENTRYPOINT [ "bash", "/scripts/run.sh" ]

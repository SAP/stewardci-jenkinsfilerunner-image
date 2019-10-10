# This produces a very basic example image which is able
# to execute a simple hello world pipeline - not more.

FROM csanchez/jenkinsfile-runner

RUN apt update -y 
RUN apt install -y jq python3 xmlstarlet

COPY scripts/ /scripts

RUN mkdir /workspace
WORKDIR /workspace

ENTRYPOINT [ "bash", "/scripts/run.sh" ]

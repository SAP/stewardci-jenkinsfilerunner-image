FROM jenkinsfile-runner-base-local

RUN apk add jq python3 xmlstarlet

COPY scripts/ /scripts

ENTRYPOINT [ "bash", "/scripts/run.sh" ]

FROM jenkinsfile-runner-base-local as packager-output
FROM openjdk:8-alpine

RUN apk add jq python3 xmlstarlet bash git
RUN addgroup -g 1000 jenkins && adduser -D -u 1000 -G jenkins jenkins
RUN mkdir -p /run && chmod o+w /run
RUN mkdir /jenkins_home && chown jenkins:jenkins /jenkins_home
USER jenkins:jenkins

COPY --from=packager-output --chown=jenkins:jenkins /app /app
COPY --from=packager-output --chown=jenkins:jenkins /usr/share/jenkins /usr/share/jenkins

# we want to clone the pipeline directory here:
RUN mkdir /tmp/pipeline
WORKDIR /tmp/pipeline

COPY scripts/ /scripts
ENTRYPOINT [ "bash", "/scripts/run.sh" ]

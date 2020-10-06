FROM jenkinsfile-runner-base-local as packager-output
FROM adoptopenjdk/openjdk11:x86_64-alpine-jdk-11.0.8_10-slim

RUN apk add jq xmlstarlet bash git curl
RUN addgroup -g 1000 jenkins && adduser -D -u 1000 -G jenkins jenkins
RUN mkdir -p /run && chmod o+w /run
RUN mkdir /jenkins_home && chown jenkins:jenkins /jenkins_home
# we want to clone the pipeline directory here:
RUN mkdir -p /workspace && chown jenkins:jenkins /workspace

VOLUME /jenkins_home
VOLUME /workspace
WORKDIR /workspace

USER jenkins:jenkins

COPY --from=packager-output --chown=jenkins:jenkins /app /app
COPY --from=packager-output --chown=jenkins:jenkins /usr/share/jenkins /usr/share/jenkins


COPY scripts/ /scripts
ENTRYPOINT [ "bash", "/scripts/run.sh" ]

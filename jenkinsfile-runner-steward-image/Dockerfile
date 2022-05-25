FROM jenkinsfile-runner-base-local as packager-output
# adoptopenjdk/openjdk11:x86_64-alpine-jdk-11.0.15_10-slim
FROM adoptopenjdk/openjdk11@sha256:9911c74c8f631562176ce21d9eb98fd032ece1e13b78a6e0bf33f2917b90a5cb

RUN apk update && apk upgrade && \
    apk add jq xmlstarlet bash git curl
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
COPY steward-interface/ /steward-interface
ENTRYPOINT [ "/steward-interface/entrypoint" ]

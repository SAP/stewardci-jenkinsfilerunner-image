FROM jenkinsfile-runner-base-local as packager-output
# adoptopenjdk/openjdk11:x86_64-alpine-jdk-11.0.8_10-slim
FROM adoptopenjdk/openjdk11@sha256:925eed1e2003bb2b9a80c77e9080c4d5b229f49ec51eac472db69b42f6072331

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

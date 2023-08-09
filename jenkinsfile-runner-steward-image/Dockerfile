FROM jenkinsfile-runner-base-local as packager-output
FROM eclipse-temurin:11.0.20_8-jdk-alpine@sha256:87219038abbc0e3a14868694b3567a39a4a6779de66ab0a23ff2c3812a8f1181

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
# avoid warnings about old .hpi extensions
RUN cd /usr/share/jenkins/ref/plugins/ && \
    for f in *.hpi; do mv -- "$f" "${f%.hpi}.jpi"; done

COPY scripts/ /scripts
COPY steward-interface/ /steward-interface
ENTRYPOINT [ "/steward-interface/entrypoint" ]

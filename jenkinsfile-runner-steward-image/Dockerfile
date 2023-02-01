FROM jenkinsfile-runner-base-local as packager-output
# eclipse-temurin:11.0.18_10-jdk-alpine
FROM eclipse-temurin@sha256:8368526729a4fa4275807761f51770c505a16c8dcad969609d7644de9dab9367

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

FROM jenkinsfile-runner-base-local as packager-output
# adoptopenjdk/openjdk8:x86_64-alpine-jdk8u252-b09-slim
FROM adoptopenjdk/openjdk8@sha256:cd08e0cb4d68fe4ce91559b57d65fecbb19c10bac659e454c49a851aecb048e9

RUN apk add jq xmlstarlet bash git
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

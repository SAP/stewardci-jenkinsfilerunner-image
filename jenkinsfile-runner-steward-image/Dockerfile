FROM jenkinsfile-runner-base-local as packager-output
# adoptopenjdk/openjdk11:x86_64-alpine-jdk-11.0.7_10-slim
FROM adoptopenjdk/openjdk11@sha256:1b5a395ba0eb4d4fa8fc2ced4471e43044681d5541a7fe11b1f0c20f0f6104db

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

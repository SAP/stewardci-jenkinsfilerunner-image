# This produces a very basic example image which is able
# to execute a simple hello world pipeline - not more.

# Source: https://github.com/jenkinsci/jenkinsfile-runner
FROM alxsap/jenkinsfile-runner:1.0-beta-10

RUN apt update -y 
RUN apt install -y jq python3 xmlstarlet

RUN curl -L -o /usr/share/jenkins/ref/plugins/git.hpi http://updates.jenkins-ci.org/download/plugins/git/3.12.1/git.hpi
RUN echo `echo 3TLGhDsiLjzhmyXAPXXP7MX3t7Y= | base64 -d | od -t x1 -w32 -An | tr -d " \t\n\r"` /usr/share/jenkins/ref/plugins/git.hpi | sha1sum -c -

RUN curl -L -o /usr/share/jenkins/ref/plugins/matrix-project.hpi http://updates.jenkins-ci.org/download/plugins/matrix-project/1.14/matrix-project.hpi
RUN echo `echo sBg0X0ORm8L+GwlEpUF6NiHdEkI= | base64 -d | od -t x1 -w32 -An | tr -d " \t\n\r"` /usr/share/jenkins/ref/plugins/matrix-project.hpi | sha1sum -c -

RUN curl -L -o /usr/share/jenkins/ref/plugins/junit.hpi http://updates.jenkins-ci.org/download/plugins/junit/1.28/junit.hpi
RUN echo `echo MHPvr0o4jhv7teV1kwg/4iXY2so= | base64 -d | od -t x1 -w32 -An | tr -d " \t\n\r"` /usr/share/jenkins/ref/plugins/junit.hpi | sha1sum -c -

COPY scripts/ /scripts

RUN mkdir /workspace
WORKDIR /workspace

ENTRYPOINT [ "bash", "/scripts/run.sh" ]

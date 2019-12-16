FROM jenkinsfile-runner-base-local

RUN apk update && apk upgrade \
    apk add jq python3 xmlstarlet

#Reduce image size
RUN rm /usr/share/jenkins/jenkins.war \
    rm -rf /app/jenkins/WEB-INF/plugins/ \
    ln -s /usr/share/jenkins/ref/plugins /app/jenkins/WEB-INF/plugins

COPY scripts/ /scripts

ENTRYPOINT [ "bash", "/scripts/run.sh" ]

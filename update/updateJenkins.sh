#!/bin/bash
exec 2> /dev/null

ROOT=$(cd "$(dirname "$BASH_SOURCE")"; pwd)

printf "This is not automated yet - update packager-config.yml manually!\n"


latestLTSLine=`curl https://www.jenkins.io/changelog-stable/ | grep "^What's new in" -m1`
latestMessage=`echo $latestLTSLine | sed s/'.*in '/'Latest LTS: '/g`
echo $latestMessage

currentVersion=`cat ${ROOT}/../jenkinsfile-runner-base-image/packager-config.yml | grep "base:"`
currentMessage=`echo $currentVersion | sed s/'.*base: '/'Current base: '/g`
echo $currentMessage

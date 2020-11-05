#!/bin/bash
###
# Prerequisites:
#  unzip $HOME/archives/JSME_2013-10-13.zip -d badapple_war/src/main/webapp
#  mv badapple_war/src/main/webapp/JSME_2013-10-13 badapple_war/src/main/webapp/jsme 
#  mvn clean install
###
cwd=$(pwd)
#
if [ $(whoami) != "root" ]; then
	echo "${0} should be run as root or via sudo."
	exit
fi
#
docker version
#
INAME="badapple_ui"
TAG="latest"
#
T0=$(date +%s)
#
###
# Build image from Dockerfile.
dockerfile="${cwd}/Dockerfile_UI"
docker build -f ${dockerfile} -t ${INAME}:${TAG} .
#
printf "Elapsed time: %ds\n" "$[$(date +%s) - ${T0}]"
#
docker images
#

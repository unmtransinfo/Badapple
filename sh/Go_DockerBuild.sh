#!/bin/sh
###
set -e
#
if [ $(whoami) != "root" ]; then
	echo "${0} should be run as root or via sudo."
	exit
fi
#
docker version
#
INAME="badapple"
CNAME="${INAME}_container"
#
###
# Build image from Dockerfile.
docker build -t ${INAME} .
docker images
#

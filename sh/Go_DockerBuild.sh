#!/bin/sh
###
set -e
#
sudo docker version
#
INAME="badapple"
CNAME="${INAME}_container"
#
###
# Build image from Dockerfile.
sudo docker build -t ${INAME} .
sudo docker images
#

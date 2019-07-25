#!/bin/sh
###
set -e
#
INAME="badapple"
CNAME="${INAME}_container"
#
###
# Instantiate and run container.
# -dit = --detached --interactive --tty
sudo docker run -dit --name ${CNAME} -p 9091:8080 ${INAME}
#

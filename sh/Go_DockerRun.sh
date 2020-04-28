#!/bin/sh
###
set -e
#
if [ $(whoami) != "root" ]; then
	echo "${0} should be run as root or via sudo."
	exit
fi
#
INAME="badapple"
CNAME="${INAME}_container"
#
###
# Instantiate and run container.
# -dit = --detached --interactive --tty
docker run -dit --name ${CNAME} -p 9091:8080 ${INAME}
#

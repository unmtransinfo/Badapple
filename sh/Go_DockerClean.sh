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
# Stop and clean up.
docker stop ${CNAME}
docker ps -a
docker rm ${CNAME}
docker rmi ${INAME}
#

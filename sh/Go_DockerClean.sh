#!/bin/sh
###
set -e
#
INAME="badapple"
CNAME="${INAME}_container"
#
###
# Stop and clean up.
sudo docker stop ${CNAME}
sudo docker ps -a
sudo docker rm ${CNAME}
sudo docker rmi ${INAME}
#

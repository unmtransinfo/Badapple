#!/bin/bash
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
INAME="badapple_db"
TAG="latest"
#
if [ ! -e "${cwd}/data" ]; then
	mkdir ${cwd}/data/
fi
#
sudo -u postgres pg_dump --no-privileges -Fc -d badapple >/home/data/Badapple/badapple.pgdump 
cp /home/data/Badapple/badapple.pgdump ${cwd}/data/
#
T0=$(date +%s)
#
###
# Build image from Dockerfile.
dockerfile="${cwd}/Dockerfile_Db"
docker build -f ${dockerfile} -t ${INAME}:${TAG} .
#
printf "Elapsed time: %ds\n" "$[$(date +%s) - ${T0}]"
#
rm -f ${cwd}/data/badapple.pgdump
#
docker images
#

#!/bin/bash
###
# https://docs.docker.com/network/
# https://docs.docker.com/network/bridge/
# Default network driver is "bridge".
# On a user-defined bridge network, containers can resolve each other
# by name (container ID) or alias (container name).
###
#
NETNAME="badapple"
#
INAME_DB="badapple_db"
INAME_UI="badapple_ui"
#
if [ $(whoami) != "root" ]; then
	echo "${0} should be run as root or via sudo."
	exit
fi
#
###
docker network rm $NETNAME
docker network create $NETNAME
#
docker network connect $NETNAME ${INAME_DB}_container
docker network connect $NETNAME ${INAME_UI}_container
#
docker network ls
#
docker exec ${INAME_UI}_container ping -c 1 ${INAME_DB}_container
#
docker exec -it ${INAME_UI}_container psql -h ${INAME_DB}_container -d badapple -U batman -c "SELECT name,version FROM dataset"
#
###
# If ok, app at: http://localhost:9092/badapple/badapple
###

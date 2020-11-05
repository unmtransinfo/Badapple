#!/bin/bash
###
# Instantiate and run containers.
# -dit = --detached --interactive --tty
###
cwd=$(pwd)
#
if [ $(whoami) != "root" ]; then
	echo "${0} should be run as root or via sudo."
	exit
fi
#
VTAG="latest"
#VTAG="v1.0.0"
#
###
# PostgreSQL db
INAME_DB="badapple_db"
#
DOCKERPORT_DB=5051
APPPORT_DB=5432
#
###
#IMG_DB="unmtransinfo/${INAME_DB}:${VTAG}"
IMG_DB="${INAME_DB}:${VTAG}"
docker run -dit --name "${INAME_DB}_container" -p ${DOCKERPORT_DB}:${APPPORT_DB} ${IMG_DB}
#
docker container logs "${INAME_DB}_container"
#
#
###
NSEC="60"
echo "Sleep ${NSEC} seconds while db server starting up..."
sleep $NSEC
###
# Test db before proceeding.
docker exec "${INAME_DB}_container" sudo -u postgres psql -l
docker exec "${INAME_DB}_container" sudo -u postgres psql -d badapple -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
docker exec "${INAME_DB}_container" sudo -u postgres psql -qA -d badapple -c "SELECT db_description,db_date_built FROM metadata"
###
#
###
# Tomcat
INAME_UI="badapple_ui"
#
DOCKERPORT_UI=9092
APPPORT_UI=8080
#
#IMG_UI="unmtransinfo/${INAME_UI}:${VTAG}"
IMG_UI="${INAME_UI}:${VTAG}"
docker run -dit --name "${INAME_UI}_container" -p ${DOCKERPORT_UI}:${APPPORT_UI} ${IMG_UI}
#
###
# Install ChemAxon license.cxl
docker exec ${INAME_UI}_container mkdir -p /usr/share/tomcat9/webapps/carlsbad/.chemaxon
LICFILE="/var/lib/tomcat9/.chemaxon/license.cxl"
if [ -e "${LICFILE}" ]; then
	docker cp ${LICFILE} ${INAME_UI}_container:/usr/share/tomcat9/webapps/carlsbad/.chemaxon
	docker exec ${INAME_UI}_container chown -R tomcat /usr/share/tomcat9/webapps/carlsbad/.chemaxon
else
	printf "ERROR: ChemAxon license file not found: "${LICFILE}"\n"
	printf "ChemAxon license file must be installed manually.\n"
fi
#
docker container logs "${INAME_UI}_container"
#
###
docker container ls -a
#
printf "Badapple PostgreSQL Endpoint: localhost:${DOCKERPORT_DB}\n" 
printf "Tomcat Web Application Manager: http://localhost:${DOCKERPORT_UI}/manager/html\n"
 
printf "Badapple-One Web Application: http://localhost:${DOCKERPORT_UI}/badapple/badapple\n" 
#
printf "Next run Go_DockerNetwork.sh\n"
#

#!/bin/sh
#
# derby.jar included by jchem.jar thus not required in CLASSPATH.
#############################################################################
#
#set -x
#
### Derby test:
#
export DBTYPE="derby"
export DBDIR=/home/data/derby
export DBNAME="badapple"
export DBSCHEMA="APP"
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbtype "$DBTYPE" \
	-dbdir "$DBDIR" -dbname "$DBNAME" -dbschema "$DBSCHEMA" \
	-describedb \
	-vvv
#
SCAFID=29
#
badapple.sh \
	-dbtype "$DBTYPE" \
	-dbdir "$DBDIR" -dbname "$DBNAME" -dbschema "$DBSCHEMA" \
	-describescaf -scafid $SCAFID \
	-vvv
#

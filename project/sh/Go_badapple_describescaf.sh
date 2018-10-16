#!/bin/sh
#
#
if [ $# -lt 1 ]; then
	echo "ERROR: syntax: `basename $0` <SCAFID>"
	echo "(Larger IDs usually faster.)"
	exit
fi
#
#LIBDIR=/home/app/lib
LIBDIR=$HOME/src/java/lib
CLASSPATH=$LIBDIR/unm_biocomp_badapple.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_db.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_hscaf.jar
CLASSPATH=$CLASSPATH:/home/app/lib/jchem.jar
CLASSPATH=$CLASSPATH:/home/app/lib/berkeleydb.jar
#
. `dirname $0`/ba_current_db.sh
echo "DBHOST = \"$DBHOST\""
echo "DBNAME = \"$DBNAME\""
echo "DBSCHEMA = \"$DBSCHEMA\""
#
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbhost "$DBHOST" -dbname "$DBNAME" -dbschema "$DBSCHEMA" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-describescaf $1 \
	-vvv
#

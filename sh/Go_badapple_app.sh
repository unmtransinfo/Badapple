#!/bin/sh
#
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
set -x
#
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbhost "$DBHOST" -dbname "$DBNAME" -dbschema "$DBSCHEMA" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-vvv
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbhost "$DBHOST" -dbname "$DBNAME" -dbschema "$DBSCHEMA" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-describedb \
	-vvv
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbhost "$DBHOST" -dbname "$DBNAME" -dbschema "$DBSCHEMA" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-describescaf 10142 \
	-vvv
#

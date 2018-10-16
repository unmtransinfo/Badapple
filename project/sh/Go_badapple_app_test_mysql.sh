#!/bin/sh
#
#
LIBDIR=$HOME/src/java/lib
CLASSPATH=$LIBDIR/unm_biocomp_badapple.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_db.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_hscaf.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_util.jar
LIBDIR=/home/app/lib
CLASSPATH=$CLASSPATH:$LIBDIR/jchem.jar
CLASSPATH=$CLASSPATH:$LIBDIR/mysql-connector-java-5.1.6.jar
#
# Note jchem.jar references MySql jar which may conflict.
#
SCAFID=29
#
#set -x
#
#############################################################################
### MySql test:
#
export DBTYPE="mysql"
export DBHOST="localhost"
export DBPORT="3306"
export DBNAME="badapple"
export DBUSR="www"
export DBPW="foobar"
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbtype "$DBTYPE" \
	-dbhost "$DBHOST" -dbport "$DBPORT" -dbname "$DBNAME" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-describescaf $SCAFID \
	-vvv
#

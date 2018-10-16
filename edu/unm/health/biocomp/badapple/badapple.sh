#!/bin/sh
#
if [ "`uname -s`" = "Darwin" ]; then
	APPDIR="/Users/app"
elif [ "`uname -s`" = "Linux" ]; then
	APPDIR="/home/app"
else
	APPDIR="/home/app"
fi
#
#LIBDIR=$HOME/src/badapple/lib
LIBDIR=$APPDIR/lib
#
CLASSPATH=$LIBDIR/unm_biocomp_badapple.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_hscaf.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_db.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_util.jar
#
CLASSPATH=$CLASSPATH:$APPDIR/ChemAxon/JChemSuite/lib/jchem.jar
#
CLASSPATH=$CLASSPATH:$LIBDIR/berkeleydb.jar
CLASSPATH=$CLASSPATH:$LIBDIR/postgresql-9.4.1208.jar
#
JAVAOPTS="-Xmx2G -Xms1G -XX:MaxMetaspaceSize=1G"
#
java $JAVAOPTS -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple $*
#

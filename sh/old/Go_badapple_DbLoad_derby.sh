#!/bin/sh
#
LIBDIR=/home/app/lib
CLASSPATH=$CLASSPATH:$LIBDIR/jchem.jar
#CLASSPATH=$CLASSPATH:$LIBDIR/derby.jar  ##jchem.jar includes Derby jars.
#
DBDIR=/home/data/derby
DBNAME="badapple"
#
#
#############################################################################
### This works, but too slow:
#
#ij <<__EOF__
#CONNECT 'jdbc:derby:$DBDIR/$DBNAME' ;
#run 'data/badapple-mysqldump.sql' ;
#__EOF__
#
#
#############################################################################
### Batch load method:
#
cwd=`dirname $0`
if [ $cwd = "." ]; then
	cwd=`pwd`
fi
datadir=${cwd}/data
#
set -x
for table in scaffold scaf2scaf compound sub2cpd scaf2cpd metadata ; do
	csvfile=${datadir}/${DBNAME}_${table}.csv
	#
	TABLE=`echo $table |tr '[a-z]' '[A-Z]'`
	#
	ij <<__EOF__
CONNECT 'jdbc:derby:$DBDIR/$DBNAME' ;
CALL SYSCS_UTIL.SYSCS_IMPORT_TABLE ('APP','$TABLE','$csvfile',',','"','UTF-8',1) ;
__EOF__
	#
done
#
#############################################################################
#

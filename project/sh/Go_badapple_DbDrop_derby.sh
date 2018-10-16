#!/bin/sh
#############################################################################
### Go_badapple_CreateDB_derby.sh
### 
### 
### Jeremy Yang
###  6 Jun 2013
#############################################################################
#
set -e
#
DBDIR="/home/data/derby"
DBNAME="badapple"
DBSCHEMA="APP"	#default
#
TMP_SQL_FILE="data/z.sql"
#
cat >$TMP_SQL_FILE <<__EOF__
CONNECT 'jdbc:derby:$DBDIR/$DBNAME' ;
--
DROP TABLE $DBSCHEMA.scaffold ;
DROP TABLE $DBSCHEMA.scaf2scaf ;
DROP TABLE $DBSCHEMA.compound ;
DROP TABLE $DBSCHEMA.sub2cpd ;
DROP TABLE $DBSCHEMA.scaf2cpd ;
DROP TABLE $DBSCHEMA.metadata ;
__EOF__
#
ij $TMP_SQL_FILE
#

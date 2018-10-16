#!/bin/sh
#############################################################################
### Go_badapple_DescribeDB.sh
### 
### Jeremy Yang
### 20 Jan 2017
#############################################################################
#
set -e
#
DB="badapple"
DBSCHEMA="public"
#
#
tables=`psql -q -d $DB -tAc "SELECT table_name FROM information_schema.tables WHERE table_schema='$DBSCHEMA'"`
#
for t in $tables ; do
	echo $t
	psql -P pager=off -q -d $DB -c "SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='$DBSCHEMA' AND table_name = '$t'"
	psql -q -d $DB -c "SELECT count(*) AS \"${t}_count\" FROM $DBSCHEMA.$t"
done
#

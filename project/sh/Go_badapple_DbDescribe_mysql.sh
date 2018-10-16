#!/bin/sh
#############################################################################
### Go_badapple_DescribeDB_mysql.sh
### 
### Jeremy Yang
### 30 Jan 2013
#############################################################################
#
set -e
#
DBNAME="badapple"
DBUSR="jjyang"
DBPW="assword"
#
for table in scaffold scaf2scaf compound sub2cpd scaf2cpd metadata ; do
	#
	mysql -u $DBUSR -p${DBPW} <<__EOF__
SELECT COUNT(*) AS ${table}_count
FROM $DBNAME.${table} ;
__EOF__
	#
done

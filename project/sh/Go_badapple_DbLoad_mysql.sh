#!/bin/sh
#############################################################################
### Go_badapple_LoadDB_mysql.sh
### 
### First run Go_badapple_Dump4Mysql.sh to dump PG tables.
### 
### Note that MySql "FILE" privilege needed to LOAD DATA.
### 
### Jeremy Yang
### 30 Jan 2013
#############################################################################
#
set -e
set -x
#
DBNAME="badapple"
DBUSR="jjyang"
DBPW="assword"
#
cwd=`pwd`
#
#mysqlfile=data/${DBNAME}_dump4mysql.sql
#
#mysql -u $DBUSR -p${DBPW} $DBNAME <$mysqlfile
#
#
# Faster to use LOAD DATA.
#
# defaults:
# FIELDS TERMINATED BY '\t' OPTIONALLY ENCLOSED BY '' ESCAPED BY '\\'
# LINES TERMINATED BY '\n' STARTING BY ''
#
tables="scaffold scaf2scaf compound sub2cpd scaf2cpd metadata"
#
for table in $tables ; do
	#
	datfile=${cwd}/data/${DBNAME}_dump4mysql_${table}.dat
	mysql -v -u $DBUSR -p${DBPW} $DBNAME <<__EOF__
LOAD DATA INFILE '${datfile}'
INTO TABLE ${table}
	;
__EOF__
	#
done
#
for table in $tables ; do
	#
	mysql -v -u $DBUSR -p${DBPW} $DBNAME <<__EOF__
OPTIMIZE TABLE ${table}
	;
__EOF__
	#
done
#
mysql -v -u $DBUSR -p${DBPW} $DBNAME <<__EOF__
UPDATE metadata SET db_date_built = CURRENT_TIMESTAMP ;
__EOF__
#

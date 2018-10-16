#!/bin/sh
#############################################################################
### Go_badapple_DropDB_mysql.sh
### 
### Jeremy Yang
### 29 Jan 2013
#############################################################################
#
set -e
#
DB="badapple"
DBUSR="jjyang"
DBPW="assword"
#
mysql -v -u $DBUSR -p${DBPW} $DB <<__EOF__
DROP DATABASE $DB ;
__EOF__

#!/bin/sh
#############################################################################
### Go_badapple_Export2CSVs.sh - Export database tables to CSV files.
### 
### Jeremy Yang
#############################################################################
#
#set -x
#
DBNAME="badapple"
DBSCHEMA="public"
#
cwd=`dirname $0`
if [ $cwd = "." ]; then
	cwd=`pwd`
fi
#
DATADIR=${cwd}/data
#
tables=$(psql -tP pager=off -d $DBNAME -c "SELECT table_name FROM information_schema.tables WHERE table_schema NOT IN ('information_schema','pg_catalog') ORDER BY table_name")
#
#
for table in ${tables} ; do
	#
	tsvfile=${DATADIR}/${DBNAME}_${DBSCHEMA}_${table}.tsv
	printf "%12s : %24s\n" $table $tsvfile
	#
	psql -d $DBNAME <<__EOF__
\COPY ${DBSCHEMA}.${table} TO '$tsvfile' DELIMITER E'\t' QUOTE '"' CSV HEADER
__EOF__
	#
done
#

#!/bin/sh
#
set -x
#
#
if [ $# -lt 4 ]; then
	printf "Syntax: %s DBNAME SCHEMA ASSAY_ID_FILE COMMENT\n" $0
	exit
fi
#
DBNAME=$1
SCHEMA=$2
ASSAY_ID_FILE=$3
COMMENT=$4
#
n_ass=`cat $ASSAY_ID_FILE |wc -l`
#
psql -d $DBNAME -c "DELETE FROM $SCHEMA.metadata"
psql -d $DBNAME -c "INSERT INTO $SCHEMA.metadata (db_description) VALUES ('${COMMENT}')"
psql -d $DBNAME -c "UPDATE $SCHEMA.metadata SET db_date_built = CURRENT_TIMESTAMP"
psql -d $DBNAME -c "UPDATE $SCHEMA.metadata SET median_ncpd_tested = (SELECT median(ncpd_tested) FROM $SCHEMA.scaffold)"
psql -d $DBNAME -c "UPDATE $SCHEMA.metadata SET median_nsub_tested = (SELECT median(nsub_tested) FROM $SCHEMA.scaffold)"
psql -d $DBNAME -c "UPDATE $SCHEMA.metadata SET median_nass_tested = (SELECT median(nass_tested) FROM $SCHEMA.scaffold)"
psql -d $DBNAME -c "UPDATE $SCHEMA.metadata SET median_nsam_tested = (SELECT median(nsam_tested) FROM $SCHEMA.scaffold)"
psql -d $DBNAME -c "UPDATE $SCHEMA.metadata SET nass_total=$n_ass"
#

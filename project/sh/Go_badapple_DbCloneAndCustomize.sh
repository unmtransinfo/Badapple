#!/bin/sh
#############################################################################
### Go_badapple_CloneAndCustomizeDB.sh
### 
###   * Create new schema from existing schema.
###   * Clone compound and scaffold tables, but delete statistics.
###   * Do not clone activity table.
###   * Generate statistics using old activity table and selected assay IDs.
### 
### "CREATE SCHEMA IF NOT EXISTS" requires PG 9.3+.
### 
### Jeremy Yang
### 17 Jul 2014
#############################################################################
#
set -e
#
DB="openchord"
#
SCHEMA_REF="badapple_pc2"
SCHEMA="badapple_pc1"
#
### Drop old if needed:
#Go_badapple_DropDB.sh $SCHEMA
#
SCHEMA_COMMENT="(derived from $SCHEMA_REF)"
#
PREFIX="data/pc_mlsmr_${SCHEMA}"
#
cwd=`pwd`
#
psql $DB <<__EOF__
CREATE SCHEMA $SCHEMA;
COMMENT ON SCHEMA $SCHEMA IS '$SCHEMA_COMMENT' ;
__EOF__
#
TABLES="scaffold scaf2scaf compound sub2cpd scaf2cpd metadata"
#
for table in $TABLES ; do
	printf "CREATE TABLE %s.%s ...\n" "$SCHEMA" "$table"
	psql $DB <<__EOF__
CREATE TABLE $SCHEMA.$table
	(LIKE $SCHEMA_REF.$table INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
	;
--
INSERT INTO $SCHEMA.$table
	SELECT * FROM $SCHEMA_REF.$table
	;
__EOF__
done
#
psql $DB <<__EOF__
UPDATE $SCHEMA.scaffold SET  (
	ncpd_total,
	ncpd_tested,
	ncpd_active,
	nsub_total,
	nsub_tested,
	nsub_active,
	nass_tested,
	nass_active,
	nsam_tested,
	nsam_active,
	pscore,
	prank )
	= (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL)
	;
UPDATE $SCHEMA.compound SET  (
	nsub_total,
	nsub_tested,
	nsub_active,
	nass_tested,
	nass_active,
	nsam_tested,
	nsam_active )
	= (0, 0, 0, 0, 0, 0, 0)
	;
UPDATE $SCHEMA.metadata SET  (
	db_description,
	median_ncpd_tested,
	median_nsub_tested,
	median_nass_tested,
	median_nsam_tested,
	nass_total )
	= ('$SCHEMA_COMMENT', 0, 0, 0, 0, 0 )
	;
__EOF__
#
psql $DB <<__EOF__
GRANT USAGE ON SCHEMA $SCHEMA TO www ;
GRANT SELECT ON ALL TABLES IN SCHEMA $SCHEMA TO www ;
GRANT UPDATE ON $SCHEMA.compound TO www ;
GRANT UPDATE ON $SCHEMA.scaffold TO www ;
__EOF__
#
#############################################################################
# Compute statistics from selected assays in activity table of reference schema.
ASSAY_ID_FILE="data/pc_mlp_selected_assays_pre-20110101.aid"
#
./badapple_assaystats_db_annotate.py \
	--annotate_compounds \
	--dbschema_activity badapple_pc2 \
	--dbschema badapple_pc1 \
	--assay_id_tag "aid" \
	--assay_id_file $ASSAY_ID_FILE \
	--vv
#
#	--no_write --n_max 10 \
#
./badapple_assaystats_db_annotate.py \
	--annotate_scaffolds \
	--dbschema_activity badapple_pc2 \
	--dbschema badapple_pc1 \
	--assay_id_tag "aid" \
	--assay_id_file $ASSAY_ID_FILE \
	--vv
#
#############################################################################
### Load metadata.  Calculate and load medians.
#
./Go_badapple_Update_metadata.sh "$SCHEMA" "$ASSAY_ID_FILE" "$SCHEMA_COMMENT"
#
#############################################################################
### Annotate scaffold table with computed Badapple scores.
###     Column "pscore" is added.
#
ofile=$cwd/${PREFIX}_scaf_scores.csv
#
./Go_badapple_score.sh "$SCHEMA" "$ofile"
./Go_badapple_scorerank.sh "$SCHEMA"
#

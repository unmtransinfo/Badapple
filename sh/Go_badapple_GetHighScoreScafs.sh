#!/bin/sh
#############################################################################
### Go_badapple_GetHighScoreScafs.sh
### 
### Jeremy Yang
### 28 Oct 2014
#############################################################################
#
DB="badapple"
DBSCHEMA="public"
PREFIX="data/${DB}"
#
#
set -x
#
PSCORE_CUTOFF="300.0"
TMPFILE="data/z.out"
#
csvfile=${PREFIX}_scaf_highscores.csv
smifile=${PREFIX}_scaf_highscores.smi
idfile=${PREFIX}_scaf_highscores.scafid
#
(psql -qA -d $DB <<__EOF__
	COPY	(SELECT
		scafsmi AS "smiles",
		id AS "scafid",
		ncpd_total AS "cTotal",
		ncpd_tested AS "cTested",
		ncpd_active AS "cActive",
		nsub_total AS "sTotal",
		nsub_tested AS "sTested",
		nsub_active AS "sActive",
		nass_tested AS "aTested",
		nass_active AS "aActive",
		nsam_tested AS "wTested",
		nsam_active AS "wActive",
		pscore AS "pScore",
		in_drug AS "inDrug"
	FROM
		$SCHEMA.scaffold
	WHERE
		pscore >= $PSCORE_CUTOFF
	ORDER BY
		id
) TO STDOUT WITH (FORMAT CSV,HEADER,DELIMITER ',',QUOTE '"')
	;
__EOF__
) \
	>$csvfile
#
N_HIGH=`cat $csvfile |sed -e '1d' |wc -l`
echo "N_HIGH = $N_HIGH"
#
csv_utils.py \
	--coltag "smiles" \
	--extractcol \
	>$smifile
#
csv_utils.py \
	--coltag "scafid" \
	--extractcol \
	>$idfile
#
#############################################################################
### Convert scaffold smiles to smarts:
#
smafile=${PREFIX}_scaf_highscores.smarts
#
hscaf_scaf2smarts.sh $smifile >$smafile
#
#
#############################################################################
# Top-scaffolds vs. assays matrix.
# Each cell value:  How many compounds are active?
# ... should be a score...
# Scaffolds, assays may exhibit patterns.  Visualize via heatmap.
#
psql -d $DB --no-align -ac "SELECT DISTINCT aid FROM $SCHEMA.activity ORDER BY aid" \
	|sed -e '1d' |sed -e '$d' \
	>${PREFIX}_tested.aid
#
badapple.py \
	--v \
	--scaf_assay_matrix \
	--scafidfile $idfile \
	--assayids ${PREFIX}_tested.aid \
	--assay_id_tag "aid" \
	--o ${PREFIX}_scafscore_vs_assay_matrix.csv
#

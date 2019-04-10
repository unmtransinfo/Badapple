#!/bin/sh
#############################################################################
### 
### Jeremy Yang
### 20 Jan 2017
#############################################################################
#
DB="badapple"
SCHEMA1="badapple_pc1"
SCHEMA2="public"
#
set -x
#
PSCORE_CUTOFF="300.0"
#
outfile=data/scaf_highscores_retro.csv
#
psql -o $outfile -F ',' -Aq $DB <<__EOF__
--
SELECT
	'"'||${SCHEMA1}.scaffold.scafsmi||'"' AS "smiles",
	${SCHEMA2}.scaffold.id AS "id_new",
	${SCHEMA2}.scaffold.pscore AS "pscore_new",
        ${SCHEMA2}.scaffold.nsub_tested AS "sTested_new",
        ${SCHEMA2}.scaffold.nsub_active AS "sActive_new",
        ${SCHEMA2}.scaffold.nass_tested AS "aTested_new",
        ${SCHEMA2}.scaffold.nass_active AS "aActive_new",
        ${SCHEMA2}.scaffold.nsam_tested AS "wTested_new",
        ${SCHEMA2}.scaffold.nsam_active AS "wActive_new",
	${SCHEMA1}.scaffold.id AS "id_old",
	${SCHEMA1}.scaffold.pscore AS "pscore_old",
        ${SCHEMA1}.scaffold.nsub_tested AS "sTested_old",
        ${SCHEMA1}.scaffold.nsub_active AS "sActive_old",
        ${SCHEMA1}.scaffold.nass_tested AS "aTested_old",
        ${SCHEMA1}.scaffold.nass_active AS "aActive_old",
        ${SCHEMA1}.scaffold.nsam_tested AS "wTested_old",
        ${SCHEMA1}.scaffold.nsam_active AS "wActive_old",
        (${SCHEMA2}.scaffold.nsam_tested - ${SCHEMA1}.scaffold.nsam_tested) AS "wTested_diff"
FROM
	${SCHEMA2}.scaffold
JOIN
	${SCHEMA1}.scaffold ON (${SCHEMA1}.scaffold.scafsmi = ${SCHEMA2}.scaffold.scafsmi)
WHERE
	${SCHEMA1}.scaffold.pscore >= ${PSCORE_CUTOFF}
ORDER BY "wTested_diff" DESC
	;
--
__EOF__

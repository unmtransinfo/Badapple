#!/bin/sh
#############################################################################
### Go_badapple_LoadDB.sh
### 
### OpenChord version.
### 
### BARD version.
### 
### This version we load the compound stats, then compute the scaffold stats using the
### database, and update the database on the fly.
###
### Note: psql COPY requires superuser role.
### Do as postgres or grant and revoke privilege: 
###	ALTER ROLE jjyang WITH SUPERUSER ;
###	ALTER ROLE jjyang WITH NOSUPERUSER ;
###
### Jeremy Yang
### 23 Jan 2013
#############################################################################
set -e
set -x
#
PGSU="postgres"
DB="openchord"
#
SCHEMA="badapple"
PREFIX="data/bard_mlsmr"
#
cwd=`pwd`
#
sudo -u postgres psql $DB <<__EOF__
ALTER ROLE jjyang WITH SUPERUSER ;
__EOF__
#############################################################################
### Step 1) Load scafs with scafids; load scaf2scaf with parentage links.
### See GoHscaf*.sh ; scaffold and scaf2scaf tables loaded directly by
### scaffold program.
#
#############################################################################
### Step 2) Load scaf2cpd links.
### Header (1st) line should be: "scafid,cid"
#
./cpdscaf_2csv.py \
	--i ${PREFIX}_hscaf_out.smi \
	--o ${PREFIX}_hscaf_out.csv
#
infile=$cwd/${PREFIX}_hscaf_out.csv
#
#PostgreSQL-8
#sql="COPY $SCHEMA.scaf2cpd FROM '${infile}' WITH DELIMITER ',' CSV HEADER;"
#
#PostgreSQL-9
sql="COPY $SCHEMA.scaf2cpd FROM '${infile}' WITH (FORMAT CSV,DELIMITER ',',HEADER TRUE);"
#
psql $DB <<__EOF__
${sql}
__EOF__
#
#############################################################################
### Step 3b) Load compounds with CIDs.  SMILES are canonicalized using
### openbabel.cansmiles() and openbabel.isosmiles().
./compounds_2sql.py \
	--dbschema $SCHEMA \
	--i ${PREFIX}_compounds.smi \
	--o ${PREFIX}_compounds.sql
#
psql -q $DB < ${PREFIX}_compounds.sql
#
#############################################################################
### Step 3b) Load CID to SID relations.
#
echo 'sid,cid' >${PREFIX}_sid2cid.csv
#
cat \
	${PREFIX}_substances.smi \
	| awk '{print $2 "," $3}' \
	>>${PREFIX}_sid2cid.csv
#
infile=$cwd/${PREFIX}_sid2cid.csv
#
#PostgreSQL-8
#sql="COPY $SCHEMA.sub2cpd FROM '${infile}' WITH DELIMITER ',' CSV HEADER;"
#
#PostgreSQL-9
sql="COPY $SCHEMA.sub2cpd FROM '${infile}' WITH (FORMAT CSV,DELIMITER ',',HEADER TRUE);"
#
psql $DB <<__EOF__
${sql}
__EOF__
#
#############################################################################
# Step 4) Load substance activities.
#
# CSV file produced by bard_query.py.
# Header (1st) line should be: "eid,sid,outcome"
#
infile=$cwd/${PREFIX}_hts_activity.csv
#
#PostgreSQL-8
#sql="COPY $SCHEMA.activity FROM '${infile}' WITH DELIMITER ',' CSV HEADER;"
#
#PostgreSQL-9
sql="COPY $SCHEMA.activity FROM '${infile}' WITH (FORMAT CSV,DELIMITER ',',HEADER TRUE);"
#
psql $DB <<__EOF__
${sql}
__EOF__
#
sudo -u postgres psql $DB <<__EOF__
ALTER ROLE jjyang WITH NOSUPERUSER ;
__EOF__
#############################################################################
### Step 5) Canonicalize scaffold smiles with OpenChord.
### For database use and efficiency, although the smiles were canonicalized
### previously by JChem during scaffold analysis process.
##
psql -q $DB <<__EOF__
UPDATE ${SCHEMA}.scaffold SET scafsmi = openbabel.cansmiles(scafsmi) ;
__EOF__
#
#############################################################################
### Step 6) Index tables.  Greatly improves search performance.
##
psql $DB <<__EOF__
CREATE INDEX scaf_scafid_idx ON $SCHEMA.scaffold (id) ;
CREATE INDEX scaf_smi_idx on $SCHEMA.scaffold (scafsmi) ;
CREATE INDEX cpd_cid_idx ON $SCHEMA.compound (cid) ;
CREATE INDEX scaf2cpd_scafid_idx ON $SCHEMA.scaf2cpd (scafid) ;
CREATE INDEX scaf2cpd_cid_idx ON $SCHEMA.scaf2cpd (cid) ;
CREATE INDEX sub2cpd_cid_idx ON $SCHEMA.sub2cpd (cid) ;
CREATE INDEX sub2cpd_sid_idx ON $SCHEMA.sub2cpd (sid) ;
CREATE INDEX act_sid_idx ON $SCHEMA.activity (sid) ;
CREATE INDEX act_eid_idx ON $SCHEMA.activity (eid) ;
__EOF__
#
#############################################################################
### Step 7) Generate compound activity statistics.  Populate/annotate compound table with calculated assay stats.
# (sTotal,sTested,sActive,aTested,aActive,wTested,wActive)
#
./Go_badapple_AnnotateCpds.sh $SCHEMA
# 
#############################################################################
### Step 8) Generate scaf activity statistics.  Populate/annotate scaffold table with calculated assay stats.
### Scaffold table must be ALTERed to contain activity statistics.
# (cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive)
#
./Go_badapple_AnnotateScafs.sh $SCHEMA
#
#############################################################################
### Step 9a) Generate scaffold analysis of drug molecule file. 
###         
./GoHscaf_drugs.sh
### 
#############################################################################
### Step 9b) Load in_drug scaffold annotations.
#
./drug_scafs_2sql.py \
	--i=data/drugs_hscaf_scaf.smi \
	--o=data/drugs_hscaf_scaf.sql \
	--dbschema=$SCHEMA \
	--v
#
psql -q $DB < data/drugs_hscaf_scaf.sql
#
psql $DB <<__EOF__
UPDATE $SCHEMA.scaffold SET in_drug=FALSE WHERE in_drug IS NULL ;
__EOF__
#
#############################################################################
### Step 10) How many experiments?
### 
### ./Go_badapple_DumpAssayIDs.sh $SCHEMA 'eid'
#
eidfile=data/${SCHEMA}_tested.eid
#
n_eid=`cat $eidfile |wc -l`
#############################################################################
### Step 11) Load metadata.  Define custom function, calculate and load medians.
#
psql $DB < sql/create_median_function.sql
#
./Go_badapple_Update_metadata.sh $SCHEMA
#
#############################################################################
### Step 12) Annotate scaffold table with computed Badapple scores.
###	Column "pscore" is added.
#
ofile=$cwd/${PREFIX}_scaf_scores.csv
./Go_badapple_score.sh $SCHEMA $ofile
./Go_badapple_scorerank.sh $SCHEMA
#
#############################################################################
### Step *) [Optional] Clear activity table to save space.
#psql $DB <<__EOF__
#DELETE FROM $SCHEMA.activity ;
#__EOF__

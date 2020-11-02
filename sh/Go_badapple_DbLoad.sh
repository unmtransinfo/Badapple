#!/bin/bash
#############################################################################
### Go_badapple_LoadDB.sh
### 
### PubChem version. PubChem activity associated with CIDs & AIDs.
### 
### This version we load the compound stats, then compute the scaffold stats using the
### database, and update the database on the fly.
###
### Note: psql COPY requires superuser role.
### Do as postgres or grant and revoke privilege: 
###	ALTER ROLE ${USER} WITH SUPERUSER ;
###	ALTER ROLE ${USER} WITH NOSUPERUSER ;
#############################################################################
#
set -x
#
DBNAME="badapple"
DBHOST="localhost"
#
SCHEMA="public"
#
ASSAY_ID_TAG='aid'
#
cwd=`pwd`
DATADIR=$cwd/data
#
PREFIX="pc_mlsmr"
#
#############################################################################
### Step 1) Load scafs with scafids; load scaf2scaf with parentage links.
### See Go_badapple_Hscaf*.sh ; scaffold and scaf2scaf tables loaded directly by
### scaffold program.
### --------------------------------------------
### HOWEVER: If scaffold and scaf2scaf tables need to be reloaded, this
### can be done thus:
#${cwd}/python/scaf_2inserts.py --v \
#	--dbschema $SCHEMA \
#	--i ${DATADIR}/${PREFIX}_hscaf_scaf.smi \
#	--o ${DATADIR}/${PREFIX}_hscaf_scaf.sql
#psql -q $DBNAME -f ${DATADIR}/${PREFIX}_hscaf_scaf.sql
#############################################################################
#
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.scaffold IS 'Scaffold definitions by hier_scaffolds, badapple_assaystats_db_annotate.py.'"
#
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.scaf2scaf IS 'Scaffold parentage by hier_scaffolds.'"
#
### Step 2) Load scaf2cpd links.
### Header (1st) line should be: "scafid,cid"
#
csvfile=${DATADIR}/${PREFIX}_hscaf_out.csv
${cwd}/python/cpdscaf_2csv.py \
	--i ${DATADIR}/${PREFIX}_hscaf_out.smi \
	--o ${csvfile}
#
#PostgreSQL-9
cat ${csvfile} |psql -d $DBNAME -c "COPY $SCHEMA.scaf2cpd FROM STDIN WITH (FORMAT CSV,DELIMITER ',',HEADER TRUE)"
#
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.scaf2cpd IS 'From ${PREFIX}_hscaf_out.smi via cpdscaf_2csv.py.'"
#
#############################################################################
### Step 3b) Load compounds with CIDs. 
### 
### With OpenChord/OpenBabel, canonicalize on load thus:
### SMILES canonicalized using openbabel.cansmiles(), openbabel.isosmiles().
###
#${cwd}/python/compounds_2sql_ob.py \
#	--dbschema $SCHEMA \
#	--i ${DATADIR}/${PREFIX}_compounds.smi \
#	|psql -q -d $DBNAME
###
### With RDKit, load raw SMILES and canonicalize/configure afterwards:
${cwd}/python/compounds_2sql.py \
	--dbschema $SCHEMA \
	--i ${DATADIR}/${PREFIX}_compounds.smi \
	|psql -q -d $DBNAME
###
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.compound IS 'From ${PREFIX}_compounds.smi via cpds_2sql.py, badapple_assaystats_db_annotate.py.'"
#
#############################################################################
### Step 3c) Load CID to SID relations.
#
csvfile=${DATADIR}/${PREFIX}_sid2cid.csv
#
#PostgreSQL-9
cat ${csvfile} |psql -d $DBNAME -c "COPY $SCHEMA.sub2cpd FROM STDIN WITH (FORMAT CSV,DELIMITER ',',HEADER TRUE)"
#
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.sub2cpd IS 'From ${PREFIX}_sid2cid.csv, from PubChem.'"
#
#############################################################################
# Step 4) Load assay-substance activities.
#
# 2017: UPDATED PROCESS.  USING FTP-MIRROR FILES.  PREVIOUS PUG/REST NOT RELIABLE.
# See pubchem_ftp_assay_results.py
#
#gzcsvfile=${DATADIR}/${PREFIX}_assaystats_act.csv.gz-20140903
gzcsvfile=${DATADIR}/${PREFIX}_mlp_assaystats_act.csv.gz
#
psql -d $DBNAME -c "DELETE FROM ${SCHEMA}.activity"
gunzip -c $gzcsvfile |sed -e '1d' |psql -d $DBNAME -c "COPY $SCHEMA.activity (aid,sid,outcome) FROM STDIN WITH (FORMAT CSV,DELIMITER ',',HEADER FALSE)"
#
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.activity IS 'From: PubChem-FTP, pubchem_ftp_assay_results.py, ${gzcsvfile}.'"
#
#############################################################################
### RDKit:
### Step 5) RDKit configuration.
#############################################################################
### Works with rdkit-Release_2019_09_03 + Boost ? on Ubuntu 18.04-LTS
#############################################################################
### Step 5a) compound -> mols.
#
sudo -u postgres psql -d $DBNAME -c 'CREATE EXTENSION rdkit'
### Create mols table for RDKit structural searching.
psql -d $DBNAME -f sql/create_rdkit_mols_table.sql
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.mols IS 'For RDKit structural searching.'"
psql -d $DBNAME -c "CREATE INDEX molidx ON ${SCHEMA}.mols USING gist(mol)"
psql -d $DBNAME -c "UPDATE ${SCHEMA}.compound SET cansmi = mol_to_smiles(mols.mol) FROM ${SCHEMA}.mols WHERE compound.cid = mols.cid"
#
#############################################################################
### Step 5b) Canonicalize scaffold smiles.
### For database use and efficiency, although the smiles were canonicalized
### previously by JChem during scaffold analysis process.  Must be consistent
### between query and db.
###
### Create mols_scaf table for RDKit structural searching.
psql -d $DBNAME -f sql/create_rdkit_mols_scaf_table.sql
psql -d $DBNAME -c "COMMENT ON TABLE ${SCHEMA}.mols_scaf IS 'For RDKit structural searching.'"
psql -d $DBNAME -c "CREATE INDEX molscafidx ON ${SCHEMA}.mols_scaf USING gist(scafmol)"
psql -q -d $DBNAME -c "UPDATE ${SCHEMA}.scaffold SET scafsmi = mol_to_smiles(mols_scaf.scafmol) FROM mols_scaf WHERE mols_scaf.id = scaffold.id"
#
#############################################################################
### Step 6) Index tables.  Greatly improves search performance.
##
psql -d $DBNAME -c "CREATE INDEX scaf_scafid_idx ON $SCHEMA.scaffold (id)"
psql -d $DBNAME -c "CREATE INDEX scaf_smi_idx on $SCHEMA.scaffold (scafsmi)"
psql -d $DBNAME -c "CREATE INDEX mols_scaf_scafid_idx ON $SCHEMA.mols_scaf (id)"
psql -d $DBNAME -c "CREATE INDEX cpd_cid_idx ON $SCHEMA.compound (cid)"
psql -d $DBNAME -c "CREATE INDEX mols_cid_idx ON $SCHEMA.mols (cid)"
psql -d $DBNAME -c "CREATE INDEX scaf2cpd_scafid_idx ON $SCHEMA.scaf2cpd (scafid)"
psql -d $DBNAME -c "CREATE INDEX scaf2cpd_cid_idx ON $SCHEMA.scaf2cpd (cid)"
psql -d $DBNAME -c "CREATE INDEX sub2cpd_cid_idx ON $SCHEMA.sub2cpd (cid)"
psql -d $DBNAME -c "CREATE INDEX sub2cpd_sid_idx ON $SCHEMA.sub2cpd (sid)"
psql -d $DBNAME -c "CREATE INDEX act_sid_idx ON $SCHEMA.activity (sid)"
psql -d $DBNAME -c "CREATE INDEX act_aid_idx ON $SCHEMA.activity (aid)"
#psql -d $DBNAME -c "REINDEX TABLE $SCHEMA.activity"
#
#############################################################################
### Step 7) Generate compound activity statistics.  Populate/annotate
### compound table with calculated assay stats.
# (sTotal,sTested,sActive,aTested,aActive,wTested,wActive)
#
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.compound ADD COLUMN nsub_total INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.compound ADD COLUMN nsub_tested INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.compound ADD COLUMN nsub_active INTEGER"
psql -d $DBNAME -c "UPDATE $SCHEMA.compound SET (nsub_total, nsub_tested, nsub_active)  = (NULL, NULL, NULL)"
#
${cwd}/python/badapple_assaystats_db_annotate.py \
	--annotate_compounds \
	--assay_id_tag $ASSAY_ID_TAG \
	--dbhost $DBHOST \
	--dbname $DBNAME \
	--dbschema $SCHEMA \
	--dbschema_activity $SCHEMA \
	--dbusr $DBUSR \
	--dbpw $DBPW \
	--v
# 
#############################################################################
### Step 8) Generate scaf activity statistics.  Populate/annotate scaffold table with calculated assay stats.
### Scaffold table must be ALTERed to contain activity statistics.
# (cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive)
#
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN ncpd_total INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN ncpd_tested INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN ncpd_active INTEGER"
psql -d $DBNAME -c "UPDATE $SCHEMA.scaffold SET (ncpd_total, ncpd_tested, ncpd_active)  = (NULL, NULL, NULL)"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nsub_total INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nsub_tested INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nsub_active INTEGER"
psql -d $DBNAME -c "UPDATE $SCHEMA.scaffold SET (nsub_total, nsub_tested, nsub_active)  = (NULL, NULL, NULL)"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nass_tested INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nass_active INTEGER"
psql -d $DBNAME -c "UPDATE $SCHEMA.scaffold SET (nass_tested, nass_active)  = (NULL, NULL)"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nsam_tested INTEGER"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN nsam_active INTEGER"
psql -d $DBNAME -c "UPDATE $SCHEMA.scaffold SET (nsam_tested, nsam_active)  = (NULL, NULL)"
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN in_drug BOOLEAN"
psql -d $DBNAME -c "UPDATE $SCHEMA.scaffold SET in_drug  = NULL"
#
#(~5h but ~4h to 50%, since top scafs have more data.)
${cwd}/python/badapple_assaystats_db_annotate.py \
	--annotate_scaffolds \
	--assay_id_tag $ASSAY_ID_TAG \
	--dbhost $DBHOST \
	--dbname $DBNAME \
	--dbschema $SCHEMA \
	--dbschema_activity $SCHEMA \
	--dbusr $DBUSR \
	--dbpw $DBPW \
	--v
#
###
# 11 Aug 2017
# n_scaf: 151500 ; elapsed time: 3d:23h:13m:51s (100.0% done)
# badapple_assaystats_db_annotate.py: total scaffolds: 151528
# badapple_assaystats_db_annotate.py: total compounds: 1444273
# badapple_assaystats_db_annotate.py: total substances: 1686880
# badapple_assaystats_db_annotate.py: total outcomes: 728297101
# badapple_assaystats_db_annotate.py: total scaffold records modified: 151528
# badapple_assaystats_db_annotate.py: total errors: 0
# badapple_assaystats_db_annotate.py: total elapsed time: 3d:23h:13m:51s
# badapple_assaystats_db_annotate.py: 2017-08-11 07:40:04
###
#
#
#############################################################################
### Step 9a) Generate scaffold analysis of drug molecule file. 
###
./Go_badapple_Hscaf_drugs.sh
###
#############################################################################
### Step 9b) Load in_drug scaffold annotations.
#
${cwd}/python/drug_scafs_2sql.py \
	--i data/drugcentral_hscaf_scaf.smi \
	--dbschema $SCHEMA \
	--v \
	|psql -d $DBNAME
#
psql -d $DBNAME -c "UPDATE $SCHEMA.scaffold SET in_drug=FALSE WHERE in_drug IS NULL"
#
#############################################################################
### Step 10) How many assays?
### 
#
ASSAY_ID_FILE=$DATADIR/${DBNAME}_tested.${ASSAY_ID_TAG}
psql -q --no-align -d $DBNAME \
	-c "SELECT DISTINCT ${ASSAY_ID_TAG} FROM $SCHEMA.activity ORDER BY ${ASSAY_ID_TAG}" \
	|sed -e '1d' |sed -e '$d' \
	>$ASSAY_ID_FILE
###
#
ASSAY_ACTIVE_ID_FILE=$DATADIR/${DBNAME}_active.${ASSAY_ID_TAG}
psql -q --no-align -d $DBNAME \
	-c "SELECT DISTINCT ${ASSAY_ID_TAG} FROM $SCHEMA.activity WHERE outcome=2 ORDER BY ${ASSAY_ID_TAG}" \
	|sed -e '1d' |sed -e '$d' \
	>$ASSAY_ACTIVE_ID_FILE
#
#
n_ass=`cat $ASSAY_ID_FILE |wc -l`
printf "N_ASS = %d\n" $n_ass
#
#############################################################################
### Step 11) Load metadata.  Define custom function, calculate and load medians.
#
psql -d $DBNAME -f sql/create_median_function.sql
#
DBCOMMENT='Badapple Db (MLSMR compounds, PubChem HTS assays w/ 20k+ compounds)'
psql -d $DBNAME -c "COMMENT ON DATABASE ${DBNAME} IS '$DBCOMMENT'"
#
./Go_badapple_DbMetadata_update.sh $DBNAME $SCHEMA $ASSAY_ID_FILE "$DBCOMMENT"
#
#############################################################################
### Step 12a) Annotate scaffold table with computed scores, add	column "pscore".
#
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN pscore FLOAT NULL"
#
opts="-v -annotate_scaf"
opts="$opts -dbtype postgres -dbport 5432"
opts="$opts -dbname $DBNAME -dbschema $SCHEMA -dbusr $DBUSR -dbpw $DBPW"
#
java -classpath ${cwd}/unm_biocomp_badapple/target/unm_biocomp_badapple-0.0.1-SNAPSHOT-jar-with-dependencies.jar edu.unm.health.biocomp.badapple.badapple_scaf $opts
#
#
### Step 12b) Annotate scaffold table with score rank, add column "prank".
#
psql -d $DBNAME -c "ALTER TABLE $SCHEMA.scaffold ADD COLUMN prank INT NULL"
###
# Sub-select needed else: "ERROR: cannot use window function in UPDATE"
#
psql -d $DBNAME <<__EOF__
UPDATE $SCHEMA.scaffold s
SET prank = x.pr
FROM (
        SELECT id, rank() OVER (ORDER BY pscore DESC) AS pr
        FROM $SCHEMA.scaffold s2
        WHERE pscore IS NOT NULL
        ) AS x
WHERE s.id = x.id
AND s.pscore IS NOT NULL
        ;
__EOF__
#
#############################################################################
### Step *) [Optional] Clear activity table to save space.
#psql -d $DBNAME -c "DELETE FROM $SCHEMA.activity"

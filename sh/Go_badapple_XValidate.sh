#!/bin/sh
#############################################################################
### Badapple cross-validation test
### Compare compound scores (highest scoring scaffold).
#############################################################################
### K-fold validation.
#############################################################################
#
set -e
#set -x
#
DBNAME="badapple"
DBSCHEMA="public"
#
K=5
#
Ntotal=`psql -d $DBNAME -tc "SELECT COUNT(cid) FROM ${DBSCHEMA}.compound" |sed -e 's/ //g'`
echo "Ntotal = $Ntotal"
#
#Step 0a: Clean up
psql -d $DBNAME -c "DROP TABLE IF EXISTS ${DBSCHEMA}.compound_xvset"
#
#Step 0b: create partition membership table with CIDs, K subsets.
psql -d $DBNAME -c "SELECT cid INTO ${DBSCHEMA}.compound_xvset FROM ${DBSCHEMA}.compound"
psql -d $DBNAME -c "ALTER TABLE ${DBSCHEMA}.compound_xvset ADD COLUMN xvset INTEGER"
psql -d $DBNAME -c "UPDATE ${DBSCHEMA}.compound_xvset SET xvset = FLOOR(1 + ${K} * RANDOM())"
psql -d $DBNAME -c "CREATE INDEX cpd_xvset ON ${DBSCHEMA}.compound_xvset (xvset)"
psql -d $DBNAME -c "SELECT COUNT(cid),xvset FROM ${DBSCHEMA}.compound_xvset GROUP BY xvset ORDER BY xvset"
###
### LOOP, K-fold, I = [1-K]
I=0
while [ $I -lt $K ]; do
	I=`expr $I + 1`
	echo "I = ${I}:"
	#
	date
	#
	#if [ $I -lt 3 ]; then
	#	echo "DEBUG: skip I=${I}..."
	#	continue
	#fi
	#
	###
	#Step 0a: Clean up
	psql -d $DBNAME -c "DROP TABLE IF EXISTS ${DBSCHEMA}.compound_test"
	psql -d $DBNAME -c "DROP TABLE IF EXISTS ${DBSCHEMA}.compound_train"
	psql -d $DBNAME -c "DROP TABLE IF EXISTS ${DBSCHEMA}.scaffold_train"
	###
	#
	#
	Ntest=`psql -d $DBNAME -tc "SELECT COUNT(c.cid) FROM ${DBSCHEMA}.compound c JOIN ${DBSCHEMA}.compound_xvset cxv ON c.cid = cxv.cid WHERE cxv.xvset = ${I}" |sed -e 's/ //g'`
	printf "[I=$I] Ntest = $Ntest\n"
	Ntrain=`expr $Ntotal - $Ntest`
	printf "[I=$I] Ntrain = $Ntrain\n"
	#
	#Step 1: select Ntest cpds, partition dataset
	#
	psql -d $DBNAME <<__EOF__
SELECT
	c.cid,
	c.nsub_total,
	c.nsub_tested,
	c.nsub_active,
	c.nass_tested,
	c.nass_active,
	c.nsam_tested,
	c.nsam_active
INTO
	${DBSCHEMA}.compound_test
FROM
	${DBSCHEMA}.compound c
JOIN
	${DBSCHEMA}.compound_xvset cxv ON c.cid = cxv.cid
WHERE
	cxv.xvset = ${I}
	;
__EOF__
	#
	psql -d $DBNAME <<__EOF__
SELECT
	c.cid,
	c.nsub_total,
	c.nsub_tested,
	c.nsub_active,
	c.nass_tested,
	c.nass_active,
	c.nsam_tested,
	c.nsam_active
INTO
	${DBSCHEMA}.compound_train
FROM
	${DBSCHEMA}.compound c
JOIN
	${DBSCHEMA}.compound_xvset cxv ON c.cid = cxv.cid
WHERE
	cxv.xvset != ${I}
	;
__EOF__
	#
	psql -d $DBNAME -c "CREATE INDEX cpd_test_cid ON ${DBSCHEMA}.compound_test (cid)"
	psql -d $DBNAME -c "CREATE INDEX cpd_train_cid ON ${DBSCHEMA}.compound_train (cid)"
	#
	psql -d $DBNAME -c "UPDATE ${DBSCHEMA}.compound_train SET (nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active) = (NULL,NULL,NULL,NULL,NULL,NULL,NULL)"
	#
	#Step 2a: new table for training scaffolds and scores without testset
	#(Specify columns, or get scafid and cid from JOIN.)
	#
	psql -d $DBNAME <<__EOF__
SELECT
	s.id,
	s.ncpd_total,
	s.ncpd_tested,
	s.ncpd_active,
	s.nsub_total,
	s.nsub_tested,
	s.nsub_active,
	s.nass_tested,
	s.nass_active,
	s.nsam_tested,
	s.nsam_active,
	s.pscore
INTO
	${DBSCHEMA}.scaffold_train
FROM
	${DBSCHEMA}.scaffold s
JOIN
	${DBSCHEMA}.scaf2cpd ON (scaf2cpd.scafid = s.id)
JOIN
	${DBSCHEMA}.compound_xvset cxv ON scaf2cpd.cid = cxv.cid
WHERE
	cxv.xvset = ${I}
	;
__EOF__
	#Step 2b: new table for test scaffolds (convenience)
	#
	psql -d $DBNAME <<__EOF__
SELECT DISTINCT
	s.id,
	s.ncpd_total,
	s.ncpd_tested,
	s.ncpd_active,
	s.nsub_total,
	s.nsub_tested,
	s.nsub_active,
	s.nass_tested,
	s.nass_active,
	s.nsam_tested,
	s.nsam_active,
	s.pscore
INTO
	${DBSCHEMA}.scaffold_test
FROM
	${DBSCHEMA}.scaffold s
JOIN
	${DBSCHEMA}.scaf2cpd ON (scaf2cpd.scafid = s.id)
JOIN
	${DBSCHEMA}.compound_xvset cxv ON scaf2cpd.cid = cxv.cid
WHERE
	cxv.xvset != ${I}
	;
__EOF__
	#
	psql -d $DBNAME -c "CREATE INDEX scaf_train_id ON ${DBSCHEMA}.scaffold_train (id)"
	#
	psql -d $DBNAME -c "UPDATE ${DBSCHEMA}.scaffold_train SET (ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,pscore) = (NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)"
	#
	Ntest_rows=`psql -d $DBNAME -tc "SELECT COUNT(cid) FROM ${DBSCHEMA}.compound_test" |sed -e 's/ //g'`
	if [ $Ntest_rows -ne $Ntest ]; then
		printf "ERROR: test rows !- Ntest (%d!=%d)\n" $Ntest_rows $Ntest
		exit
	fi
	Ntrain_rows=`psql -d $DBNAME -tc "SELECT COUNT(cid) FROM ${DBSCHEMA}.compound_train" |sed -e 's/ //g'`
	if [ $Ntrain_rows -ne $Ntrain ]; then
		printf "ERROR: train rows !- Ntrain (%d!=%d)\n" $Ntrain_rows $Ntrain
		exit
	fi
	#
	psql -d $DBNAME -c "SELECT COUNT(DISTINCT id) AS \"n_scaf_test_unknown\" FROM ${DBSCHEMA}.scaffold_test"
	psql -d $DBNAME -c "SELECT COUNT(DISTINCT id) AS \"n_scaf_test_unknown\" FROM ${DBSCHEMA}.scaffold_test WHERE id NOT IN (SELECT DISTINCT id FROM ${DBSCHEMA}.scaffold_train)"
	#
	###
	#Step 3: Compute scaffold_train statistics, scores
	#Tmp tables for speed.
	#
	printf "COMPUTING SCAFFOLD_TRAIN STATISTICS (%s)...\n" "tested samples, compounds, substances"
	#(Cannot do n_ass in this step, since assays for cpds must be merged, counted uniquely at the scaffold level.)
	#
	psql -d $DBNAME <<__EOF__
SELECT
	COUNT(a.outcome) AS "n_sam",
	COUNT(DISTINCT a.sid) AS "n_sub",
	s2c.cid
INTO
	${DBSCHEMA}.tmp
FROM
	${DBSCHEMA}.activity a
JOIN
	${DBSCHEMA}.sub2cpd s2c ON (a.sid = s2c.sid)
GROUP BY
	s2c.cid
	;
--
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	nsam_tested = t.n_sam,
	nsub_tested = t.n_sub
FROM
	(SELECT
		SUM(${DBSCHEMA}.tmp.n_sam) AS "n_sam",
		SUM(${DBSCHEMA}.tmp.n_sub) AS "n_sub",
		scafid
	FROM
		${DBSCHEMA}.tmp
	JOIN
		${DBSCHEMA}.scaf2cpd ON (${DBSCHEMA}.tmp.cid = ${DBSCHEMA}.scaf2cpd.cid)
	GROUP BY
		scafid
	) t
WHERE
	${DBSCHEMA}.scaffold_train.id = t.scafid
	;
--
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	ncpd_tested = t.n_cpd
FROM
	(SELECT
		COUNT(DISTINCT cid) AS "n_cpd",
		scafid
	FROM
		${DBSCHEMA}.scaf2cpd
	GROUP BY
		scafid
	) t
WHERE
	${DBSCHEMA}.scaffold_train.id = t.scafid
	;
__EOF__
	#
	psql -d $DBNAME -c "DROP TABLE ${DBSCHEMA}.tmp"
	#
	printf "COMPUTING SCAFFOLD_TRAIN STATISTICS (%s)...\n" "tested assays"
	#
	psql -d $DBNAME <<__EOF__
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	nass_tested = t.n_ass
FROM
	(SELECT
		COUNT(DISTINCT a.aid) AS "n_ass",
		scaf2cpd.scafid
	FROM
		${DBSCHEMA}.activity a
	JOIN
		${DBSCHEMA}.sub2cpd ON (a.sid = sub2cpd.sid)
	JOIN
		${DBSCHEMA}.scaf2cpd ON (sub2cpd.cid = scaf2cpd.cid)
	GROUP BY
		scaf2cpd.scafid
	) t
WHERE
	${DBSCHEMA}.scaffold_train.id = t.scafid
	;
__EOF__
	#
	printf "COMPUTING SCAFFOLD_TRAIN STATISTICS (%s)...\n" "active samples, compounds, substances"
	#
	psql -d $DBNAME <<__EOF__
SELECT
	COUNT(a.outcome) AS "n_sam",
	COUNT(DISTINCT sub2cpd.sid) AS "n_sub",
	sub2cpd.cid
INTO
	${DBSCHEMA}.tmp
FROM
	${DBSCHEMA}.activity a
JOIN
	${DBSCHEMA}.sub2cpd ON (a.sid = sub2cpd.sid)
WHERE
	a.outcome = 2
GROUP BY
	sub2cpd.cid
	;
--
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	nsam_active = t.n_sam,
	nsub_active = t.n_sub
FROM
	(SELECT
		SUM(${DBSCHEMA}.tmp.n_sam) AS "n_sam",
		SUM(${DBSCHEMA}.tmp.n_sub) AS "n_sub",
		scafid
	FROM
		${DBSCHEMA}.tmp
	JOIN
		${DBSCHEMA}.scaf2cpd ON (${DBSCHEMA}.tmp.cid = ${DBSCHEMA}.scaf2cpd.cid)
	GROUP BY
		scafid
	) t
WHERE
	${DBSCHEMA}.scaffold_train.id = t.scafid
	;
--
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	ncpd_active = t.n_cpd
FROM
	(SELECT
		COUNT(DISTINCT cid) AS "n_cpd",
		scafid
	FROM
		${DBSCHEMA}.scaf2cpd
	GROUP BY
		scafid
	) t
WHERE
	${DBSCHEMA}.scaffold_train.id = t.scafid
	;
__EOF__
	#
	psql -d $DBNAME -c "DROP TABLE ${DBSCHEMA}.tmp"
	#
	printf "COMPUTING SCAFFOLD_TRAIN STATISTICS (%s)...\n" "active assays"
	#
	psql -d $DBNAME <<__EOF__
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	nass_active = t.n_ass
FROM
	(SELECT
		COUNT(DISTINCT a.aid) AS "n_ass",
		scaf2cpd.scafid
	FROM
		${DBSCHEMA}.activity a
	JOIN
		${DBSCHEMA}.sub2cpd ON (a.sid = sub2cpd.sid)
	JOIN
		${DBSCHEMA}.scaf2cpd ON (sub2cpd.cid = scaf2cpd.cid)
	WHERE
		a.outcome = 2
	GROUP BY
		scaf2cpd.scafid
	) t
WHERE
	${DBSCHEMA}.scaffold_train.id = t.scafid
	;
__EOF__
	#
	printf "COMPUTING SCAFFOLD_TRAIN STATISTICS (%s)...\n" "Medians"
	#
	psql -d $DBNAME <<__EOF__
CREATE TABLE ${DBSCHEMA}.metadata_train (
	median_ncpd_tested INTEGER,
	median_nsub_tested INTEGER,
	median_nass_tested INTEGER,
	median_nsam_tested INTEGER
	);
INSERT INTO ${DBSCHEMA}.metadata_train (median_ncpd_tested,median_nsub_tested,median_nass_tested,median_nsam_tested) VALUES (NULL,NULL,NULL,NULL) ;
UPDATE ${DBSCHEMA}.metadata_train SET median_nsub_tested = t.m FROM (SELECT median(nsub_tested) AS "m" FROM ${DBSCHEMA}.scaffold_train) t;
UPDATE ${DBSCHEMA}.metadata_train SET median_nass_tested = t.m FROM (SELECT median(nass_tested) AS "m" FROM ${DBSCHEMA}.scaffold_train) t;
UPDATE ${DBSCHEMA}.metadata_train SET median_nsam_tested = t.m FROM (SELECT median(nsam_tested) AS "m" FROM ${DBSCHEMA}.scaffold_train) t;
UPDATE ${DBSCHEMA}.metadata_train SET median_ncpd_tested = t.m FROM (SELECT median(ncpd_tested) AS "m" FROM ${DBSCHEMA}.scaffold_train) t;
__EOF__
	###
	psql -d $DBNAME -c "SELECT * FROM ${DBSCHEMA}.metadata_train"
	#
	# median_ncpd_tested | median_nsub_tested | median_nass_tested | median_nsam_tested 
	#--------------------+--------------------+--------------------+--------------------
	#                  2 |                  2 |                633 |                882
	###
	#
	printf "COMPUTING SCAFFOLD_TRAIN STATISTICS (%s)...\n" "Pscore"
	###
	psql -d $DBNAME <<__EOF__
UPDATE
	${DBSCHEMA}.scaffold_train
SET
	pscore = FLOOR(
		100000.0
		*(nsub_active::FLOAT / (nsub_tested+t.median_nsub_tested))
		*(nass_active::FLOAT / (nass_tested+t.median_nass_tested))
		*(nsam_active::FLOAT / (nsam_tested+t.median_nsam_tested))
		)
FROM
	(SELECT
		median_nsub_tested,
		median_nass_tested,
		median_nsam_tested
	FROM
		${DBSCHEMA}.metadata_train
	) t
		;
__EOF__
	#
	printf "Compile and output orig and test pscores...\n"
	#
	psql -d $DBNAME -c "ALTER TABLE ${DBSCHEMA}.compound_test ADD COLUMN pscore_orig INTEGER"
	psql -d $DBNAME -c "ALTER TABLE ${DBSCHEMA}.compound_test ADD COLUMN pscore_test INTEGER"
	#
	#
	psql -d $DBNAME <<__EOF__
UPDATE
	${DBSCHEMA}.compound_test
SET
	pscore_orig = t.pscore_max
FROM
	(SELECT
		MAX(pscore) AS "pscore_max",
		compound_test.cid
	FROM
		${DBSCHEMA}.scaffold s
	JOIN
		${DBSCHEMA}.scaf2cpd ON (scaf2cpd.scafid = s.id)
	JOIN
		${DBSCHEMA}.compound_test ON  (compound_test.cid = scaf2cpd.cid)
	GROUP BY
		compound_test.cid
	) t
WHERE
	compound_test.cid = t.cid
	;
__EOF__
	#
	psql -d $DBNAME <<__EOF__
UPDATE
	${DBSCHEMA}.compound_test
SET
	pscore_test = t.pscore_max
FROM
	(SELECT
		MAX(pscore) AS "pscore_max",
		compound_test.cid
	FROM
		${DBSCHEMA}.scaffold_train
	JOIN
		${DBSCHEMA}.scaf2cpd ON (scaf2cpd.scafid = scaffold_train.id)
	JOIN
		${DBSCHEMA}.compound_test ON  (compound_test.cid = scaf2cpd.cid)
	GROUP BY
		compound_test.cid
	) t
WHERE
	compound_test.cid = t.cid
	;
__EOF__
	#
	Nscore_orig=`psql -d $DBNAME -tc "SELECT COUNT(cid) FROM ${DBSCHEMA}.compound_test WHERE pscore_orig IS NOT NULL" |sed -e 's/ //g'`
	Nscore_test=`psql -d $DBNAME -tc "SELECT COUNT(cid) FROM ${DBSCHEMA}.compound_test WHERE pscore_test IS NOT NULL" |sed -e 's/ //g'`
	Nscore_lost=`psql -d $DBNAME -tc "SELECT COUNT(cid) FROM ${DBSCHEMA}.compound_test WHERE pscore_test IS NULL AND pscore_orig IS NOT NULL" |sed -e 's/ //g'`
	#
	printf "Testset scores orig: %d / %d (%d%%)\n" $Nscore_orig $Ntest `expr 100 \* $Nscore_orig/$Ntest`
	printf "Testset scores test: %d / %d (%d%%)\n" $Nscore_test $Ntest `expr 100 \* $Nscore_test/$Ntest`
	printf "Testset scores lost: %d / %d (%d%%)\n" $Nscore_lost $Ntest `expr 100 \* $Nscore_lost/$Ntest`
	#
	psql -q -d $DBNAME >data/xval_pscores.csv <<__EOF__
COPY (
	SELECT
		cid,
		pscore_orig,
		pscore_test
	FROM
		${DBSCHEMA}.compound_test
) TO STDOUT WITH (FORMAT CSV, HEADER, DELIMITER ',')
	;
__EOF__
	#
	printf "Run R: calculate test/orig correlation...\n"
	#
	R --quiet --slave -f R/badapple_xval.R
	#
	date
	#
done
#

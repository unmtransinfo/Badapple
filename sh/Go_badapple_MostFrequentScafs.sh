#!/bin/sh
#############################################################################
### Go_badapple_MostFrequentScafs.sh - 
### 
### Most frequently occuring in bioassay dataset, i.e. ranked by number of 
### wells with this scaffold.
### 
### Jeremy Yang
###  5 Aug 2013
#############################################################################
#
#
DB="openchord"
SCHEMA="badapple"
#
set -x
#
csvfile=data/${SCHEMA}_mostfrequentscafs.csv
#
psql \
	--quiet \
	--no-align \
	-d $DB \
	-o $csvfile \
	<<__EOF__
SELECT
	id,
	scafsmi,
	ncpd_total AS ctotal,
	ncpd_tested AS ctested,
	ncpd_active AS cactive,
	nsub_total AS stotal,
	nsub_tested AS stested,
	nsub_active AS sactive,
	nass_tested AS atested,
	nass_active AS aactive,
	nsam_tested AS wtested,
	nsam_active AS wactive,
	pscore,
	in_drug
FROM
	$SCHEMA.scaffold
ORDER BY nsam_tested DESC
LIMIT 1000
	;
__EOF__
#
cat $csvfile \
	|sed -e 's/|/,/g' \
	|sed -e 's/,f$/,FALSE/' \
	|sed -e 's/,t$/,TRUE/' \
	>data/z.z
#
mv data/z.z $csvfile
#
#############################################################################
#
csvfile=data/${SCHEMA}_highscoringscafs.csv
#
psql \
	--quiet \
	--no-align \
	-d $DB \
	-o $csvfile \
	<<__EOF__
SELECT
	id,
	scafsmi,
	ncpd_total AS ctotal,
	ncpd_tested AS ctested,
	ncpd_active AS cactive,
	nsub_total AS stotal,
	nsub_tested AS stested,
	nsub_active AS sactive,
	nass_tested AS atested,
	nass_active AS aactive,
	nsam_tested AS wtested,
	nsam_active AS wactive,
	pscore,
	in_drug
FROM
	$SCHEMA.scaffold
ORDER BY pscore DESC
LIMIT 1000
	;
__EOF__
#
cat $csvfile \
	|sed -e 's/|/,/g' \
	|sed -e 's/,f$/,FALSE/' \
	|sed -e 's/,t$/,TRUE/' \
	>data/z.z
#
mv data/z.z $csvfile
#

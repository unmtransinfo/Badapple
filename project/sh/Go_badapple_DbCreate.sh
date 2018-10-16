#!/bin/sh
#############################################################################
### Go_badapple_CreateDB.sh
### 
### RDKit version
### 
### "CREATE SCHEMA IF NOT EXISTS" requires PG 9.3+.
### 
### *Note*: scaffold and scaf2scaf tables now created by HScaf process.
###         May have only columns: id, scafsmi, scaftree
### 
### Jeremy Yang
###  6 Feb 2017
#############################################################################
###   1 = inactive
###   2 = active
###   3 = inconclusive
###   4 = unspecified
###   5 = probe
###   multiple & differing 1, 2 or 3 = discrepant
###   not 4 = tested
#############################################################################
#
set -e
#
DB="badapple2"
#
if [ ! `psql -P pager=off -Al | grep '|' | sed -e 's/|.*$//' | grep "^${DB}$"` ]; then
	createdb $DB
fi
#
DBCOMMENT="Badapple DB (dev version, PubChem-based)"
psql -d $DB -c "COMMENT ON DATABASE ${DB} IS '$DBCOMMENT'"
#
SCHEMA="public"
#
psql -d $DB <<__EOF__
CREATE TABLE IF NOT EXISTS $SCHEMA.scaffold (
	id INTEGER PRIMARY KEY,
	scafsmi VARCHAR(512) NOT NULL,
	scaftree VARCHAR(2048),
	ncpd_total INTEGER,
	ncpd_tested INTEGER,
	ncpd_active INTEGER,
	nsub_total INTEGER,
	nsub_tested INTEGER,
	nsub_active INTEGER,
	nass_tested INTEGER,
	nass_active INTEGER,
	nsam_tested INTEGER,
	nsam_active INTEGER,
	in_drug BOOLEAN,
	pscore FLOAT
	) ;
CREATE TABLE IF NOT EXISTS $SCHEMA.scaf2scaf (
	parent_id INTEGER,
	child_id INTEGER
	);
--
CREATE TABLE $SCHEMA.compound (
	cid INTEGER PRIMARY KEY,
	cansmi VARCHAR(2048) NOT NULL,
	isosmi VARCHAR(2048) NOT NULL,
	nsub_total INTEGER,
	nsub_tested INTEGER,
	nsub_active INTEGER,
	nass_tested INTEGER,
	nass_active INTEGER,
	nsam_tested INTEGER,
	nsam_active INTEGER
	) ;
CREATE TABLE $SCHEMA.sub2cpd (
	sid INTEGER PRIMARY KEY,
	cid INTEGER
	) ;
--
CREATE TABLE $SCHEMA.activity (
	aid INTEGER,
	sid INTEGER,
	outcome INTEGER
	) ;
CREATE TABLE $SCHEMA.scaf2cpd (
	scafid INTEGER,
	cid INTEGER
	);
CREATE TABLE $SCHEMA.metadata (
	db_description VARCHAR(2048),
	db_date_built TIMESTAMP WITH TIME ZONE,
	median_ncpd_tested INTEGER,
	median_nsub_tested INTEGER,
	median_nass_tested INTEGER,
	median_nsam_tested INTEGER,
	nass_total INTEGER
	);
__EOF__
#

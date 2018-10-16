#!/bin/sh
#############################################################################
### Go_badapple_CreateDB_derby.sh
### 
### 
### Jeremy Yang
###  6 Jun 2013
#############################################################################
#
set -e
#
DBDIR="/home/data/derby"
DBNAME="badapple"
DBSCHEMA="APP"	#default
#
TMP_SQL_FILE="data/z.sql"
#
cat > $TMP_SQL_FILE <<__EOF__
CONNECT 'jdbc:derby:$DBDIR/$DBNAME;create=true' ;
--
CREATE TABLE $DBSCHEMA.scaffold (
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
	in_drug SMALLINT
	) ;
CREATE INDEX scaffold_smi ON scaffold ( scafsmi ) ;
--
CREATE TABLE $DBSCHEMA.scaf2scaf (
	parent_id INTEGER,
	child_id INTEGER
	);
CREATE INDEX scaf2scaf_parent_id ON scaf2scaf ( parent_id ); 
CREATE INDEX scaf2scaf_child_id ON scaf2scaf ( child_id ) ;
--
CREATE TABLE $DBSCHEMA.compound (
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
CREATE INDEX compound_smi ON compound ( cansmi ) ;
--
CREATE TABLE $DBSCHEMA.sub2cpd (
	sid INTEGER PRIMARY KEY,
	cid INTEGER
	) ;
CREATE INDEX sub2cpd_cid ON sub2cpd ( cid ) ;
--
CREATE TABLE $DBSCHEMA.scaf2cpd (
	scafid INTEGER,
	cid INTEGER
	);
CREATE INDEX scaf2cpd_scafid ON scaf2cpd ( scafid ) ;
CREATE INDEX scaf2cpd_cid ON scaf2cpd ( cid ) ;
--
CREATE TABLE $DBSCHEMA.metadata (
	db_description VARCHAR(2048),
	db_date_built TIMESTAMP,
	median_ncpd_tested INTEGER,
	median_nsub_tested INTEGER,
	median_nass_tested INTEGER,
	median_nsam_tested INTEGER
	);
--
__EOF__
#
ij $TMP_SQL_FILE
rm $TMP_SQL_FILE
#

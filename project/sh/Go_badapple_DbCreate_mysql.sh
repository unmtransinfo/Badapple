#!/bin/sh
#############################################################################
### Go_badapple_CreateDB_mysql.sh
### 
### 
### Jeremy Yang
### 29 Jan 2013
#############################################################################
#
set -e
#
DBNAME="badapple"
DBUSR="jjyang"
DBPW="assword"
#
mysql -v -u $DBUSR -p${DBPW} <<__EOF__
CREATE DATABASE $DBNAME ;
USE $DBNAME ;
--
CREATE TABLE $DBNAME.scaffold (
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
	INDEX index_smi (scafsmi)
	) ;
CREATE TABLE $DBNAME.scaf2scaf (
	parent_id INTEGER,
	child_id INTEGER,
	INDEX index_parent (parent_id),
	INDEX index_child (child_id)
	);
CREATE TABLE $DBNAME.compound (
	cid INTEGER PRIMARY KEY,
	cansmi VARCHAR(2048) NOT NULL,
	isosmi VARCHAR(2048) NOT NULL,
	nsub_total INTEGER,
	nsub_tested INTEGER,
	nsub_active INTEGER,
	nass_tested INTEGER,
	nass_active INTEGER,
	nsam_tested INTEGER,
	nsam_active INTEGER,
	INDEX index_smi (cansmi)
	) ;
CREATE TABLE $DBNAME.sub2cpd (
	sid INTEGER PRIMARY KEY,
	cid INTEGER,
	INDEX index_cid (cid)
	) ;
CREATE TABLE $DBNAME.scaf2cpd (
	scafid INTEGER,
	cid INTEGER,
	INDEX index_scafid (scafid),
	INDEX index_cid (cid)
	);
CREATE TABLE $DBNAME.metadata (
	db_description VARCHAR(2048),
	db_date_built TIMESTAMP,
	median_ncpd_tested INTEGER,
	median_nsub_tested INTEGER,
	median_nass_tested INTEGER,
	median_nsam_tested INTEGER
	);
__EOF__
#
mysql -v -u $DBUSR -p${DBPW} <<__EOF__
CREATE USER 'www'@'localhost' IDENTIFIED BY 'foobar' ;
GRANT SELECT ON badapple.* TO 'www'@'localhost' ;
CREATE USER 'bard'@'localhost' IDENTIFIED BY 'stratford' ;
GRANT SELECT ON badapple.* TO 'bard'@'localhost' ;
__EOF__

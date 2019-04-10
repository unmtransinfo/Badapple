#!/bin/sh
#############################################################################
### Go_badapple_Dump4Mysql.sh - Dump database to MySql INSERTs.
### 
### For each table a custom sql file is used, to generate tab-delimited
### output files ready for MySql "LOAD DATA". 
### Non-data lines must be removed.
### 
### Jeremy Yang
### 10 Apr 2013
#############################################################################
#
set -x
#
DB="openchord"
SCHEMA="badapple"
#
for table in scaffold scaf2scaf compound sub2cpd scaf2cpd metadata ; do
	#
	datfile=data/${SCHEMA}_dump4mysql_${table}.dat
	sqlfile=sql/dump4mysql_${table}.sql
	#
	psql \
		--quiet \
		--no-align \
		-d $DB \
		-f $sqlfile \
		-o $datfile
	#
	#
	cat $datfile \
		| egrep -v '(^\?column.*$|^\([0-9]* row.*$)' \
		>data/z.z
	mv data/z.z $datfile
done
#

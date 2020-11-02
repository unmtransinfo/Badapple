#!/bin/sh
#############################################################################
### Go_badapple_CreateUser.sh
### 
### Jeremy Yang
### 10 Jun 2013
#############################################################################
#
set -e
#
DBNAME="badapple"
DBSCHEMA="public"
#
TABLES="scaffold compound sub2cpd scaf2cpd scaf2scaf activity metadata mols mols_scaf"
#
#############################################################################
#psql -u postgres -d $DBNAME "CREATE USER $USER WITH CREATEDB CREATEROLE LOGIN PASSWORD '$PW'"
#psql -u postgres -d $DBNAME "GRANT CREATE ON DATABASE $DBNAME TO $USER"
#psql -u postgres -d $DBNAME "GRANT CONNECT ON DATABASE $DBNAME TO $USER"
#############################################################################
USER="www"
PW="foobar"
#
psql -d $DBNAME -c "CREATE ROLE $USER WITH LOGIN PASSWORD '$PW'"
psql -d $DBNAME -c "GRANT CONNECT ON DATABASE $DBNAME TO $USER"
psql -d $DBNAME -c "GRANT USAGE ON SCHEMA $DBSCHEMA TO $USER"
#
#Postgresql-8:
#for t in $TABLES ; do
#	psql -d $DBNAME -c "GRANT SELECT ON $DBSCHEMA.$t TO $USER"
#done
#
#Postgresql-9.0+:
psql -d $DBNAME -c "GRANT SELECT ON ALL TABLES IN SCHEMA $DBSCHEMA TO $USER"
psql -d $DBNAME -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA $DBSCHEMA TO $USER"
#
#############################################################################
#

#!/bin/sh
########################################################
# How to clone from dumpfile.
# See Go_badapple_DbDump.sh to produce dumpfile.
# Note that activity table not needed for runtime.
########################################################
# With RDKit 2017.03.01 and Pg 9.6.3 this error:
# pasilla$ sudo -u postgres psql -d badapple -c 'create extension rdkit'
# ERROR:  syntax error at or near "@"
# ls `pg_config --pkglibdir`/rdkit.so
# ls `pg_config --sharedir`/extension/rdkit.control
# ls `pg_config --sharedir`/extension/rdkit--3.5.sql
########################################################
#
DBNAME="badapple"
DBSCHEMA="public"
#
DATADIR="/home/data/badapple/data"
#
###
sudo -u postgres createdb $DBNAME
sudo -u postgres psql -d $DBNAME -c 'create extension rdkit'
#
gunzip -c ${DBNAME}-${DBSCHEMA}-pgdump.sql.gz |sudo -u postgres psql -d badapple
#
DBUSR="www"
DBPW="foobar"
#
sudo -u postgres psql -d $DBNAME -c "CREATE ROLE $DBUSR WITH LOGIN PASSWORD '$DBPW'"
sudo -u postgres psql -d $DBNAME -c "GRANT CONNECT ON DATABASE $DBNAME TO $DBUSR"
sudo -u postgres psql -d $DBNAME -c "GRANT USAGE ON SCHEMA $DBSCHEMA TO $DBUSR"
sudo -u postgres psql -d $DBNAME -c "GRANT SELECT ON ALL TABLES IN SCHEMA $DBSCHEMA TO $DBUSR"
sudo -u postgres psql -d $DBNAME -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA $DBSCHEMA TO $DBUSR"
###

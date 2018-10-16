#!/bin/sh
#
DB="openchord"
SCHEMA="badapple"
#
#
# We need to do this in multiple transactions, since a single collision
# can cause a global update to fail (true?), e.g.
# ERROR:  duplicate key value violates unique constraint "scaffold_scafsmi_key"
# DETAIL:  Key (scafsmi)=(c1ccc2c(c1)nsn2) already exists.
#
psql ${DB} <<__EOF__
\i sql/recansmi_scaf.sql
--
SELECT recansmi_scaf('$SCHEMA') AS scaffold_rows_modified ;
__EOF__
#
#

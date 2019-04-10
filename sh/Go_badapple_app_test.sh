#!/bin/sh
#
#
#
. `dirname $0`/ba_current_db.sh
#
SCAFID=29
#
#set -x
#
#############################################################################
### Postgres test (default, preferred):
#
badapple.sh \
	-dbhost "$DBHOST" -dbname "$DBNAME" -dbschema "$DBSCHEMA" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-describescaf -scafid $SCAFID \
	-vvv
#
#	-i $HOME/data/smi/quinine.smi \
#	-o `dirname $0`/data/quinine.smi \
#
#	-i $HOME/data/smi/hscaf_testset.smi \
#	-o `dirname $0`/data/quinine.sdf \
#

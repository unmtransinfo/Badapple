#!/bin/sh
#
#
#LIBDIR=/home/app/lib
LIBDIR=$HOME/src/java/lib
CLASSPATH=$LIBDIR/unm_biocomp_badapple.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_db.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_hscaf.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_util.jar
CLASSPATH=$CLASSPATH:/home/app/lib/jchem.jar
CLASSPATH=$CLASSPATH:/home/app/lib/berkeleydb.jar
#
. ba_current_db.sh
#
PREFIX=data/pubchem_mlsmr
#
set -x
#
echo "HOSTNAME: `hostname`"
date
#
java -classpath $CLASSPATH edu.unm.health.biocomp.badapple.badapple \
	-dbhost "$DBHOST" -dbname "$DBNAME" -dbschema "$DBSCHEMA" -dbusr "$DBUSR" -dbpw "$DBPW" \
	-i ${PREFIX}.smi\
	-o ${PREFIX}_badapple_scores.smi \
	-maxatoms 80 \
	-maxrings 8 \
	-v
#
date
#
#gunzip -c \
cat \
	${PREFIX}_badapple_scores.smi \
	| ./cpd_filter_topscores.py \
	> ${PREFIX}_badapple_scores-top.smi
#

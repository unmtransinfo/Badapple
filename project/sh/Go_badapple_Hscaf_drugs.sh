#!/bin/sh
#############################################################################
### GoHscaf_drugs.sh
### 
### Jeremy Yang
###  18 Jan 2017
#############################################################################
#
#
#
IFILE=data/drugcentral.smi
#
psql -d drugcentral -qAF " " -c "SELECT smiles,name FROM structures WHERE smiles != '' " \
	|sed -e '1d' \
	|sed -e '$d' \
	>$IFILE
#
#
PREFIX=data/drugcentral_hscaf
OFILE=${PREFIX}_out.smi
OFILE_SCAF=${PREFIX}_scaf.smi
#
if [ ! -e "$IFILE" ]; then
	echo "ERROR: $IFILE not found."
	exit
fi
#
date
#
#
NMOL=`cat $IFILE |wc -l`
#
echo "NMOL($IFILE) = $NMOL"
#
#
opts="-v"
opts="$opts -maxmol 80"
opts="$opts -maxrings 5"
opts="$opts -inc_mol"
opts="$opts -scaflist_append2title"
opts="$opts -i $IFILE"
opts="$opts -o $OFILE"
opts="$opts -out_scaf $OFILE_SCAF"
###
#Slower with no db, but problems occur with Berkeleydb.
#opts="$opts -bdb"
#opts="$opts -bdb_predelete"
#opts="$opts -bdb_dir /tmp/hscaf"
#
set -x
#
hscaf.sh $opts
#

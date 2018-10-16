#!/bin/sh
#############################################################################
### GoHscaf_*.sh
### 
### Jeremy Yang
### 11 Jan 2017
#############################################################################
#set -x
#
#
IFILE=data/pc_mlsmr_compounds.smi
#
PREFIX=data/pc_mlsmr
OFILE=${PREFIX}_hscaf_out.smi
OFILE_SCAF=${PREFIX}_hscaf_scaf.smi
#
DBHOST="localhost"
DBPORT="5432"
DBNAME="badapple2"
DBSCHEMA="public"
DBTABLEPREFIX=""
DBUSER="jjyang"
DBPW="assword"
#
createdb "$DBNAME"
#
#############################################################################
if [ ! -e "$IFILE" ]; then
	echo "ERROR: $IFILE not found."
	exit
fi
#
echo "HOSTNAME: `hostname`"
date
#
NMOL=`cat $IFILE |wc -l`
#
echo "NMOL($IFILE) = $NMOL"
#
# application options:
opts="-v"
opts="$opts -maxmol 80"
opts="$opts -maxrings 5"
opts="$opts -inc_mol"
opts="$opts -scaflist_append2title"
opts="$opts -i $IFILE"
opts="$opts -o $OFILE"
opts="$opts -out_scaf $OFILE_SCAF"
opts="$opts -rdb"
opts="$opts -rdb_predelete"
opts="$opts -rdb_host $DBHOST"
opts="$opts -rdb_port $DBPORT"
opts="$opts -rdb_name $DBNAME"
opts="$opts -rdb_schema $DBSCHEMA"
if [ "$DBTABLEPREFIX" ]; then
	opts="$opts -rdb_tableprefix $DBTABLEPREFIX"
fi
opts="$opts -rdb_user $DBUSER"
opts="$opts -rdb_pw $DBPW"
opts="$opts -rdb_keep"
#
#opts="$opts -nskip 206900"
#
set -x
#
hscaf.sh $opts
#
date
#

#!/bin/sh
#############################################################################
### Go_badapple_AssayStats_bard.sh
### 
### Fetch assay stats for substances, given input SIDs and EIDs
### (substance and experiment IDs).
### 
### Jeremy Yang
### 12 May 2014
#############################################################################
set -x
#
sidfile="data/bard_mlsmr_substances.sid"
eidfile="data/bard_experiments_hts.eid"
#ofile="data/bard_mlsmr_hts_activity.csv"
#
ofile="data/bard_mlsmr_hts_activity.csv_2"
#
date
#
opts="--vv"
opts="$opts --activity"
opts="$opts --sidfile $sidfile"
opts="$opts --eidfile $eidfile"
opts="$opts --o $ofile"
#
opts="$opts --nskip_sub 63600"
#
bard_query.py $opts
#
date
#
#
#############################################################################
## concatenate partial CSVs:
#
#cp data/bard_mlsmr_hts_activity.csv_1 \
#	data/bard_mlsmr_hts_activity.csv
#
#for f in \
#	data/bard_mlsmr_hts_activity.csv_2 \
#	data/bard_mlsmr_hts_activity.csv_3 \
#	data/bard_mlsmr_hts_activity.csv_4 \
#	data/bard_mlsmr_hts_activity.csv_5 \
#	; do
#	cat $f \
#	| sed -e '1d' \
#	>>data/bard_mlsmr_hts_activity.csv
#done
##

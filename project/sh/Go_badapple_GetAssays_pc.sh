#!/bin/sh
#############################################################################
### Go_badapple_GetAssays_pc.sh - Get PubChem assays, CSV and AID files.
### 
### Jeremy Yang
### 13 Aug 2014
#############################################################################
#
csvfile="data/pc_mlp_selected_assays.csv"
#
entrez_assay_search.pl \
	-mlp \
	-min_sidcount 20000 \
	-v \
	-out_summaries_csv $csvfile
#
n=`cat $csvfile |wc -l`
n=`expr $n - 1`
printf "assay count: %d\n" $n
#
#############################################################################
#
aidfile="data/pc_mlp_selected_assays.aid"
csv_utils.py \
	--v \
	--i $csvfile \
	--extractcol \
	--coltag "ID" \
	>$aidfile
#
printf "HTS assay count: %d\n" `cat $aidfile |wc -l`
#
#############################################################################
# Subset by date cutoff.
#
DATE_MAX="20110101"
csvfile_early="data/pc_mlp_selected_assays_pre-${DATE_MAX}.csv"
aidfile_early="data/pc_mlp_selected_assays_pre-${DATE_MAX}.aid"
#
csv_utils.py \
	--filterbycol \
	--coltag "DepositDate" \
	--chron \
	--maxval $DATE_MAX \
	--i $csvfile \
	--o $csvfile_early \
	--v
#
csv_utils.py \
	--extractcol \
	--coltag "ID" \
	--i $csvfile_early \
	--o $aidfile_early \
	--v
#

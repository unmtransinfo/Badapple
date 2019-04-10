#!/bin/sh
#
sidfile="data/pc_mlsmr.sid"
sid2cid_file="data/pc_mlsmr_sid2cid.csv"
cidfile="data/pc_mlsmr.cid"
#
smifile_cpds=data/pc_mlsmr_compounds.smi
sdffile_cpds=data/pc_mlsmr_compounds.sdf
#
entrez_substance_search.pl \
	-v \
	-mlsmr \
	-out_sids $sidfile
#
printf "sid count: %d\n" `cat $sidfile |wc -l`
#
#entrez_compound_search.pl \
#	-v \
#	-mlsmr \
#	-out_cids $cidfile
#
pug_rest_query.py \
	--v \
	--sids2cids \
	--i data/pc_mlsmr.sid \
	--o $sid2cid_file
#
cat $sid2cid_file \
	|sed -e '1d' \
	|awk -F ',' '{print $2}' \
	|sort -u \
	>$cidfile
#
printf "cid count: %d\n" `cat $cidfile |wc -l`
#
pug_rest_query.py \
	--v \
	--cids2smi \
	--i $cidfile \
	--o $smifile_cpds
#
#Does this work?  SDFs have CIDs?
#Apparently API does not support.
#pug_rest_query.py \
#	--v \
#	--sids2sdf \
#	--i $sidfile \
#	--o $sdffile_cpds
#

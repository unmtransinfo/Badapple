#!/bin/sh
#############################################################################
### Go_badapple_GetData_pc.sh - Get PubChem assays, and compounds.
### 
### SHOULD WE CONTINUE TO RESTRICT TO MLSMR? IN 2017?
### 
### Jeremy Yang
### 24 Jan 2017
#############################################################################
#
csvfile="data/pc_mlp_selected_assays.csv"
aidfile="data/pc_mlp_selected_assays.aid"
#
#entrez_assay_search.pl -mlp -min_sidcount 20000 -v -out_summaries_csv $csvfile
#(Not working due to NCBI https-related issue.)
#csv_utils.py --v --i $csvfile --extractcol --coltag "ID" >$aidfile
###
qry="(20000[TotalSidCount]:1000000000[TotalSidCount])"
qry="${qry} AND \"NIH Molecular Libraries Program\"[SourceCategory]"
esearch -db pcassay -query "${qry}" \
	| efetch -format uid \
	>$aidfile
#
n_ass=`cat $aidfile |wc -l`
printf "n_ass: %d\n" $n_ass
#
#############################################################################
xmlfile="data/pc_mlp_selected_assays.xml"
esearch -db pcassay -query "${qry}" \
	|efetch -format docsum \
	>$xmlfile
#
# Convert XML to CSV with cols:
# ID,ActivityOutcomeMethod,AssayName,SourceName,ModifyDate,DepositDate,ActiveSidCount,InactiveSidCount,InconclusiveSidCount,TotalSidCount,ActiveCidCount,TotalCidCount,ProteinTargetList
#
# (Github:xmlutils):
xml2csv \
	--input $xmlfile \
	--tag "DocumentSummary" \
	--output $csvfile
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
#
#
sidfile="data/pc_mlsmr.sid"
sid2cid_csvfile="data/pc_mlsmr_sid2cid.csv"
cidfile="data/pc_mlsmr.cid"
#
smifile_cpds=data/pc_mlsmr_compounds.smi
#
#entrez_substance_search.pl -v -mlsmr -out_sids $sidfile
qry="MLSMR[SourceName]"
esearch -db pcsubstance -query "${qry}" \
	| efetch -format uid \
	>$sidfile
#
n_sid=`cat $sidfile |wc -l`
printf "n_sid: %d\n" $n_sid
#
### SLOW, ~3.5 days in Jan 2017.
pubchem_query.py \
	--v \
	--sids2cids \
	--i data/pc_mlsmr.sid \
	--o $sid2cid_csvfile
#
csv_utils.py \
	--i $sid2cid_csvfile \
	--coltag "cid" \
	--extractcol \
	|sort -nu \
	>$cidfile
#
n_cid=`cat $cidfile |wc -l`
printf "n_cid: %d\n" $n_cid
#
pubchem_query.py \
	--v \
	--cids2smi \
	--i $cidfile \
	--o $smifile_cpds
#
#Does this work?  SDFs have CIDs?
#Apparently API does not support.
#sdffile_cpds=data/pc_mlsmr_compounds.sdf
#pubchem_query.py \
#	--v \
#	--sids2sdf \
#	--i $sidfile \
#	--o $sdffile_cpds
#
#############################################################################
### Slow
#pubchem_query.py --assayresults --i $sidfile --iaid $aidfile --vv \
#	--o data/pc_mlsmr_mlp_assaystats_act.csv
####
#Local-ftpmirror method (~90min):
i_aid="0"
n_aid=`cat $aidfile |gzip -c |wc -l`
ofile="data/pc_mlsmr_mlp_assaystats_act.csv.gz"
echo "AID,SID,OUTCOME" >$ofile
while [ $i_aid -le $n_aid ]; do
	i_aid=`expr $i_aid + 1`
	aid=`cat $aidfile |sed "${i_aid}q;d"`
	if [ ! "$aid" ]; then
		continue
	fi
	printf "%d. %s\n" $i_aid $aid
	pubchem_ftp_assay_results.py --aid "${aid}" --i "$sidfile" --v \
		|sed -e '1d' \
		|gzip -c \
		>>$ofile
done
#
####
#

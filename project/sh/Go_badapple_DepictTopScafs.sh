#!/bin/sh
#############################################################################
### Go_badapple_DepictTopScafs.sh
### 
### Input CSV (unsorted) from Java badapple app, or can be dumped (sorted) 
### from database.  badapple_analysis.R also sorts by pScore.
### 
### Jeremy Yang
###  3 Jun 2014
#############################################################################
#
if [ `uname -s` = "Linux" ]; then
	#PDFVIEWER="acroread"
	PDFVIEWER="okular"
elif [ `uname -s` = "Darwin" ]; then
	PDFVIEWER="open"
else
	PDFVIEWER="acroread"
fi
#
DB="openchord"
SCHEMA="badapple2"
PREFIX="data/${SCHEMA}"
#
#
set -x
#
csvfile=${PREFIX}_scaf_scores.csv
#
#Can be produced with:
#./badapple.sh -v -dbschema ${SCHEMA} -out_scaf ${csvfile}
#
#############################################################################
### Sort CSV by pScore.
#
score_tag=`head -1 $csvfile |awk -F ',' '{print $13}'`
printf "pScore tag: %s" $score_tag
#
csvfile_sort=${PREFIX}_scaf_scores_sort.csv
cat $csvfile \
	|sed -e '1d' \
	|awk -F ',' '{print $1 " " $2 " " $13 " " $14}' \
	|sort -nrk 3 \
	|awk '{print $1 " " $2 ";" $3 ";" $4}' \
	>$csvfile_sort
#
#############################################################################
### Generate top 1% depictions using OE toolkit program.
#
if [ ! -f "$HOME/bin/moltopdf" ]; then
	echo "ERROR: Cannot find program moltopdf."
	exit
fi
#
N=`cat $csvfile |wc -l`
N=`expr $N - 1`
N_TOP=`expr $N / 100`
echo "N_TOP = $N_TOP"
#
depictionfile="${PREFIX}_scaf_top1pct_depictions.pdf"
#
cat $csvfile_sort \
	|sed -e "${N_TOP},\$d" \
	|moltopdf \
	-cols 8 -rows 10 \
	-border \
	-pagesize US_Letter \
	-pagetitle "Badapple Top Promiscuous Scaffolds (fields: id,pScore,inDrug)" \
	-linewidth 1.0 \
	-in .smi \
	-out $depictionfile
#
#$PDFVIEWER $depictionfile &
#
#Top 50 to PNG:
cat $csvfile_sort \
	|sed -e "${N_TOP},\$d" \
	|$OE_DIR/toolkits/examples/bin/mols2img \
	-height 1600 -width 800 \
	 -cols 5 -rows 10 \
	-linewidth 1.0 \
	-i .smi \
	-o "${PREFIX}_scaf_top50_depictions.png"
#
chromium "${PREFIX}_scaf_top50_depictions.png"
#

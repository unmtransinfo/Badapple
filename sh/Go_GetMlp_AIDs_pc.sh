#!/bin/sh
#############################################################################
### Go_GetMlpAIDs.sh
### 
#############################################################################
### 31 Aug 2012:
### $ entrez_assay_search.pl -mlp
### entrez_assay_search.pl: assays found: 5284
###
### $ entrez_assay_search.pl -mlp -method_screening
### entrez_assay_search.pl: assays found: 1048
###
### $ entrez_assay_search.pl -pcquery 'screening"[activityoutcomemethod] AND 20000:1000000[Total Sid Count]'
### entrez_assay_search.pl: assays found: 518
###
### $ entrez_assay_search.pl -pcquery 'screening"[activityoutcomemethod] AND 1[Target Count] AND 20000:1000000[Total Sid Count]'
### entrez_assay_search.pl: assays found: 359
###
### $ entrez_assay_search.pl -pcquery 'MLP[SourceCategory] AND 20000:1000000[Total Sid Count]'
### entrez_assay_search.pl: assays found: 727
#############################################################################
### Problem with 1[Target Count] is phenotypic assays excluded.
#############################################################################
### Jeremy Yang
### 19 Jun 2014
#############################################################################
#
aidfile="data/pubchem_mlp_hts.aid"
#
set -x
#
#entrez_assay_search.pl \
#	-mlp \
#	-out_aids $aidfile
#
entrez_assay_search.pl \
	-pcquery 'MLP[SourceCategory] AND 20000:1000000[Total Sid Count]' \
	-out_aids $aidfile
#
setman.py \
	--AminusB \
	--sort \
	--numerical \
	--iA data/pubchem_mlp_hts.aid \
	--iB data/NEW_profiling.txt \
	--o data/z.aid
#
setman.py \
	--AminusB \
	--sort \
	--numerical \
	--iA data/z.aid \
	--iB data/NEW_non-MLSMR.txt \
	--o $aidfile
#
rm data/z.aid
#

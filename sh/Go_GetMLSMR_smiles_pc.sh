#!/bin/sh
# 
entrez_compound_search.pl \
	-mlsmr \
	-out_cids data/pubchem_mlsmr.cid
#
wc -l data/pubchem_mlsmr.cid 
#
pug_rest_ids2mols.py \
	--i=data/pubchem_mlsmr.cid \
	--o=data/pubchem_mlsmr.smi \
	--v
#

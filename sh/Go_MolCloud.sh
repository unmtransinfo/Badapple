#!/bin/sh
#
#
head -200 data/bard_mlsmr_scaf_scores_sort.csv \
	|perl -pe 's/^([^\s]*)\s+([^;]*);([^;\.]*)\.?[0-9]*;(.*)$/$1\t$3/' \
	> data/bard_mlsmr_scaf_scores_sort_top200.smi
#
molcloud.sh \
	-f data/bard_mlsmr_scaf_scores_sort_top200.smi \
	-nogui -x 2000 -y 1400 \
	-o data/bard_mlsmr_scaf_scores_sort_top200_mcloud.png
#

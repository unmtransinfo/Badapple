#!/bin/sh
#
#NMAX=5000
#NMAX=1000
NMAX=0
#
#Schemas:
DBS1="badapple1"
DBS2="badapple2"
DBS3="badapple_pc2"
DBS4="badapple_pc1"
#
#set -x
#
DBSCHEMAS="$DBS1 $DBS2 $DBS3 $DBS4"
#
for db in $DBSCHEMAS; do
	./badapple.py --v --topscores --nmax $NMAX --dbschema $db --o data/${db}_topscores_${NMAX}.csv
done
#
#
for dbA in $DBSCHEMAS ; do
	DBSCHEMAS_B=`echo "$DBSCHEMAS" | sed -e "s/^.*${dbA} *//"`
	for dbB in $DBSCHEMAS_B ; do
		echo "$dbA vs. $dbB ..."
		ofile="data/${dbA}_vs_${dbB}_topscores_compare-${NMAX}.csv"
		./badapple.py --v --topscores_compare --nmax $NMAX --dbschema $dbA --dbschema2 $dbB --o ${ofile}
		R --no-restore --slave -q -f R/badapple_compare.R --args $ofile $dbA $dbB
		#
		ofile="data/${dbA}_vs_${dbB}_topscores_compare-${NMAX}_nonnull.csv"
		./badapple.py --v --topscores_compare --nmax $NMAX --non_null --dbschema $dbA --dbschema2 $dbB --o ${ofile}
		R --no-restore --slave -q -f R/badapple_compare.R --args $ofile $dbA $dbB
		#
		ofile="data/${dbA}_vs_${dbB}_topscores_compare-${NMAX}_nonzero.csv"
		./badapple.py --v --topscores_compare --nmax $NMAX --non_zero --dbschema $dbA --dbschema2 $dbB --o ${ofile}
		R --no-restore --slave -q -f R/badapple_compare.R --args $ofile $dbA $dbB
		#
	done
done
#

#!/bin/sh
#############################################################################
### Go_badapple_DescribeDB_derby.sh
### 
### Jeremy Yang
###  7 Jun 2013
#############################################################################
#
set -x
#
DBDIR=/home/data/derby
DBNAME="badapple"
DBSCHEMA="APP"
#
LIBDIR=$HOME/src/java/lib
CLASSPATH=$LIBDIR/unm_biocomp_db.jar
CLASSPATH=$CLASSPATH:/home/app/ChemAxon/JChem/lib/jchem.jar
LIBDIR=/home/app/lib
#CLASSPATH=$CLASSPATH:$LIBDIR/derby.jar  ##jchem.jar includes Derby jars.
#
java -cp $CLASSPATH \
	edu.unm.health.biocomp.db.derby_utils \
	-v \
	-dbdir $DBDIR \
	-dbname $DBNAME \
	-describe
#
TMP_SQL_FILE="data/z.sql"
#
cat >$TMP_SQL_FILE <<__EOF__
CONNECT 'jdbc:derby:$DBDIR/$DBNAME' ;
__EOF__
#
for table in scaffold scaf2scaf compound sub2cpd scaf2cpd metadata ; do
	#
	cat >>data/z.sql <<__EOF__
SELECT CAST(COUNT(*) AS CHAR(20)) AS ${table}_count FROM $DBSCHEMA.${table} ;
__EOF__
done
	#
cat >>data/z.sql <<__EOF__
SELECT CAST(db_description AS CHAR(50)),db_date_built FROM $DBSCHEMA.metadata ;
SELECT
	median_ncpd_tested AS m_cpd_tst,
	median_nsub_tested AS m_sub_tst,
	median_nass_tested AS m_ass_tst,
	median_nsam_tested AS m_sam_tst
FROM $DBSCHEMA.metadata ;
__EOF__
#
ij $TMP_SQL_FILE
rm $TMP_SQL_FILE
#

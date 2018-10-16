#!/bin/sh
#
LIBDIR=/home/app/lib
CLASSPATH=$CLASSPATH:$LIBDIR/jchem.jar
#CLASSPATH=$CLASSPATH:$LIBDIR/derby.jar  ##jchem.jar includes derby.jar.
#
DBDIR="/home/data/derby"
DBNAME="badapple"
DBSCHEMA="APP"  #default
#
#
ij <<__EOF__
CREATE FUNCTION CANSMI(SMILES VARCHAR(8192))
	RETURNS VARCHAR(8192)
	LANGUAGE JAVA 
	PARAMETER STYLE JAVA
	EXTERNAL NAME 'edu.unm.health.biocomp.badapple.badapple_utils.Cansmi'
	NO SQL
	DETERMINISTIC
	RETURNS NULL ON NULL INPUT
	;
__EOF__
#
#############################################################################
#
LIBDIR=$HOME/src/java/lib
CLASSPATH=$LIBDIR/unm_biocomp_badapple.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_db.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_hscaf.jar
CLASSPATH=$CLASSPATH:$LIBDIR/unm_biocomp_util.jar
LIBDIR=/home/app/lib
CLASSPATH=$CLASSPATH:$LIBDIR/jchem.jar
#
ij <<__EOF__
CONNECT 'jdbc:derby:$DBDIR/$DBNAME' ;
UPDATE scaffold SET scafsmi = CANSMI(scafsmi) ;
UPDATE compound SET cansmi = CANSMI(cansmi) ;
__EOF__
#

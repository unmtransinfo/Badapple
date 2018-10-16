#!/bin/sh
#
#
set -x
#
DBNAME="badapple"
#
mysqldump \
	-password \
	-v \
	--skip-extended-insert \
	--skip-quote-names \
	--no-create-db --no-create-info --no-set-names --skip-add-locks --skip-add-drop-table \
	$DBNAME \
	scaffold scaf2scaf compound sub2cpd scaf2cpd metadata \
	>data/${DBNAME}-mysqldump.sql
#
#
#	|gzip -c \
#	>data/${DBNAME}-mysqldump.sql.gz
#
#	|ssh habanero "cat > ~/projects/badapple/data/${DBNAME}-mysqldump.sql.gz"
#
#	--skip-extended-insert \
#	--skip-quote-names \
# This line to allow use for Derby import, with db already created:
#	--compatible=ansi \
#	--no-create-db --no-create-info --no-set-names --skip-add-locks --skip-add-drop-table \
#

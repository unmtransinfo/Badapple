#!/bin/sh
#
### Drop schema, all tables.
#
#
DB="openchord"
#
if [ $# -ne 1 ]; then
	printf "Syntax: %s SCHEMA\n" $0
	exit
fi
SCHEMA=$1
#
printf "\n\tYOU ARE DELETING SCHEMA \"%s\";  CONFIRMATION REQUIRED (enter \"yes\"): " $SCHEMA
read answer
printf "\n"
#
if [ "$answer" = "yes" ]; then
	printf "\tDELETING SCHEMA \"%s\"...\n" $SCHEMA
else
	printf "\t(Operation cancelled.)\n"
	exit
fi
#
psql ${DB} <<__EOF__
DROP SCHEMA ${SCHEMA} CASCADE;
__EOF__
#

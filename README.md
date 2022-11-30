# Badapple <img align="right" src="doc/images/BadappleWorm.png" height="80">

Bioassay data associative promiscuity pattern learning engine.
Badapple web app, utility apps, library, and project code.
Methods developed at the [UNM Translational Informatics Division](http://datascience.unm.edu)
for for HTS analytics and hit prioritization. Note that for large input files,
local installation and the command-line interface is recommended.

* [Public web app](https://datascience.health.unm.edu/tomcat/badapple/badapple)
* [Badapple: promiscuity patterns from noisy evidence, Yang et al., J. Cheminfo. 8:29 (2016)](http://jcheminf.springeropen.com/articles/10.1186/s13321-016-0137-3).
* [Badapple Formula](/doc/images/badapple_formula.png)

## Dependencies

* Java 8+
* Maven 3.5+
* Additional libraries (clone and install with `mvn clean install`)
 * [`unm_biocomp_util.jar`](https://github.com/unmtransinfo/unm_biocomp_util)
 * [`unm_biocomp_depict.jar`](https://github.com/unmtransinfo/unm_biocomp_depict)
 * [`unm_biocomp_hscaf.jar`](https://github.com/unmtransinfo/unm_biocomp_hscaf)
* ChemAxon JChem 19.3.0+
* Access to [ChemAxon Maven repository](https://hub.chemaxon.com) (see [documentation](https://docs.chemaxon.com/display/docs/Public+Repository)).
* Runtime: Badapple database accessible (PostgreSQL with RDKit cartridge); see below.

## Compiling

```
mvn clean install
```

## Deploying webapp via warfile

Ok for Tomcat v8/v9 also. Deploy to server `TomcatServer` as specified
in Maven `settings.xml`.

```
mvn --projects badapple_war tomcat7:deploy
```

or

```
mvn --projects badapple_war tomcat7:redeploy
```

## Testing webapp with Jetty

<http://localhost:8081/badapple/badapple>

```
mvn --projects badapple_war jetty:run
```

## Command-line usage

```
mvn --projects unm_biocomp_badapple exec:java -Dexec.mainClass="edu.unm.health.biocomp.badapple.badapple -Dexec.args="-describedb"
```

Or:

```
java -jar unm_biocomp_badapple-0.0.1-SNAPSHOT-jar-with-dependencies.jar
```

Or:

```
java -classpath unm_biocomp_badapple-0.0.1-SNAPSHOT-jar-with-dependencies.jar edu.unm.health.biocomp.badapple.badapple
```

```
usage: Badapple [-chemaxon_license_file <arg>] [-dbhost <arg>] [-dbname
       <arg>] [-dbport <arg>] [-dbpw <arg>] [-dbschema <arg>] [-dbusr
       <arg>] -describedb | -describescaf | -process_mols |
       -test_chemaxon_license  [-h] [-i <IFILE>] [-maxatoms <arg>]
       [-maxrings <arg>] [-nmax <arg>] [-nskip <arg>] [-o <OFILE>]
       [-scafid <arg>] [-scafid_max] [-scafid_min]  [-v] [-vv] [-vvv]
Badapple - command line app for Badapple
Operations: [-describedb describe db, -describescaf describe specified
scaffold, -process_mols process input molecules, -test_chemaxon_license
test chemaxon license]
 -chemaxon_license_file <arg>   chemaxon_license_file
                                [$HOME/.chemaxon/license.cxl]
 -dbhost <arg>                  db host [localhost]
 -dbname <arg>                  db name [badapple]
 -dbport <arg>                  db port [5432]
 -dbpw <arg>                    db password
 -dbschema <arg>                db schema [public]
 -dbusr <arg>                   db user [www]
 -describedb                    describe db
 -describescaf                  describe specified scaffold
 -h,--help                      Show this help.
 -i <IFILE>                     input molecules
 -maxatoms <arg>                max atom count of input mol [50]
 -maxrings <arg>                max ring count of input mol [5]
 -nmax <arg>                    quit after NMAX molecules
 -nskip <arg>                   skip NSKIP molecules
 -o <OFILE>                     output molecules, w/ scores
 -process_mols                  process input molecules
 -scafid <arg>                  scaffold ID
 -scafid_max                    max scaf ID to calculate/annotate
 -scafid_min                    min scaf ID to calculate/annotate
 -test_chemaxon_license         test chemaxon license
 -v,--verbose                   verbose.
 -vv,--vverbose                 very verbose.
 -vvv,--vvverbose               very very verbose.
Missing required option: [-describedb describe db, -describescaf describe
specified scaffold, -process_mols process input molecules,
-test_chemaxon_license test chemaxon license]
```

Example:

```
java -classpath unm_biocomp_badapple-0.0.1-SNAPSHOT-jar-with-dependencies.jar edu.unm.health.biocomp.badapple.badapple -i data/badapple_test.smi -o badapple_test_out.smiles
```

## Database installation

Badapple requires a PostgreSQL database for execution, which can be installed and
configured locally. This is known to work with Ubuntu 20.04LTS, postgresql-12 and
postgresql-12-rdkit, or with 22.04LTS, postgresql-14 and postgresql-14-rdkit, but may
work with other combinations.

1. Download [badapple.pgdump](https://unmtid-dbs.net/download/Badapple/badapple.pgdump)
1. Create database: `createdb badapple`
1. Load from dumpfile: `pg_restore -O -x -v -C -d badapple badapple.pgdump`
1. Configure user:
  1. `psql -c "CREATE ROLE myname WITH LOGIN PASSWORD 'foobar'"`
  1. `psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO myname"`
  1. `psql -c "GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO myname"`
  1. `psql -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO myname"`

## Docker

* Docker containers based on Ubuntu 20.04.
* [`badapple_db`](https://hub.docker.com/repository/docker/unmtransinfo/badapple_db)
* [`badapple_ui`](https://hub.docker.com/repository/docker/unmtransinfo/badapple_ui)
* ChemAxon license must be installed into running `badapple_ui` container.

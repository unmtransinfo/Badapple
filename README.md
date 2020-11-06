# Badapple <img align="right" src="doc/images/BadappleWorm.png" height="80">

Bioassay data associative promiscuity pattern learning engine. 
Badapple web app, utility apps, library, and project code.
Methods developed at the [UNM Translational Informatics Division](http://datascience.unm.edu)
for for HTS analytics and hit prioritization.

* [Public web app](http://pasilla.health.unm.edu/badapple)
* [Badapple: promiscuity patterns from noisy evidence , Yang et al., J. Cheminfo. 8:29 (2016)](http://jcheminf.springeropen.com/articles/10.1186/s13321-016-0137-3).
* See [Badapple Formula](/doc/badapple_formula.html)

## Dependencies

* Java 8
* Maven 3.5+
* [`unm_biocomp_hscaf.jar`](https://github.com/unmtransinfo/unm_biocomp_hscaf), [`unm_biocomp_depict.jar`](https://github.com/unmtransinfo/unm_biocomp_depict), [`unm_biocomp_util.jar`](https://github.com/unmtransinfo/unm_biocomp_util)
* ChemAxon JChem 19.3.0+
* Access to [ChemAxon Maven repository](https://hub.chemaxon.com)
(see [documentation](https://docs.chemaxon.com/display/docs/Public+Repository)).

## Compiling

```
mvn clean install
```

## Deploying webapp `BADAPPLE_WAR`

Ok for Tomcat v8/v9 also. Deploy to server `TomcatServer` as specified
in Maven `settings.xml`.

```
mvn --projects badapple_war tomcat7:deploy
```

or

```
mvn --projects badapple_war tomcat7:redeploy
```

## Testing with Jetty

<http://localhost:8081/badapple/badapple>

```
mvn --projects badapple_war jetty:run
```

## Command-line usage

```
mvn exec:java -Dexec.mainClass="edu.unm.health.biocomp.badapple.badapple"
```

Or:

```
java -jar unm_biocomp_badapple-0.0.1-SNAPSHOT-jar-with-dependencies.jar
```

## Docker

* Docker containers based on Ubuntu 20.04.
* [`badapple_db`](https://hub.docker.com/repository/docker/unmtransinfo/badapple_db)
* [`badapple_ui`](https://hub.docker.com/repository/docker/unmtransinfo/badapple_ui)
* ChemAxon license must be installed into running `badapple_ui` container.

<img align="center" src="/doc/images/badapple_formula.png">


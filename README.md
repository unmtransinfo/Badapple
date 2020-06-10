# Badapple <img align="right" src="doc/images/BadappleWorm.png" height="80">

Bioassay data associative promiscuity pattern learning engine. 
Methods developed at UNM for for HTS analytics and hit prioritization.

Badapple web app, utility apps, library, and project code.

## Dependencies

* Java 8
* Maven 3.5+
* `unm_biocomp_hscaf.jar`, `unm_biocomp_db.jar`, `unm_biocomp_depict.jar`, `unm_biocomp_util.jar`
* ChemAxon JChem (19.3.0 ok)
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

Developed at the [UNM Translational Informatics Division](http://datascience.unm.edu).

* [Public web app](http://pasilla.health.unm.edu/badapple)
* Badapple: promiscuity patterns from noisy evidence , Yang JJ, Ursu O, Lipinski
CA, Sklar LA, Oprea TI Bologa CG, J. Cheminfo. 8:29 (2016), DOI: 10.1186/s13321-016-0137-3,
<http://jcheminf.springeropen.com/articles/10.1186/s13321-016-0137-3>.
* See [Badapple Formula](/doc/badapple_formula.html)

<img align="center" src="/doc/images/badapple_formula.png">

## Docker

* Docker container based on Ubuntu 18.04-LTS.

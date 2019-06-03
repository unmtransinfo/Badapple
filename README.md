# Badapple <img align="right" src="/src/main/webapp/images/BadappleWorm.png" height="80">

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

## Usage

```
mvn exec:java -Dexec.mainClass="edu.unm.health.biocomp.badapple.badapple"
```

Developed at the [UNM Translational Informatics Division](http://datascience.unm.edu).

* [Public web app](http://pasilla.health.unm.edu/badapple)
* Badapple: promiscuity patterns from noisy evidence , Yang JJ, Ursu O, Lipinski
CA, Sklar LA, Oprea TI Bologa CG, J. Cheminfo. 8:29 (2016), DOI: 10.1186/s13321-016-0137-3,
<http://jcheminf.springeropen.com/articles/10.1186/s13321-016-0137-3>.
* See [Badapple Formula](/doc/badapple_formula.html)

<img align="center" src="/doc/images/badapple_formula.png">

package edu.unm.health.biocomp.badapple;

import java.io.*;
import java.util.*;
import java.sql.*;
import java.text.DateFormat;

import org.apache.commons.cli.*; // CommandLine, CommandLineParser, HelpFormatter, OptionBuilder, Options, ParseException, PosixParser
import org.apache.commons.cli.Option.*; // Builder

import chemaxon.struc.*;
import chemaxon.formats.*;
import chemaxon.marvin.io.*;

import edu.unm.health.biocomp.hscaf.*;
import edu.unm.health.biocomp.util.db.*; // DBCon, pg_utils, mysql_utils, derby_utils
import edu.unm.health.biocomp.util.*; // time_utils
import edu.unm.health.biocomp.util.jre.*;

/**	Command line application for Badapple system.
	<br>
	Database engines supported:
	<ul>
	<li>PostgreSQL
	<ul>
	<li>PostgreSQL JDBC driver (org.postgresql.Driver).
	<li>Requires either (1) RDKit or (2) gNova OpenChord.
	</ul>
	<li>MySQL
	<ul>
	<li>MySQL JDBC driver (com.mysql.jdbc.Driver).
	<li>No chemical cartridge yet.
	</ul>
	<li>Derby
	</ul>
	<br>
	@author Jeremy J Yang
*/
public class badapple
{
  private static String APPNAME="BADAPPLE";
  private static String dbhost="localhost";
  private static Integer dbport=5432; //PostgreSql default
  private static String dbname="badapple";
  private static String dbdir="/tmp";
  private static String dbschema="public";
  private static String dbusr="www";
  private static String dbpw="foobar";
  private static String dbtype="postgres";
  private static String chemkit="rdkit";
  private static Integer maxatoms=50;
  private static Integer maxrings=5;
  private static Integer verbose=0;
  private static String smifmt="cxsmiles:u-L-l-e-d-D-p-R-f-w";
  private static String ifile=null;
  private static String ofile=null;
  private static String ofile_scaf=null;
  private static Boolean describe=false;
  private static Boolean describescaf=false;
  private static Boolean process_mols=false;
  private static Integer scafid=null;
  private static Integer nmax=0;
  private static Integer nskip=0;
  private static Long scafid_min=null;
  private static Long scafid_max=null;

  /////////////////////////////////////////////////////////////////////////////
  public static void main(String[] args) throws Exception
  {
    String HELPHEADER = "BADAPPLE - command line app for Badapple system";
    String HELPFOOTER = "From the UNM Translational Informatics Division";
    Options opts = new Options();
    opts.addOption(Option.builder("i").required().hasArg().argName("IFILE").desc("input molecules").build());
    opts.addOption(Option.builder("o").hasArg().argName("OFILE").desc("output molecules, w/ scores").build());
    opts.addOption(Option.builder("describe").desc("describe db").build());
    opts.addOption(Option.builder("describescaf").desc("describe scaf: mols, stats").build());
    opts.addOption(Option.builder("process_mols").desc("process input molecules").build());
    opts.addOption(Option.builder("scafid").hasArg().argName("ID").desc("scaf ID").build());
    opts.addOption(Option.builder("dbtype").hasArg().argName("DBTYPE").desc("db type (postgres|mysql|derby) ["+dbtype+"]").build());
    opts.addOption(Option.builder("chemkit").hasArg().argName("CHEMKIT").desc("chemical cartridge (rdkit|openchord) ["+chemkit+"]").build());
    opts.addOption(Option.builder("dbhost").hasArg().argName("DBHOST").desc("db host ["+dbhost+"]").build());
    opts.addOption(Option.builder("dbdir").hasArg().argName("DBDIR").desc("db dir (Derby only) ["+dbdir+"]").build());
    opts.addOption(Option.builder("dbname").hasArg().argName("DBNAME").desc("db name ["+dbname+"]").build());
    opts.addOption(Option.builder("dbschema").hasArg().argName("DBSCHEMA").desc("db schema ["+dbschema+"] (postgres)").build());
    opts.addOption(Option.builder("dbusr").hasArg().argName("DBUSR").desc("db user ["+dbusr+"]").build());
    opts.addOption(Option.builder("dbpw").hasArg().argName("DBPW").desc("db password").build());
    opts.addOption(Option.builder("dbport").type(Integer.class).hasArg().argName("DBPORT").desc("db port ["+dbport+"]").build());
    opts.addOption(Option.builder("maxatoms").type(Integer.class).hasArg().argName("MAXATOMS").desc("max atom count of input mol ["+maxatoms+"]").build());
    opts.addOption(Option.builder("maxrings").type(Integer.class).hasArg().argName("MAXRINGS").desc("max ring count of input mol ["+maxrings+"]").build());
    opts.addOption(Option.builder("nmax").type(Integer.class).hasArg().argName("NMAX").desc("quit after NMAX molecules").build());
    opts.addOption(Option.builder("nskip").type(Integer.class).hasArg().argName("NSKIP").desc("skip NSKIP molecules").build());
    opts.addOption(Option.builder("scafid_min").argName("SCAFID_MIN").desc("min scaf ID to calculate/annotate").build());
    opts.addOption(Option.builder("scafid_max").argName("SCAFID_MAX").desc("max scaf ID to calculate/annotate").build());

    opts.addOption("v", "verbose", false, "Verbose.");
    opts.addOption("vv", "vverbose", false, "Very verbose.");
    opts.addOption("vvv", "vvverbose", false, "Very very verbose.");
    opts.addOption("h", "help", false, "Show this help.");
    HelpFormatter helper = new HelpFormatter();
    CommandLineParser clip = new PosixParser();
    CommandLine clic = null;
    try {
      clic = clip.parse(opts, args);
    } catch (ParseException e) {
      helper.printHelp(APPNAME, HELPHEADER, opts, e.getMessage(), true);
      System.exit(0);
    }
    ifile = clic.getOptionValue("i");
    if (clic.hasOption("o")) ofile = clic.getOptionValue("o");
    if (clic.hasOption("dbhost")) dbhost = clic.getOptionValue("dbhost");
    if (clic.hasOption("dbname")) dbname = clic.getOptionValue("dbname");
    if (clic.hasOption("dbschema")) dbschema = clic.getOptionValue("dbschema");
    if (clic.hasOption("dbusr")) dbusr = clic.getOptionValue("dbusr");
    if (clic.hasOption("dbpw")) dbpw = clic.getOptionValue("dbpw");
    if (clic.hasOption("dbdir")) dbdir = clic.getOptionValue("dbdir");
    if (clic.hasOption("dbport")) dbport = (Integer)(clic.getParsedOptionValue("dbport"));
    if (clic.hasOption("chemkit")) chemkit = clic.getOptionValue("chemkit");
    if (clic.hasOption("dbtype")) dbtype = clic.getOptionValue("dbtype");
    if (clic.hasOption("maxrings")) maxrings = (Integer)(clic.getParsedOptionValue("maxrings"));
    if (clic.hasOption("maxatoms")) maxatoms = (Integer)(clic.getParsedOptionValue("maxatoms"));
    if (clic.hasOption("nmax")) nmax = (Integer)(clic.getParsedOptionValue("nmax"));
    if (clic.hasOption("nskip")) nskip = (Integer)(clic.getParsedOptionValue("nskip"));
    if (clic.hasOption("scafid")) scafid = (Integer)(clic.getParsedOptionValue("scafid"));
    if (clic.hasOption("scafid_min")) scafid_min = (Long)(clic.getParsedOptionValue("scafid_min"));
    if (clic.hasOption("scafid_max")) scafid_max = (Long)(clic.getParsedOptionValue("scafid_max"));
    if (clic.hasOption("describe")) describe = true;
    if (clic.hasOption("describescaf")) describescaf = true;
    if (clic.hasOption("process_mols")) process_mols = true;
    if (clic.hasOption("vvv")) verbose = 3;
    else if (clic.hasOption("vv")) verbose = 2;
    else if (clic.hasOption("v")) verbose = 1;
    if (clic.hasOption("h")) {
      helper.printHelp(APPNAME, HELPHEADER, opts, "", true);
      System.exit(0);
    }

    if (verbose>0) System.err.println("JRE_VERSION: "+JREUtils.JREVersion());

    MolImporter molReader=null;
    if (ifile!=null)
    {
      if (!(new File(ifile).exists())) 
      helper.printHelp(APPNAME, HELPHEADER, opts, ("Non-existent input file: "+ifile), true);
      molReader = new MolImporter(ifile);
    }

    MolExporter molWriter=null;
    if (ofile!=null)
    {
      String ofmt=MFileFormatUtil.getMostLikelyMolFormat(ofile);
      if (ofmt.equals("smiles")) ofmt="smiles:+n-a"; //Kekule for compatibility
      molWriter=new MolExporter(new FileOutputStream(ofile),ofmt);
    } else {
      molWriter=new MolExporter(System.out,"sdf");
    }

    String dbname_full=(dbtype.equals("derby")?(dbdir+"/"+dbname):dbname);

    if (verbose>0)
    {
      if (dbtype.equals("postgres") && dbport!=5432)
        System.err.println("Warning: non-standard "+dbtype+" port: "+dbport+" (normally 5432).");
      else if (dbtype.equals("mysql") && dbport!=3306)
        System.err.println("Warning: non-standard "+dbtype+" port: "+dbport+" (normally 3306).");
      System.err.println("JChem version: "+com.chemaxon.version.VersionInfo.getVersion());
    }
   
    DBCon dbcon = null;
    try { dbcon = new DBCon(dbtype,dbhost,dbport,dbname_full,dbusr,dbpw); }
    catch (Exception e) {
      helper.printHelp(APPNAME, HELPHEADER, opts, ("DB ("+dbtype+") error; "+e.getMessage()), true);
      System.exit(0);
    }
    if (dbcon==null) {
      helper.printHelp(APPNAME, HELPHEADER, opts, ("DB ("+dbtype+") connection failed."), true);
      System.exit(0);
    } else if (verbose>0) {
      System.err.println("DB ("+dbtype+") connection ok :"+(dbtype.equals("derby")?"":(dbhost+":"+dbport+":"))+dbname_full);
      if (verbose>1) System.err.println(dbcon.serverStatusTxt());
    }

    try
    {
      if (describe)
      {
        System.out.println("database: ("+dbtype+") "+dbname_full);
        System.out.println(badapple_utils.DBDescribeTxt(dbcon,dbschema));
      }
      else if (describescaf)
      {
        if (scafid==null) 
          helper.printHelp(APPNAME, HELPHEADER, opts, ("ERROR: -scafid ID required for -describescaf."), true);
        System.out.println("database: "+dbname_full+"\nScafID: "+describescaf);
        System.out.println(badapple_utils.ScaffoldDescribeTxt(dbcon,dbschema,chemkit,scafid,verbose));
      }
      else if (process_mols)
      {
        if (molReader==null)
          helper.printHelp(APPNAME, HELPHEADER, opts, ("ERROR: -i IFILE required for -process_mols."), true);
        //System.err.println("DEBUG: nskip="+nskip+" ; nmax="+nmax);
        badapple_utils.ProcessMols(dbcon,dbschema,chemkit,molReader,molWriter,nskip,nmax,maxatoms,maxrings,verbose);
      }
      else
      {
        helper.printHelp(APPNAME, HELPHEADER, opts, ("ERROR: no operation specified."), true);
      }
    }
    catch (Exception e) { System.err.println("DB ("+dbtype+") error; "+e.getMessage()); }
    System.exit(0);
  }
}

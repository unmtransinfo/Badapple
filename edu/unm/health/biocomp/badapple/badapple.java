package edu.unm.health.biocomp.badapple;

import java.io.*;
import java.util.*;
import java.sql.*;
import java.text.DateFormat;

import chemaxon.struc.*;
import chemaxon.formats.*;
import chemaxon.marvin.io.*;

import edu.unm.health.biocomp.db.*; // DBCon, pg_utils, mysql_utils, derby_utils
import edu.unm.health.biocomp.hscaf.*;
import edu.unm.health.biocomp.util.time_utils;

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
  private static String dbhost="localhost";
  private static Integer dbport=5432; //PostgreSql default
  //private static Integer dbport=3306; //MySql default
  private static String dbname="badapple";
  private static String dbdir="/tmp";
  private static String dbschema="public";
  private static String dbusr="www";
  private static String dbpw="foobar";
  private static String dbtype="postgres";
  private static String chemkit="rdkit";
  private static int maxatoms=50;
  private static int maxrings=5;

  private static void Help(String msg)
  {
    System.err.println(msg+"\n"
      +"badapple - command line app for Badapple system\n"
      +"\n"
      +"From the UNM Translational Informatics Division\n"
      +"\n"
      +"usage: badapple [options]\n"
      +"\n"
      +"  operations (one of):\n"
      +"    -describe ................. describe db\n"
      +"    -describescaf ............. describe scaf: mols, stats\n"
      +"    -process_mols ............. process input molecules\n"
      +"\n"
      +"  i/o:\n"
      +"    -i IFILE .................. input molecules\n"
      +"    -o OFILE .................. output molecules, w/ scores\n"
      +"    -scafid ID ................ scaf ID\n"
      +"\n"
      +"  options:\n"
      +"    -dbtype DBTYPE ............ db type (postgres|mysql|derby) ["+dbtype+"]\n"
      +"    -chemkit CHEMKIT .......... chemical cartridge (rdkit|openchord) ["+chemkit+"]\n"
      +"    -dbhost DBHOST ............ db host ["+dbhost+"]\n"
      +"    -dbport DBPORT ............ db port ["+dbport+"]\n"
      +"    -dbdir DBDIR .............. db dir (Derby only) ["+dbdir+"]\n"
      +"    -dbname DBNAME ............ db name ["+dbname+"]\n"
      +"    -dbschema DBSCHEMA ........ db schema ["+dbschema+"] (postgres)\n"
      +"    -dbusr DBUSR .............. db user ["+dbusr+"]\n"
      +"    -dbpw DBPW ................ db password\n"
      +"    -maxatoms MAX ............. max atom count of input mol ["+maxatoms+"]\n"
      +"    -maxrings MAX ............. max ring count of input mol ["+maxrings+"]\n"
      +"    -nmax NMAX ................ quit after NMAX molecules\n"
      +"    -nskip NSKIP .............. skip NSKIP molecules\n"
      +"    -scafid_min MIN ........... min scaf ID to calculate/annotate\n"
      +"    -scafid_max MAX ........... max scaf ID to calculate/annotate\n"
      +"    -v[v[v]] .................. verbose [very [very]]\n"
      +"    -h ........................ this help\n"
      +"\n"
      );
    System.exit(1);
  }
  private static int verbose=0;
  private static String smifmt="cxsmiles:u-L-l-e-d-D-p-R-f-w";
  private static String ifile=null;
  private static String ofile=null;
  private static String ofile_scaf=null;
  private static Boolean describe=false;
  private static Boolean describescaf=false;
  private static Boolean process_mols=false;
  private static Integer scafid=null;
  private static int nmax=0;
  private static int nskip=0;
  private static Long scafid_min=null;
  private static Long scafid_max=null;

  /////////////////////////////////////////////////////////////////////////////
  private static void ParseCommand(String args[])
  {
    for (int i=0;i<args.length;++i)
    {
      if (args[i].equals("-i")) ifile=args[++i];
      else if (args[i].equals("-o")) ofile=args[++i];
      else if (args[i].equals("-dbhost")) dbhost=args[++i];
      else if (args[i].equals("-dbport")) dbport=Integer.parseInt(args[++i]);
      else if (args[i].equals("-dbname")) dbname=args[++i];
      else if (args[i].equals("-dbdir")) dbdir=args[++i];
      else if (args[i].equals("-dbschema")) dbschema=args[++i];
      else if (args[i].equals("-dbusr")) dbusr=args[++i];
      else if (args[i].equals("-dbpw")) dbpw=args[++i];
      else if (args[i].equals("-dbtype")) dbtype=args[++i];
      else if (args[i].equals("-chemkit")) chemkit=args[++i];
      else if (args[i].equals("-describe")) describe=true;
      else if (args[i].equals("-describescaf")) describescaf=true;
      else if (args[i].equals("-process_mols")) process_mols=true;
      else if (args[i].equals("-scafid")) scafid=Integer.parseInt(args[++i]);
      else if (args[i].equals("-maxatoms")) maxatoms=Integer.parseInt(args[++i]);
      else if (args[i].equals("-maxrings")) maxrings=Integer.parseInt(args[++i]);
      else if (args[i].equals("-nmax")) nmax=Integer.parseInt(args[++i]);
      else if (args[i].equals("-nskip")) nskip=Integer.parseInt(args[++i]);
      else if (args[i].equals("-scafid_min")) scafid_min=Long.parseLong(args[++i]);
      else if (args[i].equals("-scafid_max")) scafid_max=Long.parseLong(args[++i]);
      else if (args[i].equals("-v")) verbose=1;
      else if (args[i].equals("-vv")) verbose=2;
      else if (args[i].equals("-vvv") || args[i].equals("-debug")) verbose=3;
      else if (args[i].equals("-h")) Help("");
      else Help("Unknown option: "+args[i]);
    }
  }
  /////////////////////////////////////////////////////////////////////////////
  public static void main(String[] args)
    throws IOException,SQLException
  {
    ParseCommand(args);

    MolImporter molReader=null;
    if (ifile!=null)
    {
      if (!(new File(ifile).exists())) Help("Non-existent input file: "+ifile);
      molReader = new MolImporter(ifile);
    }

    MolExporter molWriter=null;
    if (ofile!=null)
    {
      String ofmt=MFileFormatUtil.getMostLikelyMolFormat(ofile);
      if (ofmt.equals("smiles")) ofmt="smiles:+n-a"; //Kekule for compatibility
      molWriter=new MolExporter(new FileOutputStream(ofile),ofmt);
    }

    String dbname_full=(dbtype.equals("derby")?(dbdir+"/"+dbname):dbname);

    if (verbose>0)
    {
      if (dbtype.equals("postgres") && dbport!=5432)
        System.err.println("Warning: non-standard "+dbtype+" port: "+dbport+" (normally 5432).");
      else if (dbtype.equals("mysql") && dbport!=3306)
        System.err.println("Warning: non-standard "+dbtype+" port: "+dbport+" (normally 3306).");
      //System.err.println("JChem version: "+chemaxon.jchem.version.VersionInfo.JCHEM_VERSION); //pre-v6.3
      System.err.println("JChem version: "+com.chemaxon.version.VersionInfo.getVersion());
    }
   
    DBCon dbcon = null;
    try { dbcon = new DBCon(dbtype,dbhost,dbport,dbname_full,dbusr,dbpw); }
    catch (Exception e) { Help("DB ("+dbtype+") error; "+e.getMessage()); }

    if (dbcon==null)
      Help("DB ("+dbtype+") connection failed.");
    else if (verbose>0)
    {
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
        if (scafid==null) Help("ERROR: -scafid ID required for -describescaf.");
        System.out.println("database: "+dbname_full+"\nScafID: "+describescaf);
        System.out.println(badapple_utils.ScaffoldDescribeTxt(dbcon,dbschema,chemkit,scafid,verbose));
      }
      else if (process_mols)
      {
        if (molReader==null) Help("ERROR: -i IFILE required for -process_mols.");
        //System.err.println("DEBUG: nskip="+nskip+" ; nmax="+nmax);
        badapple_utils.ProcessMols(dbcon,dbschema,chemkit,molReader,molWriter,nskip,nmax,maxatoms,maxrings,verbose);
      }
      else
      {
        Help("ERROR: no operation specified.");
      }
    }
    catch (Exception e) { System.err.println("DB ("+dbtype+") error; "+e.getMessage()); }

    System.exit(0);
  }
}

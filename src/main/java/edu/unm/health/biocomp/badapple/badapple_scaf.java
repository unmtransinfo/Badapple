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
	@author Jeremy J Yang
*/
public class badapple_scaf
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
  private static int maxatoms=100;
  private static int maxrings=10;

  private static void Help(String msg)
  {
    System.err.println(msg+"\n"
      +"badapple - command line app for scaffold calculations\n"
      +"\n"
      +"From the UNM Translational Informatics Division\n"
      +"\n"
      +"usage: badapple_scaf [options]\n"
      +"\n"
      +"  operations (one of):\n"
      +"    -describe ................. describe db\n"
      +"    -calc_scaf ................ compute scaf scores\n"
      +"    -annotate_scaf ............ compute scaf scores; write to db (column: pscore)\n"
      +"\n"
      +"  i/o:\n"
      +"    -i IFILE .................. input molecules\n"
      +"    -o OFILE .................. output db scaffolds, stats, computed scores\n"
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
      +"NOTE: -calc_scaf and -annotate_scaf requires activity table.\n"
      +"NOTE: -o OFILE may be combined with -annotate_scaf\n"
      );
    System.exit(1);
  }
  private static int verbose=0;
  private static String smifmt="cxsmiles:u-L-l-e-d-D-p-R-f-w";
  private static String ifile=null;
  private static String ofile=null;
  private static Boolean describe=false;
  private static Boolean annotate_scaf=false;
  private static Boolean calc_scaf=false;
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
      else if (args[i].equals("-calc_scaf")) calc_scaf=true;
      else if (args[i].equals("-annotate_scaf")) annotate_scaf=true;
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

    File fout_scaf=(ofile!=null)?(new File(ofile)):null;

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
      else if (annotate_scaf || calc_scaf)
      {
        long n_scaf_done=0;
        if (scafid_min==null) scafid_min=1L;
        if (scafid_max==null) scafid_max=badapple_utils.GetMaxScafID(dbcon,dbschema);
        n_scaf_done=badapple_utils.ComputeScaffoldScores(dbcon,dbschema,scafid_min,scafid_max,fout_scaf,annotate_scaf,verbose);
        System.err.println("scafs processed: "+n_scaf_done);
        if (ofile!=null)
          System.err.println("scafs output file: "+ofile);
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

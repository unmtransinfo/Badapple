package edu.unm.health.biocomp.badapple;

import java.io.*;
import java.util.*;
import java.sql.*;
import java.text.DateFormat;

import chemaxon.struc.*;
import chemaxon.formats.*;
import chemaxon.marvin.io.MolExportException;
import chemaxon.license.*; // LicenseManager

import edu.unm.health.biocomp.util.db.*;
import edu.unm.health.biocomp.hscaf.*;
import edu.unm.health.biocomp.util.*;

/**	Static utility methods for BADAPPLE database system.
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
	<ul>
	<li>Derby JDBC driver (org.apache.derby.jdbc.EmbeddedDriver).
	<li>No chemical cartridge.
	<li>Derby useful for local storage when shared server not available.
	</ul>
	</ul>
	<br>
	@author Jeremy J Yang
*/
public class badapple_utils
{
  public static final String SMIFMT="cxsmiles:u-L-l-e-d-D-p-R-f-w";

  /////////////////////////////////////////////////////////////////////////////
  /**	Promiscuity score computation:
        score = <br>
		sActive / (sTested + median(sTested)) * <br>
		aActive / (aTested + median(aTested)) * <br>
		wActive / (wTested + median(wTested)) * <br>
		1e5 <br>
	<br>
        where: <br>
          sTested (substances tested) = # tested substances containing this scaffold <br>
          sActive (substances active) = # active substances containing this scaffold <br>
          aTested (assays tested) = # assays with tested compounds containing this scaffold <br>
          aActive (assays active) = # assays with active compounds containing this scaffold <br>
          wTested (samples tested) = # samples (wells) containing this scaffold <br>
          wActive (samples active) = # active samples (wells) containing this scaffold <br>
  */
  public static Float ComputeScore(long sTested,long sActive,long aTested,long aActive,long wTested,long wActive,long median_sTested,long median_aTested,long median_wTested)
  {
    if (sTested==0 || aTested==0 || wTested==0) return null; //null means no evidence
    Float pScore=
	1.0f *
        sActive / (sTested + median_sTested) *
        aActive / (aTested + median_aTested) *
        wActive / (wTested + median_wTested) *
        100.0f * 1000.0f ;
    pScore = (float)(Math.round(pScore*100)/100); //rounds to two decimal places
    return pScore;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return description text, with scaffold and compound counts.
  */
  public static String DBDescribeTxt(DBCon dbcon,String schema)
	throws SQLException,Exception
  {
    String txt=DBMetaDataTxt(dbcon,schema);

    ResultSet rset=dbcon.executeSql("SELECT count(*) FROM "+schema+".compound");
    if (rset.next())
      txt+=("compound count: "+rset.getInt(1)+"\n");
    rset.getStatement().close();
    rset=dbcon.executeSql("SELECT count(*) FROM "+schema+".scaffold");
    if (rset.next())
      txt+=("scaffold count: "+rset.getInt(1)+"\n");
    rset.getStatement().close();
//    try {
//      rset=dbcon.executeSql("SELECT count(*) FROM "+schema+".activity"); //may be slow
//      if (rset.next())
//        txt+=("activity count: "+rset.getInt(1)+"\n");
//      rset.getStatement().close();
//    }
//    catch (Exception e) { txt+=("activity count: 0\n"); } //activity table may not exist
    return txt;
  }
  /////////////////////////////////////////////////////////////////////////////
  public static String DBMetaDataTxt(DBCon dbcon,String schema)
	throws SQLException,Exception
  {
    DatabaseMetaData meta=dbcon.getConnection().getMetaData();
    String txt=(meta.getDatabaseProductName()+" "+meta.getDatabaseMajorVersion()+"."+meta.getDatabaseMinorVersion()+"\n");
    txt+=(meta.getDriverName()+" "+meta.getDriverVersion()+"\n");
    String sql;
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT db_description,db_date_built FROM "+schema+".metadata");
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT db_description,db_date_built FROM metadata");
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT db_description,db_date_built FROM "+schema+".metadata");
    else
    {
      System.err.println("ERROR: BADAPPLE dbtype unknown.  (Aaack!)");
      throw new Exception("ERROR: BADAPPLE dbtype unknown.  (Aaack!)");
    }
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
    {
      txt+=(rset.getString("db_description")+" ["+rset.getString("db_date_built")+"]\n");
    }
    else //ERROR; metadata not in db? (Should not happen.)
    {
      System.err.println("ERROR: BADAPPLE metadata not found in database.  (Aaack!)");
      throw new Exception("ERROR: BADAPPLE metadata not found in database.  (Aaack!)");
    }
    rset.getStatement().close();
    return txt;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Returns scaffold statistics medians needed for scoring.
  */
  public static HashMap<String,Integer> GetMedians(DBCon dbcon,String schema)
	throws SQLException,Exception
  {
    HashMap<String,Integer> medians = new HashMap<String,Integer>();
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT median_ncpd_tested,median_nsub_tested,median_nass_tested,median_nsam_tested FROM "+schema+".metadata");
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT median_ncpd_tested,median_nsub_tested,median_nass_tested,median_nsam_tested FROM metadata");
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT median_ncpd_tested,median_nsub_tested,median_nass_tested,median_nsam_tested FROM "+schema+".metadata");
    else
    {
      System.err.println("ERROR: BADAPPLE dbtype unknown.  (Aaack!)");
      throw new Exception("ERROR: BADAPPLE dbtype unknown.  (Aaack!)");
    }
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
    {
      medians.put("median_cTested",rset.getInt("median_ncpd_tested"));
      medians.put("median_sTested",rset.getInt("median_nsub_tested"));
      medians.put("median_aTested",rset.getInt("median_nass_tested"));
      medians.put("median_wTested",rset.getInt("median_nsam_tested"));
    }
    else //ERROR; metadata not in db? (Should not happen.)
    {
      System.err.println("ERROR: BADAPPLE medians not found in database.  (Aaack!)");
      throw new Exception("ERROR: BADAPPLE medians not found in database.  (Aaack!)");
    }
    rset.getStatement().close();
    return medians;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Returns string describing scaffold from database.
  */
  public static String ScaffoldDescribeTxt(DBCon dbcon,String schema,String chemkit,long scafid,int verbose)
	throws SQLException,Exception
  {
    String txt="";
    txt+=("smi,cid,sTested,sActive,aTested,aActive,wTested,wActive\n");
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT c.cid,cansmi,isosmi,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE s.scafid="+scafid+" AND c.cid=s.cid");
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT c.cid,cansmi,isosmi,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active FROM compound AS c, scaf2cpd AS s WHERE s.scafid="+scafid+" AND c.cid=s.cid");
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT c.cid,cansmi,isosmi,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE s.scafid="+scafid+" AND c.cid=s.cid");
    ResultSet rset=dbcon.executeSql(sql);
    while (rset.next())
    {
      txt+=(String.format("\"%s\",%d,%d,%d,%d,%d,%d,%d\n",
	rset.getString("cansmi"),
	rset.getLong("cid"),
	rset.getInt("nsub_tested"),
	rset.getInt("nsub_active"),
	rset.getInt("nass_tested"),
	rset.getInt("nass_active"),
	rset.getInt("nsam_tested"),
	rset.getInt("nsam_active")));
    }
    rset.getStatement().close();
    ScaffoldScore score=GetScaffoldScore(dbcon,schema,chemkit,scafid,verbose);
    txt+=("score: "+score.getScore()+"\n");
    if (verbose>1)
    {
      txt+=DBMetaDataTxt(dbcon,schema);
      HashMap<String,Integer> medians=GetMedians(dbcon,schema);
      txt+=("median_cTested: "+medians.get("median_cTested")+"\n");
      txt+=("median_sTested: "+medians.get("median_sTested")+"\n");
      txt+=("median_aTested: "+medians.get("median_aTested")+"\n");
      txt+=("median_wTested: "+medians.get("median_wTested")+"\n");
    }
    return txt;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Returns largest scaffold ID.
  */
  public static long GetMaxScafID(DBCon dbcon,String schema)
	throws SQLException
  {
    long scafid_max=0;
    ResultSet rset=null;
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      rset=dbcon.executeSql("SELECT max(id) FROM "+schema+".scaffold");
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      rset=dbcon.executeSql("SELECT max(id) FROM scaffold");
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      rset=dbcon.executeSql("SELECT max(id) FROM "+schema+".scaffold");
    if (rset.next()) scafid_max=rset.getLong(1);
    rset.getStatement().close();
    return scafid_max;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Compute scaffold scores, optionally annotate scaffold table,
	optionally write to file.
  */
  public static long ComputeScaffoldScores(DBCon dbcon,String schema,
	long scafid_min,long scafid_max,File fout,Boolean annotate,int verbose)
	throws SQLException,IOException,Exception
  {
    PrintWriter fout_writer=null;
    if (fout!=null)
    {
      fout_writer=new PrintWriter(new BufferedWriter(new FileWriter(fout,false))); //overwrite
      fout_writer.printf("smiles,scafid,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive,pScore,inDrug\n");
    }
    HashMap<String,Integer> medians=GetMedians(dbcon,schema);
    if (verbose>0)
    {
      for (String key: medians.keySet())
        System.err.println("medians["+key+"]: "+medians.get(key));
    }
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT id,scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug FROM "+schema+".scaffold WHERE id>="+scafid_min+" AND id<="+scafid_max+" ORDER BY id ASC");
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT id,scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug FROM scaffold WHERE id>="+scafid_min+" AND id<="+scafid_max+" ORDER BY id ASC");
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT id,scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug FROM "+schema+".scaffold WHERE id>="+scafid_min+" AND id<="+scafid_max+" ORDER BY id ASC");
    ResultSet rset=dbcon.executeSql(sql);
    long n_scaf=0;
    long n_update=0;
    long n_null=0;
    long n_zero=0;
    long n_gtzero=0;
    while (rset.next())
    {
      ScaffoldScore score = new ScaffoldScore();
      String scafsmi=rset.getString("scafsmi");
      Long scafid=rset.getLong("id");
      Integer cTotal=rset.getInt("ncpd_total"); // not used for score
      Integer cTested=rset.getInt("ncpd_tested"); // not used for score
      Integer cActive=rset.getInt("ncpd_active"); // not used for score
      Integer sTotal=rset.getInt("nsub_total"); // not used for score
      Integer sTested=rset.getInt("nsub_tested");
      Integer sActive=rset.getInt("nsub_active");
      Integer aTested=rset.getInt("nass_tested");
      Integer aActive=rset.getInt("nass_active");
      Integer wTested=rset.getInt("nsam_tested");
      Integer wActive=rset.getInt("nsam_active");
      Boolean inDrug=rset.getBoolean("in_drug");
      //System.err.println(String.format("DEBUG: scafsmi="+scafsmi+",scafid="+scafid+",cTested="+cTested+",cActive="+cActive+",sTested="+sTested+",sActive="+sActive+",aTested="+aTested+",aActive="+aActive+",wTested="+wTested+",wActive="+wActive+",inDrug="+inDrug));
      score.setID(scafid);
      score.setSmiles(scafsmi);
      score.setKnown(true);
      score.setInDrug(inDrug);
      score.setStats(cTested,cActive,sTested,sActive,aTested,aActive,wTested,wActive);
      Float pScore=ComputeScore(sTested,sActive,aTested,aActive,wTested,wActive,medians.get("median_sTested"),medians.get("median_aTested"),medians.get("median_wTested"));
      score.setScore(pScore);
      if (fout!=null)
        fout_writer.printf("%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s\n",
	  scafsmi,scafid,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive,
	((pScore!=null)?String.format("%.2f",pScore):""),
	(inDrug?"1":"0"));
      if (pScore==null) ++n_null;
      else if (pScore==0.0) ++n_zero;
      else ++n_gtzero;
      if (annotate && pScore!=null)
      {
        UpdateScaffoldScore(dbcon,schema,scafid,pScore,"pscore");
        ++n_update;
      }
      ++n_scaf;
      if (verbose>0 && (n_scaf%1000)==0)
        System.err.println("n_scaf: "+n_scaf+" ("+((int)((float)100*n_scaf/(scafid_max-scafid_min+1)))+"%)");
    }
    if (n_scaf==0)
      System.err.println("ERROR: ComputeScaffoldScores() data not found.");
    rset.getStatement().close();
    System.err.println("scafid range: ["+scafid_min+"-"+scafid_max+"] ("+(scafid_max-scafid_min+1)+")");
    System.err.println("n_scaf: "+n_scaf);
    System.err.println("n_null: "+n_null+" ; n_zero: "+n_zero+" ; n_gtzero: "+n_gtzero);
    System.err.println("n_update: "+n_update+" (scores updated in db)");
    if (fout!=null)
      fout_writer.close();
    return n_scaf;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Annotate scaffold table row with score.
  */
  public static boolean UpdateScaffoldScore(DBCon dbcon,String schema,
	long scafid,
	float pScore,String colname)
	throws SQLException,IOException
  {
    boolean ok=false;
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("UPDATE "+schema+".scaffold SET "+colname+"="+pScore+" WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("UPDATE scaffold SET "+colname+"="+pScore+" WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("UPDATE "+schema+".scaffold SET "+colname+"="+pScore+" WHERE id="+scafid);
    ok=dbcon.execute(sql);
    return ok;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return promiscuity score for given SCAFID.
	If scafid not in database, return null.
	If medians not found, throws special Exception.
  */
  public static ScaffoldScore GetScaffoldScore(DBCon dbcon,String schema,String chemkit,long scafid,int verbose)
	throws SQLException,Exception
  {
    ScaffoldScore score = null; //If scaffold not in db; return null.
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug FROM "+schema+".scaffold WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug FROM scaffold WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug FROM "+schema+".scaffold WHERE id="+scafid);
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
    {
      score = new ScaffoldScore();
      String scafsmi=rset.getString("scafsmi");
      Integer cTotal=rset.getInt("ncpd_total");
      Integer cTested=rset.getInt("ncpd_tested");
      Integer cActive=rset.getInt("ncpd_active");
      Integer sTotal=rset.getInt("nsub_total");
      Integer sTested=rset.getInt("nsub_tested");
      Integer sActive=rset.getInt("nsub_active");
      Integer aTested=rset.getInt("nass_tested");
      Integer aActive=rset.getInt("nass_active");
      Integer wTested=rset.getInt("nsam_tested");
      Integer wActive=rset.getInt("nsam_active");
      Boolean inDrug=rset.getBoolean("in_drug");

      HashMap<String,Integer> medians = GetMedians(dbcon,schema);
      Integer median_cTested=medians.get("median_cTested");
      Integer median_sTested=medians.get("median_sTested");
      Integer median_aTested=medians.get("median_aTested");
      Integer median_wTested=medians.get("median_wTested");

      score.setID(scafid);
      score.setSmiles(scafsmi);
      score.setKnown(true);
      score.setInDrug(inDrug);
      score.setStats(cTested,cActive,sTested,sActive,aTested,aActive,wTested,wActive);
      score.setScore(ComputeScore(sTested,sActive,aTested,aActive,wTested,wActive,median_sTested,median_aTested,median_wTested));
    }
    rset.getStatement().close();
    return score;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return promiscuity score for given Scaffold.  Returns ID
	via ScaffoldScore if in database.
	If not in database, return null.
  */
  public static ScaffoldScore GetScaffoldScore(DBCon dbcon,String schema,String chemkit,Scaffold scaf,int verbose)
	throws SQLException,Exception
  {
    return GetScaffoldScore(dbcon,schema,chemkit,scaf.getSmi(),verbose);
  }
  /////////////////////////////////////////////////////////////////////////////
  public static String RDKit_Version(DBCon dbcon)
  {
    String ver="";
    try
    {
      ResultSet rset=dbcon.executeSql("SELECT rdkit_version() AS ver");
      if (rset.next())
        ver=rset.getString("ver");
    }
    catch (Exception e) {
      System.err.println(e.getMessage());
    }
    return ver;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return promiscuity score for given scaffold smiles.  Returns ID
	via ScaffoldScore, if in database.
	If not in database, return null.
	<br>
	If not postgres and rdkit|openchord; must have canonical smiles in db.
	<br>
	Note, with RDKit, SMI::mol::VARCHAR = mol_to_smiles(mol_from_smiles(SMI))::VARCHAR.
  */
  public static ScaffoldScore GetScaffoldScore(DBCon dbcon,String schema,String chemkit,String smi,int verbose)
	throws SQLException,Exception
  {
    ScaffoldScore score = new ScaffoldScore();
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
    {
      if (chemkit.equalsIgnoreCase("openchord"))
        sql=("SELECT id FROM "+schema+".scaffold WHERE scafsmi=openbabel.cansmiles('"+smi+"')");
      else //rdkit
        sql=("SELECT id FROM "+schema+".scaffold WHERE scafsmi='"+smi+"'::mol::VARCHAR");
    }
    else 
      sql=("SELECT id FROM "+schema+".scaffold WHERE scafsmi='"+Cansmi(smi)+"'");
    if (verbose>2) System.err.println("DEBUG: SQL: "+sql);
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
    {
      Long scafid=rset.getLong("id");
      score = GetScaffoldScore(dbcon,schema,chemkit,scafid,verbose);
    }
    else
    {
      score.setSmiles(smi); // Not in db; return smiles for convenience.
      score.setKnown(false);
      score.setInDrug(false);
    }
    rset.getStatement().close();
    return score;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return ID for given scaffold smiles, or null if not in database.
	Only for non-Badapple (HScaf) use.
  */
  public static Long GetScaffoldID(DBCon dbcon,String schema,String chemkit,String smi,int verbose)
	throws SQLException,Exception
  {
    Long scafid=null;
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
    {
      if (chemkit.equalsIgnoreCase("openchord"))
        sql=("SELECT id FROM "+schema+".scaffold WHERE scafsmi=openbabel.cansmiles('"+Cansmi(smi)+"')");
      else //rdkit
        sql=("SELECT id FROM "+schema+".scaffold WHERE scafsmi='"+Cansmi(smi)+"'::mol::VARCHAR");
    }
    else 
      sql=("SELECT id FROM "+schema+".scaffold WHERE scafsmi='"+Cansmi(smi)+"'");
    if (verbose>2) System.err.println("DEBUG: SQL: "+sql);
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
      scafid=rset.getLong("id");
    rset.getStatement().close();
    return scafid;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	For given SCAFID, return smiles.
	If scafid not in database, return null.
  */
  public static String GetScaffoldSmiles(DBCon dbcon,String schema,long scafid,int verbose)
	throws SQLException,Exception
  {
    String scafsmi=null;
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT scafsmi FROM "+schema+".scaffold WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT scafsmi FROM scaffold WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT scafsmi FROM "+schema+".scaffold WHERE id="+scafid);
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
      scafsmi=rset.getString("scafsmi");
    rset.getStatement().close();
    return scafsmi;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	For given SCAFID, return child IDs as scaffold tree.
	If scafid not in database, return null.
  */
  public static String GetScaffoldTree(DBCon dbcon,String schema,long scafid,int verbose)
	throws SQLException,Exception
  {
    String scaftree=null;
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT scaftree FROM "+schema+".scaffold WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT scaftree FROM scaffold WHERE id="+scafid);
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT scaftree FROM "+schema+".scaffold WHERE id="+scafid);
    ResultSet rset=dbcon.executeSql(sql);
    if (rset.next())
      scaftree=rset.getString("scaftree");
    rset.getStatement().close();
    return scaftree;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return promiscuity scores for given molecule, meaning one score for each scaffold
	contained in the molecule.  This method for molecules in database, thus
	not requiring scaffold analysis.  Whether the query molecule is stereo
	or non-stereo, the exact stereo-specific match will be found if present in the
	database, and if not the non-stereo match will be found.  Arguably a
	stereo-specific query should not hit a non-stereo match, so this
	behavior might be reconsidered.
	<br>
	If molecule not in database, returns null.
	If molecule in database, but without scaffolds, returns empty scores ArrayList.
	<br>
	If DBTYPE not "postgres", no openchord/openbabel; must assume that (JChem) canonical smiles are stored.
  */
  public static ArrayList<ScaffoldScore> GetScaffoldScoresForDBMol(DBCon dbcon,String schema,String chemkit,Molecule mol,int verbose)
	throws SQLException,Exception
  {
    ArrayList<ScaffoldScore> scores = null;
    if (mol==null) return scores;
    String molname=mol.getName();
    String smi=null;
    try { smi=MolExporter.exportToFormat(mol,"smiles:"); } //escape backslashes?
    catch (Exception e) {
      System.err.println(e.getMessage());
      return scores;
    }
    // 1st query for exact isosmi match:
    // Issue: Can RDKit do isomeric?
    String sql;
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
    {
      if (chemkit.equalsIgnoreCase("openchord"))
        sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cansmi=openbabel.isosmiles('"+smi+"') AND c.cid=s.cid");
      else
        sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cansmi='"+smi+"'::mol::VARCHAR AND c.cid=s.cid");
    }
    else
      sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cansmi='"+Cansmi(smi)+"' AND c.cid=s.cid");
    //if (verbose>2) System.err.println("DEBUG: SQL: "+sql);
    ResultSet rset=dbcon.executeSql(sql);
    if (!rset.next())
    {
      rset.getStatement().close();
      // This query can  return multiple CIDs with different isosmis.
      if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      {
        if (chemkit.equalsIgnoreCase("openchord"))
          sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cansmi=openbabel.cansmiles('"+smi+"') AND c.cid=s.cid");
        else
          sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cansmi='"+smi+"'::mol::VARCHAR AND c.cid=s.cid");
      }
      else
        sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cansmi='"+Cansmi(smi)+"' AND c.cid=s.cid");
      if (verbose>2) System.err.println("DEBUG: SQL: "+sql);
      rset=dbcon.executeSql(sql);
      if (!rset.next()) //compound not in db, or no scafs; return null.
      {
        rset.getStatement().close();
        return null;
      }
    }
    scores = new ArrayList<ScaffoldScore>();
    Long cid=rset.getLong("cid");
    ArrayList<Long> cids = new ArrayList<Long>();
    ArrayList<Long> scafids = new ArrayList<Long>();
    scafids.add(rset.getLong("scafid"));
    while (rset.next())
    {
      if (!scafids.contains(rset.getLong("scafid")))
        scafids.add(rset.getLong("scafid"));
      if (!cids.contains(rset.getLong("cid")))
      {
        cids.add(rset.getLong("cid"));
        //System.err.println("DEBUG: mol found in DB; CID="+cid);
      }
    }
    rset.getStatement().close();
    for (long scafid: scafids)
    {
      ScaffoldScore score = GetScaffoldScore(dbcon,schema,chemkit,scafid,verbose);
      scores.add(score);
    }
    return scores;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return promiscuity scores for given molecule, meaning one score for each scaffold
	contained in the molecule.  
	<br>
	If molecule not in database, returns null.
	If molecule in database, but without scaffolds, returns empty scores ArrayList.
  */
  public static ArrayList<ScaffoldScore> GetScaffoldScoresForDBMol(DBCon dbcon,String schema,String chemkit,long cid,int verbose)
	throws SQLException,Exception
  {
    ArrayList<ScaffoldScore> scores = null;
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cid="+cid+" AND c.cid=s.cid");
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT c.cid,scafid FROM compound AS c, scaf2cpd AS s WHERE c.cid="+cid+" AND c.cid=s.cid");
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT c.cid,scafid FROM "+schema+".compound AS c, "+schema+".scaf2cpd AS s WHERE c.cid="+cid+" AND c.cid=s.cid");
    if (verbose>2) System.err.println("DEBUG: SQL: "+sql);
    ResultSet rset=dbcon.executeSql(sql);
    if (!rset.next()) //cid not in db, or no scafs; return null.
    {
      rset.getStatement().close();
      return null;
    }
    ArrayList<Long> scafids = new ArrayList<Long>();
    scafids.add(rset.getLong("scafid"));
    while (rset.next())
    {
      if (!scafids.contains(rset.getLong("scafid")))
        scafids.add(rset.getLong("scafid"));
    }
    rset.getStatement().close();
    scores = new ArrayList<ScaffoldScore>();
    for (long scafid: scafids)
    {
      ScaffoldScore score = GetScaffoldScore(dbcon,schema,chemkit,scafid,verbose);
      scores.add(score);
    }
    return scores;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return promiscuity scores for given molecule, meaning one score for each scaffold
	contained in the molecule.  This method for molecules not in database, thus
	requiring scaffold analysis.
  */
  public static ArrayList<ScaffoldScore> GetScaffoldScores(DBCon dbcon,String schema,String chemkit,Molecule mol,int verbose)
	throws SQLException,Exception
  {
    ArrayList<ScaffoldScore> scores = new ArrayList<ScaffoldScore>();
    if (mol==null) return scores;
    String molname=mol.getName();
    if (mol.getFragCount(MoleculeGraph.FRAG_BASIC)>1)
    {
      if (verbose>1)
        System.err.println("Warning: multi-frag mol; analyzing largest frag only: "+molname);
      mol=hier_scaffolds_utils.LargestPart(mol);
    }
    boolean ok=true;
    ScaffoldTree scaftree=null;
    boolean stereo=false;
    boolean keep_nitro_attachments=false;
    try {
      scaftree = new ScaffoldTree(mol,stereo,keep_nitro_attachments,(new ScaffoldSet()));
    }
    catch (Exception e) {
      System.err.println("Exception (ScaffoldTree):"+e.getMessage());
      ok=false;
    }
    if (!ok) return scores;
    if (verbose>1)
    {
      System.err.print("\tn_scaf="+scaftree.getScaffoldCount());
      System.err.print("\tn_link="+scaftree.getLinkerCount());
      System.err.println("\tn_chain="+scaftree.getSidechainCount());
    }
    int n_scaf=0;
    for (Scaffold scaf: scaftree.getScaffolds())
    {
      ++n_scaf;
      ScaffoldScore score=GetScaffoldScore(dbcon,schema,chemkit,scaf,verbose);
      scores.add(score); // If scaf unknown getKnown() will indicate.
      if (verbose>2)
      {
        System.err.println("\tscaf: "+n_scaf+". "+(scaf.getCansmi()));
        System.err.print("\t\tID="+(scaf.getID()));
        System.err.print(" cIDs="+scaf.getChildIDs());
        System.err.print(scaf.isRoot()?" (root)":"");
        System.err.print(scaf.isLeaf()?" (leaf)":"");
        System.err.println("");
      }
    }
    return scores;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Return cansmi or isosmi for given CID.  
  */
  public static String CID2Smiles(DBCon dbcon,String schema,long cid,boolean stereo)
	throws SQLException,Exception
  {
    String sql="";
    if (dbcon.getDBType().equalsIgnoreCase("postgres"))
      sql=("SELECT cansmi,isosmi FROM "+schema+".compound AS c WHERE c.cid="+cid);
    else if (dbcon.getDBType().equalsIgnoreCase("mysql"))
      sql=("SELECT cansmi,isosmi FROM compound AS c WHERE c.cid="+cid);
    else if (dbcon.getDBType().equalsIgnoreCase("derby"))
      sql=("SELECT cansmi,isosmi FROM "+schema+".compound AS c WHERE c.cid="+cid);
    ResultSet rset=dbcon.executeSql(sql);
    String smiles=null; //If cid not in db, return null.
    if (rset.next())
    {
      if (stereo) smiles=rset.getString("isosmi");
      else smiles=rset.getString("cansmi");
    }
    rset.getStatement().close();
    return smiles;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	For testing.  
  */
  public static ScaffoldScore getRandomScaffoldScore()
  {
    ScaffoldScore score = new ScaffoldScore();
    String [] scafsmis = {
	"C1CN2CCC1CC2",
	"O=C(CC1=CC=CC=C1)OC1CC2[NH2+]C(C1)C1OC21",
	"C1CC2[NH2+]C(C1)C1OC21",
	"O=C1C=CNC2=NC=CC=C12",
	"C1CCC23CCNC(CC4=CC=CC=C24)C3C1",
	"O=C(NC1=CC=CC=C1)C1=CC=CC=C1",
	"O=C1NC(=O)C2=CC=CC=C12",
	"C1CC2=CC=CC=C2OC1C1=CC=CC=C1",
	"C1COC2=CC=CC=C2C1",
	"C(CC1=CC=CC=C1)NCCC1=CC=CC=C1"
	};
    String scafsmi = scafsmis[(new Long(Math.round(Math.random() * 1000L))).intValue() % 10];
    Long cTested = Math.round(Math.random() * 100);
    Long cActive = Math.round(Math.random() * 0.2f  * cTested);
    Long sTested = Math.round(Math.random() * 100);
    Long sActive = Math.round(Math.random() * 0.2f  * sTested);
    Long aTested = Math.round(Math.random() * 1000);
    Long aActive = Math.round(Math.random() * 0.2f  * aTested);
    Long wTested = Math.round(Math.random() * 1000);
    Long wActive = Math.round(Math.random() * 0.2f  * wTested);
    Boolean inDrug = (Math.random() > 0.9f);
    Long median_cTested= 1L;
    Long median_sTested= 2L;
    Long median_aTested= 373L;
    Long median_wTested= 515L;
    score.setSmiles(scafsmi);
    score.setKnown(true);
    score.setInDrug(inDrug);
    score.setStats(cTested,cActive,sTested,sActive,aTested,aActive,wTested,wActive);
    Float pScore = ComputeScore(sTested,sActive,aTested,aActive,wTested,wActive,median_sTested,median_aTested,median_wTested);
    score.setScore(pScore);
    return score;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Process input molecules, do scaffold analysis, generate scores and write to output file.
  */
  public static void ProcessMols(DBCon dbcon,
	String dbschema,String chemkit,MolImporter molReader,MolExporter molWriter,
	int nskip,int nmax,int maxatoms,int maxrings,int verbose)
    throws IOException
  {
    Molecule mol;
    int n_mol=0;
    int n_mol_out=0;
    int n_err=0;
    int n_total_scaf=0;
    int n_scaf_known=0;
    int n_mol_bad_format=0;
    int n_mol_toobig=0;
    int n_mol_toomanyrings=0;
    int n_mol_noscafs=0;
    int n_mol_indb=0;
    long scafid_max=0;
    try { scafid_max = GetMaxScafID(dbcon,dbschema); }
    catch (Exception e)
    { System.err.println("Exception: "+e.getMessage()); return; }
    java.util.Date t_0 = new java.util.Date();
    if (verbose>0)
      System.err.println(DateFormat.getDateTimeInstance().format(t_0));
    java.util.Date t_i = t_0;
    while (true)
    {
      try {
        mol=molReader.read();
        if (mol==null) break; //EOF
        ++n_mol;
      }
      catch (MolFormatException e)
      {
        System.err.println(e.getMessage());
        ++n_err;
        ++n_mol;
        continue;
      }
      if (nskip>0 && n_mol<=nskip) continue;
      String molname=mol.getName();
      Molecule outmol=mol.cloneMolecule();
      outmol.setName(molname);
      outmol.setProperty("NAME",molname);
      boolean ok=true;
      boolean in_db=false;
      String smi=null;
      String status="";
      try { smi=MolExporter.exportToFormat(mol,SMIFMT); }
      catch (Exception e) {
        smi=null;
        status="Exception ("+(e.getMessage().replaceFirst("^\\s+","").replaceAll("\\n"," ")+")");
      }
      if (verbose>1)
        System.err.println(""+n_mol+". "+molname+"\t"+smi);
      int ring_count=hier_scaffolds_utils.RawRingsystemCount(mol);
      if (mol.getAtomCount()>maxatoms)
      {
        status = ("Skipped; natoms>maxatoms ("+mol.getAtomCount() +">"+maxatoms+")");
        if (verbose>1) System.err.println("Warning: "+status+" ["+n_mol+"] "+molname);
        outmol.setProperty("BADAPPLE_STATUS",status);
        ++n_mol_toobig;
      }
      else if (maxrings>0 && ring_count>maxrings)
      {
        status = ("Skipped; nrings>maxrings ("+ring_count +">"+maxrings+")");
        if (verbose>1) System.err.println("Warning: "+status+" ["+n_mol+"] "+molname);
        outmol.setProperty("BADAPPLE_STATUS",status);
        ++n_mol_toomanyrings;
      }
      else if (smi==null)
      {
        // Likely query features; may corrupt downstream analysis, thus skip molecule.
        if (verbose>1) System.err.println("ERROR: "+status+" ["+n_mol+"] "+molname);
        outmol.setProperty("BADAPPLE_STATUS",status);
        ++n_mol_bad_format;
        ++n_err;
      }
      else
      {
        ArrayList<ScaffoldScore> scores=null;
        try {
          scores=GetScaffoldScoresForDBMol(dbcon,dbschema,chemkit,mol,verbose);
          if (scores==null)
          {
            scores=GetScaffoldScores(dbcon,dbschema,chemkit,mol,verbose);
            if (verbose>1)
              System.err.println("Note: mol not in DB: ["+n_mol+"] "+molname);
          }
          else
          {
            ++n_mol_indb;
            in_db=true;
          }

          if (scores.size()>0)
          {
            Collections.sort(scores); //descending score order
            n_total_scaf+=scores.size();
            String scores_str="";
            String scafids_str="";
            String scafindrug_str="";
            String scafsmis_str="";
            int n_scaf_known_this=0;
            for (ScaffoldScore score: scores)
            {
              if (score==null)
                continue;
              if (score.getKnown())
              {
                ++n_scaf_known_this;
                if (verbose>1)
                {
                  System.err.println(String.format("\t%5d: %7.1f %s",score.getID(),score.getScore(),score.getSmiles()));
                }
                // Scaffolds not in db have null scores.
                if (score.getScore()!=null)
                  scores_str+=String.format("%.1f,",score.getScore());
                else
                  scores_str+=("none,");
                // Scaffolds not in db have no internal (db) IDs (only temporary).
                if (score.getID()<=scafid_max)
                  scafids_str+=(score.getID()+",");
                else
                  scafids_str+=(",");
                scafindrug_str+=(score.getInDrug()+",");
                scafsmis_str+=String.format("%s,",score.getSmiles());
              }
            }
            n_scaf_known+=n_scaf_known_this;
            if (n_scaf_known_this>0)
              outmol.setProperty("BADAPPLE_STATUS","Scores computed (nscaf="+scores.size()+")");
            else
              outmol.setProperty("BADAPPLE_STATUS","No score, scafs unknown (nscaf="+scores.size()+")");
            outmol.setProperty("BADAPPLE_PSCORES",scores_str.replaceFirst(",$","")); //SDF
            outmol.setProperty("BADAPPLE_SCAFIDS",scafids_str.replaceFirst(",$","")); //SDF
            outmol.setProperty("BADAPPLE_SCAFINDRUG",scafindrug_str.replaceFirst(",$","")); //SDF
            outmol.setProperty("BADAPPLE_SCAFSMILES",scafsmis_str.replaceFirst(",$","")); //SDF
            if (molWriter.getFormat().toLowerCase().matches("smi")) //SMI
              outmol.setName(molname+"\t"+scafids_str+"\t"+scores_str+"\t"+scafsmis_str);
          }
          else
          {
            status = ("No scaffolds, no score.");
            if (verbose>1) System.err.println("Warning: "+status+" ["+n_mol+"] "+molname);
            outmol.setProperty("BADAPPLE_STATUS",status);
            ++n_mol_noscafs;
          }
        }
        catch (Exception e)
        {
          System.err.println("Exception: "+e.getMessage());
          outmol.setProperty("BADAPPLE_STATUS","Exception ("+e.getMessage()+")");
          ++n_err;
        }
      }
      outmol.setProperty("BADAPPLE_IN_DB",""+in_db);
      if (molWriter!=null) { if (WriteMol(molWriter,outmol)) ++n_mol_out; else ++n_err; }
      if (nmax>0 && n_mol>=(nmax+nskip)) break;
    }
    try { dbcon.close(); }
    catch (SQLException e) { }
    if (molWriter!=null) molWriter.close();
    molReader.close();
    if (nskip>0)
      System.err.println("Skipped mols: "+nskip);
    System.err.println("Input mols: "+(n_mol-nskip));
    System.err.println("Output mols: "+n_mol_out);
    System.err.println("Skipped mols (natoms>"+maxatoms+"): "+n_mol_toobig);
    System.err.println("Skipped mols (nrings>"+maxrings+"): "+n_mol_toomanyrings);
    System.err.println("Skipped mols (format problem): "+n_mol_bad_format);
    System.err.println("Mols in db: "+n_mol_indb);
    System.err.println("Mols with no scaffolds: "+(n_mol_noscafs));
    // Count mols with no known scaffolds...?
    if (verbose>0)
    {
      System.err.println("Scaffolds known: "+n_scaf_known);
      System.err.println("Scaffolds unknown: "+(n_total_scaf-n_scaf_known));
      System.err.println("Scaffolds total: "+n_total_scaf);
    }
    System.err.println("Errors: "+n_err);
    if (verbose>0)
      System.err.println("Total elapsed time: "+time_utils.TimeDeltaStr(t_0,new java.util.Date()));
  }
  /////////////////////////////////////////////////////////////////////////////
  private static boolean WriteMol(MolExporter molWriter,Molecule mol)
  {
    try { molWriter.write(mol); }
    catch (Exception e) {
      System.err.println(e.getMessage());
      return false;
    }
    return true;
  }
  /////////////////////////////////////////////////////////////////////////////
  // JChem-canonical SMILES.
  public static String Cansmi(String smiles)
  {
    Molecule mol=null;
    try { mol=MolImporter.importMol(smiles,"smiles:"); }
    catch (IOException e) { System.err.println(e.getMessage()); }
    return Cansmi(mol);
  }
  /////////////////////////////////////////////////////////////////////////////
  // JChem-canonical SMILES.
  public static String Cansmi(Molecule mol)
  {
    String smi=null;
    try { smi=MolExporter.exportToFormat(mol,SMIFMT); }
    catch (MolExportException e) { System.err.println(e.getMessage()); }
    catch (IOException e) { System.err.println(e.getMessage()); }
    return smi;
  }
  /////////////////////////////////////////////////////////////////////////////
  public static Boolean TestChemaxonLicense()
  {
    return LicenseManager.isLicensed(LicenseManager.JCHEM);
  }
}

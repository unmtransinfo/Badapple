package edu.unm.health.biocomp.badapple;

import java.io.*;
import java.net.*; //URLEncoder, InetAddress
import java.text.*;
import java.util.*;
import java.util.regex.*;
import java.lang.Math;
import java.sql.*;
import javax.servlet.*;
import javax.servlet.http.*;

import com.oreilly.servlet.*; //MultipartRequest
import com.oreilly.servlet.multipart.DefaultFileRenamePolicy;

import chemaxon.formats.*;
import chemaxon.marvin.io.MolExportException;
import chemaxon.struc.*;
import chemaxon.license.*; // LicenseManager

import edu.unm.health.biocomp.badapple.*;
import edu.unm.health.biocomp.util.*;
import edu.unm.health.biocomp.util.http.*;
import edu.unm.health.biocomp.util.db.*;

/**	Badapple = Bioactivity data associative promiscuity pattern learning engine
	<br>
	Generates promiscuity scores (pScore) for input molecules,
	more precisely, the scaffolds contained therein, based on a database of
	bioactivity data.
	Scores are statistics (function of sample data) reflecting the weight
	of evidence indicating promiscuity.
	<br>
	Badapple: promiscuity patterns from noisy evidence , Yang JJ, Ursu O,
	Lipinski CA, Sklar LA, Oprea TI Bologa CG, J. Cheminfo. 8:29 (2016),
	DOI: 10.1186/s13321-016-0137-3.
	<br>
	@author Jeremy J Yang
*/
public class badapple_servlet extends HttpServlet
{
  private static ServletContext CONTEXT=null;
  //private static ServletConfig CONFIG=null;
  private static String APPNAME=null;	// configured in web.xml
  private static String DBTYPE=null;	// configured in web.xml
  private static String DBSCHEMA=null;	// configured in web.xml
  private static String DBNAME=null;	// configured in web.xml
  private static String DBHOST=null;	// configured in web.xml
  private static String DBUSR=null;	// configured in web.xml
  private static String DBPW=null;	// configured in web.xml
  private static Integer DBPORT=null;	// configured in web.xml
  private static String CHEMKIT=null;	// configured in web.xml
  private static String UPLOADDIR=null;	// configured in web.xml
  private static String SCRATCHDIR=null;	// configured in web.xml
  private static Integer N_MAX=null;	// configured in web.xml
  private static Integer MAX_POST_SIZE=Integer.MAX_VALUE; // configured in web.xml
  private static Integer PSCORE_CUTOFF_MODERATE=null;	// configured in web.xml
  private static Integer PSCORE_CUTOFF_HIGH=null;	// configured in web.xml
  private static Boolean DEBUG=false;	// configured in web.xml
  private static String PREFIX=null;
  private static String SERVLETNAME=null;
  private static int scratch_retire_sec=3600;
  private static String CONTEXTPATH=null;
  private static ResourceBundle RESOURCEBUNDLE=null;
  private static ArrayList<String> errors=null;
  private static ArrayList<String> outputs=null;
  private static HttpParams params=null;
  private static String SERVERNAME=null;
  private static String REMOTEHOST=null;
  private static String DATESTR=null;
  private static String color1="#F0A555";
  private static String color2="#EEEEEE";
  private static DBCon DBCON=null;
  private static ArrayList<Molecule> molsDB=null;
  private static int depsz=90;
  private static String MOL2IMG_SERVLETURL=null;
  private static String JSMEURL=null;
  private static String colorgray="#DDDDDD";	// pScore advisory color code
  private static String colorgreen="#88FF88";	// pScore advisory color code
  private static String coloryellow="#F0FF00";	// pScore advisory color code
  private static String colorred="#FF8888";	// pScore advisory color code
  private static String SCORE_RANGE_KEY="";
  private static String PROXY_PREFIX=null;	// configured in web.xml

  /////////////////////////////////////////////////////////////////////////////
  public void doPost(HttpServletRequest request,HttpServletResponse response)
      throws IOException,ServletException
  {
    SERVERNAME=request.getServerName();
    if (SERVERNAME.equals("localhost")) SERVERNAME = InetAddress.getLocalHost().getHostAddress();
    REMOTEHOST = request.getHeader("X-Forwarded-For"); // client (original)
    if (REMOTEHOST!=null)
    {
      String[] addrs = Pattern.compile(",").split(REMOTEHOST);
      if (addrs.length>0) REMOTEHOST = addrs[addrs.length-1];
    }
    else
    {
      REMOTEHOST = request.getRemoteAddr(); // client (may be proxy)
    }
    RESOURCEBUNDLE = ResourceBundle.getBundle("LocalStrings",request.getLocale());
    MultipartRequest mrequest=null;
    if (request.getMethod().equalsIgnoreCase("POST"))
    {
      try { mrequest = new MultipartRequest(request,UPLOADDIR,MAX_POST_SIZE,"ISO-8859-1",new DefaultFileRenamePolicy()); }
      catch (IOException lEx) { this.getServletContext().log("not a valid MultipartRequest",lEx); }
    }

    // main logic:
    ArrayList<String> cssincludes = new ArrayList<String>(Arrays.asList(((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/css/biocomp.css"));
    ArrayList<String> jsincludes = new ArrayList<String>(Arrays.asList(((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/js/biocomp.js", ((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/js/ddtip.js"));

    if (mrequest!=null)		//method=POST, normal operation
    {
      boolean ok = initialize(request, mrequest, response);
      if (!ok)
      {
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        out.println(HtmUtils.HeaderHtm(APPNAME, jsincludes, cssincludes, JavaScript(), "", color1, request));
        out.println(FormHtm(response));
        ClearFrame(out, "outframe");
        ClearFrame(out, "msgframe");
        PrintFrame(out, "msgframe", errors);
        closeDoc(out, "topframe");
        closeDoc(out, "outframe");
        closeDoc(out, "msgframe");
        out.println("</BODY></HTML>");
      }
      else if (params.isChecked("gobad"))
      {
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        out.println(HtmUtils.HeaderHtm(APPNAME, jsincludes, cssincludes, JavaScript(), "", color1, request));
        out.println(FormHtm(response));
        ClearFrame(out, "outframe");
        ClearFrame(out, "msgframe");
        Integer n_mol=0;
        Integer n_scaf=0;
        long t0 = System.currentTimeMillis();
        n_mol = GoBadapple_Multi(molsDB, response);
        if (n_mol>0) outputs.add(SCORE_RANGE_KEY);
        long t = System.currentTimeMillis()-t0;
        errors.add("elapsed query time: "+String.format("%.2f", (float)t/1000.0f)+"s");
        PrintFrame(out, "outframe", outputs);
        PrintFrame(out, "msgframe", errors);
        closeDoc(out, "topframe");
        closeDoc(out, "outframe");
        closeDoc(out, "msgframe");
        out.println("</BODY></HTML>");
        HtmUtils.PurgeScratchDirs(Arrays.asList(SCRATCHDIR), scratch_retire_sec, params.isChecked("verbose"), ".", (HttpServlet) this);
      }
    }
    else
    {
      String downloadtxt = request.getParameter("downloadtxt"); // POST param
      String downloadfile = request.getParameter("downloadfile"); // POST param
      if (request.getParameter("help")!=null)	// GET method
      {
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        out.println(HtmUtils.HeaderHtm(APPNAME, jsincludes, cssincludes, JavaScript(), "", color2, request));
        out.println(HelpHtm());
        out.println("<HR></BODY></HTML>");
      }
      else if (request.getParameter("test")!=null)	// GET method
      {
        response.setContentType("text/plain");
        PrintWriter out = response.getWriter();
        HashMap<String,String> t = new HashMap<String,String>();
        t.put("JCHEM_LICENSE_OK", (LicenseManager.isLicensed(LicenseManager.JCHEM)?"True":"False"));
        out.print(HtmUtils.TestTxt(APPNAME, t));
      }
      else if (downloadtxt!=null && downloadtxt.length()>0) // POST param
      {
        ServletOutputStream ostream = response.getOutputStream();
        HtmUtils.DownloadString(response, ostream, downloadtxt, request.getParameter("fname"));
      }
      else if (downloadfile!=null && downloadfile.length()>0) // POST param
      {
        ServletOutputStream ostream = response.getOutputStream();
        HtmUtils.DownloadFile(response, ostream, downloadfile,
          request.getParameter("fname"));
      }
      else if (request.getParameter("topframe")!=null)
      // GET method , initial invocation of topframe w/ no params
      {
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        out.println(HtmUtils.HeaderHtm(APPNAME, jsincludes, cssincludes, JavaScript(), "", color1, request));
        out.println(TopHtm(response));
        out.println("</BODY></HTML>");
      }
      else if (request.getParameter("formframe")!=null)
      // GET method , initial invocation of formframe w/ no params
      {
        boolean ok = initialize(request, mrequest, response);
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        out.println(HtmUtils.HeaderHtm(APPNAME, jsincludes, cssincludes, JavaScript(), "", color1, request));
        out.println(FormHtm(response));
        ClearFrame(out, "outframe");
        PrintFrame(out, "outframe", "<H1 ALIGN=\"center\">"+DBNAME.replaceFirst("^.*/", "")+(DBTYPE.equalsIgnoreCase("postgres")?(":"+DBSCHEMA):"")+"</H1>");
        ClearFrame(out, "msgframe");
        PrintFrame(out, "msgframe", errors);
        PrintFrame(out, "outframe", "server: "+DBHOST);
        PrintFrame(out, "outframe", "dbname: "+DBNAME);
        PrintFrame(out, "outframe", "schema: "+DBSCHEMA);
        try {
          PrintFrame(out, "outframe", "<PRE>"+badapple_utils.DBDescribeTxt(DBCON, DBSCHEMA)+"</PRE>");

          if (CHEMKIT.equalsIgnoreCase("rdkit"))
            PrintFrame(out, "outframe", "<PRE>RDKit_EXTENSION_VERSION: "+badapple_utils.RDKit_Version(DBCON)+"</PRE>");
        }
        catch (Exception e)
        { PrintFrame(out, "outframe", "DB error: <PRE>"+e.getMessage()+"</PRE>"); }
        try {
          HashMap<String, Integer> medians = badapple_utils.GetMedians(DBCON, DBSCHEMA);
          PrintFrame(out, "msgframe", "<PRE>"
            +"median_cTested="+medians.get("median_cTested")+"\n"
            +"median_sTested="+medians.get("median_sTested")+"\n"
            +"median_aTested="+medians.get("median_aTested")+"\n"
            +"median_wTested="+medians.get("median_wTested")
            +"</PRE>");
        }
        catch (Exception e)
        { PrintFrame(out, "outframe", "DB error (GetMedians): <PRE>"+e.getMessage()+"</PRE>"); }

        //try { DBCON.close(); }
        //catch (SQLException e)
        //{ PrintFrame(out, "outframe", "SQLException: <PRE>"+e.getMessage()+"</PRE>"); }

        PrintFrame(out, "outframe", SCORE_RANGE_KEY);

        String logo_htm = "<TABLE CELLSPACING=5 CELLPADDING=5><TR><TD>";
        String imghtm = ("<IMG BORDER=\"0\" SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/biocomp_logo_only.gif\">");
        String tiphtm=(APPNAME+" web app from UNM Translational Informatics.");
        String href = ("http://datascience.unm.edu/");
        logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white"));
        logo_htm+="</TD><TD>";

        imghtm = ("<IMG BORDER=0 SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/chemaxon_powered_100px.png\">");
        tiphtm = ("JChem from ChemAxon Ltd.");
        href = ("https://www.chemaxon.com");
        logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white"));
        logo_htm+="</TD><TD>";

        imghtm = ("<IMG BORDER=0 HEIGHT=60 SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/rdkit_logo.png\">");
        tiphtm = ("RDKit");
        href = ("http://www.rdkit.org");
        logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white", "parent.formframe"));

        imghtm = ("<IMG BORDER=0 HEIGHT=\"40\" SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/JSME_logo.png\">");
        tiphtm = ("JSME Molecular Editor");
        href = ("http://peter-ertl.com/jsme/");
        logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white", "parent.formframe"));

        logo_htm+="</TD></TR></TABLE>";

        PrintFrame(out, "outframe", logo_htm);

        closeDoc(out, "topframe");
        closeDoc(out, "outframe");
        closeDoc(out, "msgframe");
        out.println("<SCRIPT>go_reset(window.document.mainform)</SCRIPT>");
        out.println("</BODY></HTML>");
      }
      else	// GET method,  initial invocation of servlet w/ no params
      {
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        out.println(framesHtm(response)); // no body in frameset.
      }
      //if (DBCON!=null) { try { DBCON.close(); } catch (SQLException e) {} }
    }
  }
  /////////////////////////////////////////////////////////////////////////////
  private static void PrintFrame(PrintWriter out, String fname, String str)
  {
    PrintFrame(out, fname, new ArrayList<String>(Arrays.asList(str)));
  }
  private static void PrintFrame(PrintWriter out, String fname, ArrayList<String> strs)
  {
    for (int i=0;i<strs.size();++i)
    {
      strs.set(i, strs.get(i).replace("\"", "\\\""));
      strs.set(i, strs.get(i).replace("\n", "\\n"));
      strs.set(i, strs.get(i).replace("\r", "\\n"));
    }
    out.println("<SCRIPT>");
    out.println("var frame="+fname+";");
    out.print("frame.document.writeln(");
    for (int i=0;i<strs.size();++i)
    {
      out.print("\""+strs.get(i)+"<BR>\"");
      if (i<strs.size()-1) out.print(", \n");
    }
    out.println(");");
    if (fname.equals("msgframe"))
      out.println("frame.scrollTo(0, 9999);\n</SCRIPT>");
    else if (fname.equals("outframe"))
      out.println("frame.scrollTo(0, 0);\n</SCRIPT>");
  }
  /////////////////////////////////////////////////////////////////////////////
  private static void ClearFrame(PrintWriter out, String fname)
  {
    out.println("<SCRIPT>");
    out.println("var frame="+fname+";");
    out.println("frame.document.close();");
    out.println("frame.document.open();");
    out.println("</SCRIPT>");
    out.println("<SCRIPT>");
    out.println("var frame="+fname+";");
    out.println("frame.document.writeln(\"<HTML><HEAD><STYLE TYPE=\\\"text/css\\\"> html, button, td, p, select, input { font-family: Arial, Helvetica, 'sans serif'; font-size: 12px; color: #000066; }</STYLE></HEAD><BODY BGCOLOR=\\\""+color2+"\\\">\");");
    out.println("</SCRIPT>");
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Close doc in named frame ("outframe"|"msgframe").
  */
  private void closeDoc(PrintWriter out, String fname)
  {
    out.println("<SCRIPT>");
    out.println("var frame=parent."+fname+";");
    out.println("frame.document.close();");
    out.println("</SCRIPT>");
  }
  /////////////////////////////////////////////////////////////////////////////
  private boolean initialize(HttpServletRequest request, MultipartRequest mrequest, HttpServletResponse response)
      throws IOException, ServletException
  {
    SERVLETNAME = this.getServletName();
    outputs = new ArrayList<String>();
    errors = new ArrayList<String>();
    params = new HttpParams();

    String logo_htm = "<TABLE CELLSPACING=5 CELLPADDING=5><TR><TD>";
    String imghtm = ("<IMG BORDER=0 SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/biocomp_logo_only.gif\">");

    String tiphtm = (APPNAME+" web app from UNM Translational Informatics.");
    String href = ("http://medicine.unm.edu/informatics/");
    logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white", "parent.formframe"));
    logo_htm+="</TD><TD>";

    imghtm = ("<IMG BORDER=0 HEIGHT=60 SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/rdkit_logo.png\">");
    tiphtm = ("RDKit");
    href = ("http://www.rdkit.org");
    logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white", "parent.formframe"));
    logo_htm+="</TD><TD>";
    imghtm = ("<IMG BORDER=0 SRC=\""+((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/images/chemaxon_powered_100px.png\">");
    tiphtm = ("JChem and Marvin from ChemAxon Ltd.");
    href = ("http://www.chemaxon.com");
    logo_htm+=(HtmUtils.HtmTipper(imghtm, tiphtm, href, 200, "white", "parent.formframe"));
    logo_htm+="</TD></TR></TABLE>";

    errors.add(logo_htm);

    Calendar calendar = Calendar.getInstance();
    calendar.setTime(new java.util.Date());
    DATESTR = String.format("%04d%02d%02d%02d%02d%02d", calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH)+1, calendar.get(Calendar.DAY_OF_MONTH), calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), calendar.get(Calendar.SECOND));
    Random rand = new Random();
    PREFIX = SERVLETNAME+"."+DATESTR+"."+String.format("%03d", rand.nextInt(1000));

    try {
      LicenseManager.setLicenseFile(CONTEXT.getRealPath("")+"/.chemaxon/license.cxl");
    } catch (Exception e) {
      errors.add("ERROR: ChemAxon LicenseManager error: "+e.getMessage());
    }
    LicenseManager.refresh();

    MOL2IMG_SERVLETURL = (((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/mol2img");
    JSMEURL = (((PROXY_PREFIX!=null)?PROXY_PREFIX:"")+CONTEXTPATH+"/jsme_win.html");

    if (DBCON==null)
    {
      errors.add("ERROR: DB connection FAILED (dbtype="+DBTYPE+", "+DBUSR+"@"+DBHOST+").");
      return false;
    }

    if (mrequest==null) return true;

    /// Stuff for a run:

    for (Enumeration e=mrequest.getParameterNames(); e.hasMoreElements(); )
    {
      String key=(String)e.nextElement();
      if (mrequest.getParameter(key)!=null)
        params.setVal(key, mrequest.getParameter(key));
    }

    if (params.getVal("depsize").equals("xs"))      depsz=60;
    else if (params.getVal("depsize").equals("s"))  depsz=90;
    else if (params.getVal("depsize").equals("m"))  depsz=120;
    else if (params.getVal("depsize").equals("l"))  depsz=180;
    else if (params.getVal("depsize").equals("xl")) depsz=240;
    else depsz=90;

    if (params.isChecked("verbose"))
    {
      errors.add("DB connection ok ("+DBUSR+"@"+DBHOST+", dbtype="+DBTYPE+", dbname="+DBNAME+", dbschema="+DBSCHEMA+")");
      errors.add("JChem version: "+com.chemaxon.version.VersionInfo.getVersion());
      errors.add("Tomcat: "+CONTEXT.getServerInfo());
    }

    String fname="infileDB";
    File fileDB = mrequest.getFile(fname);
    String intxt = params.getVal("intxt");
    intxt = intxt.replaceFirst("[\\s]+$", "");
    intxt = intxt.replaceFirst("^([\n\r]+)", "untitled$1");
    String line = null;
    if (fileDB!=null)
    {
      if (params.isChecked("file2txtDB") && fileDB!=null)
      {
        BufferedReader br = new BufferedReader(new FileReader(fileDB));
        intxt="";
        for (int i=0;(line=br.readLine())!=null;++i)
        {
          intxt+=(line+"\n");
          if (i==5000)
          {
            errors.add("ERROR: max lines copied to input: "+5000);
            break;
          }
        }
        params.setVal("intxt", intxt);
      }
      else
      {
        params.setVal("intxt", "");
      }
    }
    molsDB = new ArrayList<Molecule>();
    MolImporter molReaderDB=null;
    if (params.getVal("molfmtDB").equals("automatic"))
    {
      String ifmt_auto = MFileFormatUtil.getMostLikelyMolFormat(mrequest.getOriginalFileName(fname));
      if (ifmt_auto!=null)
      {
        if (fileDB!=null)
          molReaderDB = new MolImporter(fileDB, ifmt_auto);
        else if (intxt.length()>0)
          molReaderDB = new MolImporter(new ByteArrayInputStream(intxt.getBytes()), ifmt_auto);
      }
      else
      {
        if (fileDB!=null)
          molReaderDB = new MolImporter(new FileInputStream(fileDB));
        else if (intxt.length()>0)
          molReaderDB = new MolImporter(new ByteArrayInputStream(intxt.getBytes()));
      }
    }
    else
    {
      molReaderDB = new MolImporter(new FileInputStream(fileDB), params.getVal("molfmtDB"));
    }
    if (params.isChecked("verbose"))
      errors.add("input DB format:  "+molReaderDB.getFormat()+" ("+MFileFormatUtil.getFormat(molReaderDB.getFormat()).getDescription()+")");
    Molecule m;
    int n_failed=0;
    while (true)
    {
      try {
        m = molReaderDB.read();
      }
      catch (MolFormatException e)
      {
        ++n_failed;
        errors.add("ERROR: ["+n_failed+"]: "+e.getMessage());
        continue;
      }
      if (m==null) break;
  
      m.aromatize(MoleculeGraph.AROM_GENERAL);
      molsDB.add(m);
      if (molsDB.size()==N_MAX)
      {
        errors.add("Warning: mol list truncated at N_MAX mols: "+N_MAX);
        break;
      }
      //if (params.getVal("runmode").equals("single")) break; //Only one mol needed.
    }
    molReaderDB.close();
    if (params.isChecked("verbose"))
    {
      errors.add("DB mols read:  "+molsDB.size());
    }
    //if (fileDB!=null) fileDB.delete();

    return true;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Note: cannot be static method; must use this.getServletName().
  */
  private String framesHtm(HttpServletResponse response)
  {
    return (
    ("<HEAD><TITLE>"+APPNAME+"</TITLE>\n")
    +("<SCRIPT>\n")
    +("if (top!=self) top.location=location; // Don't get framed!\n")
    +("</SCRIPT>\n")
    +("</HEAD>\n")
    +("<FRAMESET ROWS=\"50,*\" FRAMEBORDER=\"yes\">\n")
    +("  <FRAME NAME=\"topframe\" SRC=\""+response.encodeURL(this.getServletName()+"?topframe=true")+"\" MARGINWIDTH=5 MARGINHEIGHT=5 SCROLLING=AUTO>\n")
    +("  <FRAMESET COLS=\"300,*\" FRAMEBORDER=\"yes\">\n")
    +("    <FRAME NAME=\"formframe\" SRC=\""+response.encodeURL(this.getServletName()+"?formframe=true")+"\" MARGINWIDTH=5 MARGINHEIGHT=5 SCROLLING=AUTO>\n")
    +("    <FRAMESET ROWS=\"*,100\" FRAMEBORDER=\"yes\">\n")
    +("      <FRAME NAME=\"outframe\" SRC=\"javascript:''\" MARGINWIDTH=5 MARGINHEIGHT=5 SCROLLING=YES>\n")
    +("      <FRAME NAME=\"msgframe\" SRC=\"javascript:''\" MARGINWIDTH=0 MARGINHEIGHT=0 SCROLLING=AUTO>\n")
    +("    </FRAMESET>\n")
    +("  </FRAMESET>\n")
    +("  <NOFRAMES>Sorry, "+this.getServletName()+" requires frames.</NOFRAMES>\n")
    +("</FRAMESET>\n")
    );
  }
  /////////////////////////////////////////////////////////////////////////////
  private static String TopHtm(HttpServletResponse response)
      throws ServletException
  {
    return (
    ("<TABLE WIDTH=\"100%\" CELLSPACING=\"0\" CELLPADDING=\"0\"><TR>\n")
    +("<TD WIDTH=\"20%\" VALIGN=\"top\"><DIV STYLE=\"font-family: Arial, Helvetica, 'sans serif'; font-size: 24px; font-weight: bold\">"+APPNAME+"</DIV></TD>\n")
    +("<TD WIIDTH=\"50%\" VALIGN=\"top\">- Bioactivity data associative promiscuity pattern learning engine\n")
    +"<TD ALIGN=\"right\" VALIGN=\"top\">\n"
    +("<BUTTON TYPE=BUTTON onClick=\"void window.open('"+response.encodeURL(SERVLETNAME)+"?help=TRUE', 'helpwin', 'width=700, height=400, scrollbars=1, resizable=1')\"><B>Help</B></BUTTON>\n")
    +("<BUTTON TYPE=BUTTON onClick=\"parent.formframe.go_demo(parent.formframe.mainform)\"><B>Demo</B></BUTTON>\n")
    +("<BUTTON TYPE=BUTTON onClick=\"parent.location.replace('"+response.encodeURL(SERVLETNAME)+"')\"><B>Reset</B></BUTTON>\n")
    +"</TD></TR></TABLE>\n"
    );
  }
  /////////////////////////////////////////////////////////////////////////////
  private static String FormHtm(HttpServletResponse response)
      throws IOException, ServletException
  {
    String deptype_scaf=""; String deptype_mol=""; String deptype_none="";
    if (params.getVal("deptype").equals("scaf")) deptype_scaf="CHECKED";
    else if (params.getVal("deptype").equals("mol")) deptype_mol="CHECKED";
    else if (params.getVal("deptype").equals("none")) deptype_none="CHECKED";

    //String sortby_size=""; String sortby_id=""; String sortby_score="";
    //if (params.getVal("sortby").equals("size")) sortby_size="CHECKED";
    //else if (params.getVal("sortby").equals("id")) sortby_id="CHECKED";
    //else if (params.getVal("sortby").equals("score")) sortby_score="CHECKED";

    String depsize_menu="<SELECT NAME=\"depsize\">";
    depsize_menu+=("<OPTION VALUE=\"xs\">XS");
    depsize_menu+=("<OPTION VALUE=\"s\">S");
    depsize_menu+=("<OPTION VALUE=\"m\">M");
    depsize_menu+=("<OPTION VALUE=\"l\">L");
    depsize_menu+=("<OPTION VALUE=\"xl\">XL");
    depsize_menu+="</SELECT>\n";
    depsize_menu = depsize_menu.replace("\""+params.getVal("depsize")+"\">", "\""+params.getVal("depsize")+"\" SELECTED>");

    //String runmode_single=""; String runmode_multi="";
    //if (params.getVal("runmode").equals("single")) runmode_single="CHECKED";
    //else if (params.getVal("runmode").equals("multi")) runmode_multi="CHECKED";
    //else runmode_single="CHECKED";

    String molfmt_menuDB = "<SELECT NAME=\"molfmtDB\">\n";
    molfmt_menuDB+=("<OPTION VALUE=\"automatic\">automatic\n");
    for (String fmt: MFileFormatUtil.getMolfileFormats())
    {
      String desc = MFileFormatUtil.getFormat(fmt).getDescription();
      molfmt_menuDB+=("<OPTION VALUE=\""+fmt+"\">"+desc+"\n");
    }
    molfmt_menuDB+="</SELECT>\n";

    int H_MVIEW=220;
    int W_MVIEW=280;
    String htm=(
    "<FORM NAME=\"mainform\" METHOD=POST\n"+
    " ACTION=\""+response.encodeURL(SERVLETNAME)+"\"\n"+
    " ENCTYPE=\"multipart/form-data\">\n"+
    "<INPUT TYPE=HIDDEN NAME=\"gobad\">\n"+
    "<INPUT TYPE=HIDDEN NAME=\"qsmi\"\">\n");
    //"<B>mode:</B>\n"+
    //"<INPUT TYPE=RADIO NAME=\"runmode\" VALUE=\"single\" "+runmode_single+">single (1st)\n"+
    //"<INPUT TYPE=RADIO NAME=\"runmode\" VALUE=\"multi\" "+runmode_multi+">multi\n"+
    //"<HR>\n"

    htm+=(
      "<B>input mol[s]:</B> format:\n"+
      molfmt_menuDB+"<BR>\n"+
      "upload: <INPUT TYPE=\"FILE\" NAME=\"infileDB\"> ...or paste:\n"+
      "&nbsp; &nbsp; &nbsp;"+
      "<INPUT TYPE=CHECKBOX NAME=\"file2txtDB\" VALUE=\"CHECKED\"\n"+
      " "+params.getVal("file2txtDB")+">file2txt<BR>\n"+
      "<TEXTAREA NAME=\"intxt\" WRAP=OFF ROWS=8 COLS=40>"+params.getVal("intxt")+"</TEXTAREA>\n");

    htm+=("or <BUTTON TYPE=\"BUTTON\" onClick=\"StartJSME()\">JSME</BUTTON>\n");

    htm+=(
    "<HR>\n"+
    "<B>output:</B><BR>\n");
      htm+=(
      "<TABLE WIDTH=100%><TR>\n"+
      "<TD VALIGN=TOP>\n"+
      "depict: "+
      //"&nbsp;&nbsp;<INPUT TYPE=\"RADIO\" NAME=\"deptype\" VALUE=\"mol\" "+deptype_mol+">mol\n"+
      //"&nbsp;&nbsp;<INPUT TYPE=\"RADIO\" NAME=\"deptype\" VALUE=\"scaf\" "+deptype_scaf+">scaf\n"+
      //"&nbsp;&nbsp;<INPUT TYPE=\"RADIO\" NAME=\"deptype\" VALUE=\"none\" "+deptype_none+">none\n"+
      "&nbsp;&nbsp;"+depsize_menu+
      //"<BR>\n"+
      //"sort scaffolds by: "+
      //"&nbsp;&nbsp;<INPUT TYPE=\"RADIO\" NAME=\"sortby\" VALUE=\"size\" "+sortby_size+">size\n"+
      //"&nbsp;&nbsp;<INPUT TYPE=\"RADIO\" NAME=\"sortby\" VALUE=\"id\" "+sortby_id+">id\n"+
      //"&nbsp;&nbsp;<INPUT TYPE=\"RADIO\" NAME=\"sortby\" VALUE=\"score\" "+sortby_score+">score\n"+
      "<BR>\n");
    htm+=(
    //"<INPUT TYPE=CHECKBOX NAME=\"nondrugonly\" VALUE=\"CHECKED\" "+params.getVal("nondrugonly")+">non-drug scaffolds only<BR>\n"+
    "<INPUT TYPE=CHECKBOX NAME=\"verbose\" VALUE=\"CHECKED\" "+params.getVal("verbose")+">verbose<BR>\n"+
    "</TD></TR></TABLE>\n"+
    "<HR>\n"+
    "<CENTER>\n"+
    //"<BUTTON TYPE=BUTTON onClick=\"go_demo(this.form)\"><B>Demo</B></BUTTON>\n"+
    "<BUTTON TYPE=BUTTON onClick=\"go_bad(this.form)\"><B>Go "+APPNAME+"</B></BUTTON>\n"+
    "</CENTER>\n"+
    "</FORM>\n");
    return htm;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Analyze one molecule; generate a detailed table for interactive viewing.
	One row per scaffold.
  */
  private static Integer GoBadapple_Single(Molecule mol)
  {
    int n_rows=0;
    ArrayList<ScaffoldScore> scores=null;
    try { scores = badapple_utils.GetScaffoldScores(DBCON, DBSCHEMA, CHEMKIT, mol, params.isChecked("verbose")?0:2); }
    catch (Exception e) { errors.add("Exception (GetScaffoldScores): "+e.getMessage()); }
    if (scores==null) return n_rows;
    try { n_rows = Scores2Output_Single(mol, scores); }
    catch (Exception e) { errors.add("Exception (Scores2Output_Single): "+e.getMessage()); }
    return n_rows;
  }
  /////////////////////////////////////////////////////////////////////////////
  private static Integer RemoveDrugScores(ArrayList<ScaffoldScore> scores)
  {
    if (scores==null) return 0;
    int n_removed=0;
    for (int i=scores.size()-1;i>=0;--i)
    {
      ScaffoldScore score = scores.get(i);
      if (score.getInDrug())
      {
        scores.remove(i);
        ++n_removed;
      }
    }
    return n_removed;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Output detailed data table for one molecule.
  */
  private static Integer Scores2Output_Single(Molecule qmol, ArrayList<ScaffoldScore> scores)
      throws SQLException, IOException
  {
    String qsmiles=null;
    try { qsmiles=MolExporter.exportToFormat(qmol, "smiles:u,+a_gen"); } /// Aromatize so matching/highlighting works.
    catch (IOException e) { qsmiles=params.getVal("smiles"); }
    if (params.isChecked("verbose"))
      errors.add("query: "+qsmiles);

    //if (params.isChecked("nondrugonly"))
    //  RemoveDrugScores(scores);

    String thtm=("<TABLE BORDER>\n");
    String rhtm=("");

    rhtm=("<TH>scaffold</TH><TH>pScore</TH><TH>InDrug</TH><TH>advisory</TH>");
    if (params.isChecked("verbose")) rhtm+=("<TH>details</TH>");
    thtm+=("<TR>"+rhtm+"</TR>\n");
    //if (params.getVal("sortby").equals("score"))
      Collections.sort(scores);
    //else if (params.getVal("sortby").equals("id"))
    //  Collections.sort(scores, new ScaffoldScore_CmpID());
    //else if (params.getVal("sortby").equals("size"))
    //  Collections.sort(scores, new ScaffoldScore_CmpSize());

    int n_scaf=0;
    for (ScaffoldScore score: scores)
    {
      ++n_scaf;
      String scafsmi = score.getSmiles();
      Molecule mol_scaf = MolImporter.importMol(scafsmi, "smiles:");
      if (params.isChecked("verbose")) errors.add("scaffold: ["+score.getID()+"] "+scafsmi);
      String imghtm="";
      if (params.getVal("deptype").equals("scaf"))
      {
        imghtm = HtmUtils.Smi2ImgHtm(scafsmi, "&clearqprops=true",
		depsz, (int)Math.floor(1.25f*depsz),
		MOL2IMG_SERVLETURL, true, 4, "parent.formframe.go_zoom_smi2img");
      }
      else
      {
        // Depict smiles; highlight using scafsmi as smarts.  smilesmatch option allows "[nH]" to match.
        imghtm = HtmUtils.Smi2ImgHtm(qsmiles, "&smilesmatch=true&smarts="+URLEncoder.encode(scafsmi, "UTF-8"),
		depsz, (int)Math.floor(1.25f*depsz),
		MOL2IMG_SERVLETURL, true, 4, "parent.formframe.go_zoom_smi2img");
      }
      Float pscore = score.getScore();
      String bgcolor;
      String advisory;
      if (pscore==null || !score.getKnown())
      {
        advisory="None";
        bgcolor=colorgray;
      }
      else if (pscore>PSCORE_CUTOFF_HIGH)
      {
        advisory="High pScore.";
        bgcolor=colorred;
      }
      else if (pscore>PSCORE_CUTOFF_MODERATE)
      {
        advisory="Moderate pScore.";
        bgcolor=coloryellow;
      }
      else
      {
        advisory="Low pScore.";
        bgcolor=colorgreen;
      }
      rhtm=("<TR BGCOLOR=\""+bgcolor+"\">\n");
      rhtm+=("<TD ALIGN=\"center\">"+imghtm+"</TD>\n");
      rhtm+=("<TD ALIGN=\"center\">"+((pscore==null)?"~":pscore.intValue())+"</TD>\n");

      rhtm+=("<TD ALIGN=\"center\">"+(score.getInDrug()?"TRUE":"FALSE")+"</TD>\n");
      rhtm+=("<TD ALIGN=\"center\">"+advisory+"</TD>\n");
      if (params.isChecked("verbose"))
      {
        errors.add("scaffold known: "+(score.getKnown()?("yes, ID="+score.getID()):"no"));
        String detailtxt = ("scaffold ID: "+(score.getKnown()?(""+score.getID()):"NA")+"\n");
        if (score.getKnown())
        {
          errors.add("scaffold ["+score.getID()+"] sTested: "+score.getSubTested());
          errors.add("scaffold ["+score.getID()+"] sActive: "+score.getSubActive());
          errors.add("scaffold ["+score.getID()+"] aTested: "+score.getAsyTested());
          errors.add("scaffold ["+score.getID()+"] aActive: "+score.getAsyActive());
          errors.add("scaffold ["+score.getID()+"] wTested: "+score.getSamTested());
          errors.add("scaffold ["+score.getID()+"] wActive: "+score.getSamActive());
          errors.add("scaffold ["+score.getID()+"] inDrug: "+score.getInDrug());

          detailtxt+=("substances Tested: "+score.getSubTested()+"\n");
          detailtxt+=("substances Active: "+score.getSubActive()+"\n");
          detailtxt+=("assays Tested: "+score.getAsyTested()+"\n");
          detailtxt+=("assays Active: "+score.getAsyActive()+"\n");
          detailtxt+=("samples Tested: "+score.getSamTested()+"\n");
          detailtxt+=("samples Active: "+score.getSamActive()+"\n");
        }
        rhtm+=("<TD ALIGN=\"center\"><PRE>"+detailtxt+"</PRE></TD>\n");
      }
      rhtm+=("</TR>");
      thtm+=(rhtm+"\n");
    }
    thtm+=("</TABLE>\n");
    outputs.add("<H3>Badapple Promiscuity Analysis Output:</H3>");
    //if (params.isChecked("nondrugonly"))
    //  outputs.add("<B>Non-drug-scaffold-only mode.</B>");
    if (n_scaf>0)
    {
      outputs.add("scaffold count: "+n_scaf);
      outputs.add(thtm);
    }
    else
    {
      outputs.add("<P><B>No known scaffolds recognized.  No pScore and no advisory available.</B></P>");
    }
    return n_scaf;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Analyze a dataset of molecules; generate a table for interactive viewing
	and provide data as downloadable CSV.
	One row per input molecule.
  */
  private static Integer GoBadapple_Multi(List<Molecule> mols, HttpServletResponse response)
	throws MolExportException
  {
    int n_mol=0;
    ArrayList<ArrayList<ScaffoldScore> >scoreses = new ArrayList<ArrayList<ScaffoldScore> >();
    for (Molecule mol: mols)
    {
      try {
        ArrayList<ScaffoldScore> scores = badapple_utils.GetScaffoldScores(DBCON, DBSCHEMA, CHEMKIT, mol, 0);
        scoreses.add(scores);
      }
      catch (Exception e) { errors.add("Exception: "+e.getMessage()); }
    }
    try { n_mol+=Scores2Output_Multi(mols, scoreses, response); }
    catch (Exception e) { errors.add("IOException: "+e.getMessage()); }

    //errors.add("DEBUG: GoBadapple_Multi mols in: "+mols.size()+" ; out: "+n_mol);
    return n_mol;
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Output data table for multiple mols.
	<br/>
	pScore_mol = pScores for highest scoring scaffold<br/>
	pScore_mol_nd = pScore for highest scoring scaffold not in any drug<br/>
	Advisory based on highest scoring scaffold. <br/>
  */
  private static Integer Scores2Output_Multi(List<Molecule> mols, ArrayList<ArrayList<ScaffoldScore> > scoreses, HttpServletResponse response)
      throws SQLException, IOException
  {
    //errors.add("DEBUG: SCRATCHDIR: "+SCRATCHDIR);
    File dout = new File(SCRATCHDIR);
    if (!dout.exists())
    {
      boolean ok = dout.mkdir();
      System.err.println("SCRATCHDIR creation "+(ok?"succeeded":"failed")+": "+SCRATCHDIR);
    }
    File fout = File.createTempFile(PREFIX, "_out.txt", dout);
    PrintWriter fout_writer = new PrintWriter(new BufferedWriter(new FileWriter(fout, true)));
    fout_writer.printf("mol_i, mol_smi, mol_name, scaf_smi, pScore, in_drug, advisory, substancesTested, substancesActive, assaysTested, assaysActive, samplesTested, samplesActive\n");
    String thtm="<TABLE BORDER>\n";
    thtm+=("<TR><TH></TH><TH>molecule</TH><TH>scaffold</TH><TH>pScore</TH><TH>InDrug</TH><TH>advisory</TH><TH>details</TH></TR>\n");
    int i_mol=0;
    for (List<ScaffoldScore> scores: scoreses)
    {
      ++i_mol;
      Molecule mol = mols.get(i_mol-1);
      Float pscore_mol=0.0f;
      Float pscore_mol_nd=0.0f;
      int n_removed=0;
      boolean isKnown=false;
      boolean inDrug=false;

      String qsmiles=null;
      try { qsmiles = MolExporter.exportToFormat(mol, "smiles:u,+a_gen"); } /// Aromatize so matching/highlighting works.
      catch (IOException e) { qsmiles=params.getVal("smiles"); }
      if (params.isChecked("verbose"))
        errors.add("query: "+qsmiles);

      //String scafsmi=null;

      //if (params.isChecked("nondrugonly"))
      //  n_removed=RemoveDrugScores(scores);

      //if (params.isChecked("nondrugonly"))
      //{
      //  pscore_mol_nd=pscore_mol;
      //}
      //else
      //{
      for (ScaffoldScore score: scores)
      {
        if (!score.getInDrug())
        {
          pscore_mol_nd = score.getScore();
          break;
        }
      }
      //}

      if (scores!=null && scores.size()>0)
      {
        Collections.sort(scores); //sort by score

        //FIXING THIS TO INCLUDE ALL SCAFFOLDS IN OUTPUT.

        String bgcolor_mol;
        String advisory_mol;
        Float pscore_max = scores.get(0).getScore(); //only use highest scaf-score
        if (pscore_max==null || !scores.get(0).getKnown())
        {
          advisory_mol="None";
          bgcolor_mol=colorgray;
        }
        else if (pscore_max>PSCORE_CUTOFF_HIGH)
        {
          advisory_mol="High pScore.";
          bgcolor_mol=colorred;
        }
        else if (pscore_max>PSCORE_CUTOFF_MODERATE)
        {
          advisory_mol="Moderate pScore.";
          bgcolor_mol=coloryellow;
        }
        else
        {
          advisory_mol="Low pScore.";
          bgcolor_mol=colorgreen;
        }

        int n_scaf=scores.size();
        int i_scaf=0;
        for (ScaffoldScore score: scores)
        {
          ++i_scaf;
          String scafsmi = score.getSmiles();
          Molecule mol_scaf = MolImporter.importMol(scafsmi, "smiles:");
          if (params.isChecked("verbose")) errors.add("scaffold: ["+score.getID()+"] "+scafsmi);

          // Depict qmol; highlight using scafsmi as smarts.  smilesmatch option allows "[nH]" to match.
          String imghtm_mol = HtmUtils.Smi2ImgHtm(qsmiles, "&smilesmatch=true&smarts="+URLEncoder.encode(scafsmi, "UTF-8"),
		    depsz, (int)Math.floor(1.25f*depsz),
		    MOL2IMG_SERVLETURL, true, 4, "parent.formframe.go_zoom_smi2img");

          String imghtm_scaf = HtmUtils.Smi2ImgHtm(scafsmi, "&clearqprops=true",
		    depsz, (int)Math.floor(1.25f*depsz),
		    MOL2IMG_SERVLETURL, true, 4, "parent.formframe.go_zoom_smi2img");
      
          Float pscore = score.getScore();
          String bgcolor_scaf;
          String advisory;
          if (pscore==null || !score.getKnown())
          {
            advisory="None";
            bgcolor_scaf=colorgray;
          }
          else if (pscore>PSCORE_CUTOFF_HIGH)
          {
            advisory="High pScore.";
            bgcolor_scaf=colorred;
          }
          else if (pscore>PSCORE_CUTOFF_MODERATE)
          {
            advisory="Moderate pScore.";
            bgcolor_scaf=coloryellow;
          }
          else
          {
            advisory="Low pScore.";
            bgcolor_scaf=colorgreen;
          }
          String rhtm=("<TR>\n");
          if (i_scaf==1) rhtm+=("<TD BGCOLOR=\""+bgcolor_mol+"\" ALIGN=\"right\" VALIGN=\"TOP\" ROWSPAN=\""+n_scaf+"\">"+i_mol+"</TD>\n");
          rhtm+=("<TD BGCOLOR=\""+bgcolor_mol+"\" ALIGN=\"center\">"+imghtm_mol+"</TD>\n");
          rhtm+=("<TD BGCOLOR=\""+bgcolor_scaf+"\" ALIGN=\"center\">"+imghtm_scaf+"</TD>\n");
          rhtm+=("<TD BGCOLOR=\""+bgcolor_scaf+"\" ALIGN=\"center\">"+((pscore==null)?"~":pscore.intValue())+"</TD>\n");

          rhtm+=("<TD BGCOLOR=\""+bgcolor_scaf+"\" ALIGN=\"center\">"+(score.getInDrug()?"TRUE":"FALSE")+"</TD>\n");
          rhtm+=("<TD BGCOLOR=\""+bgcolor_scaf+"\" ALIGN=\"center\">"+advisory+"</TD>\n");
          //if (params.isChecked("verbose"))
          //{
            errors.add("scaffold known: "+(score.getKnown()?("yes, ID="+score.getID()):"no"));
            String detailtxt = ("scaffold ID: "+(score.getKnown()?(""+score.getID()):"NA")+"\n");
            if (score.getKnown())
            {
              errors.add("scaffold ["+score.getID()+"] sTested: "+score.getSubTested());
              errors.add("scaffold ["+score.getID()+"] sActive: "+score.getSubActive());
              errors.add("scaffold ["+score.getID()+"] aTested: "+score.getAsyTested());
              errors.add("scaffold ["+score.getID()+"] aActive: "+score.getAsyActive());
              errors.add("scaffold ["+score.getID()+"] wTested: "+score.getSamTested());
              errors.add("scaffold ["+score.getID()+"] wActive: "+score.getSamActive());
              errors.add("scaffold ["+score.getID()+"] inDrug: "+score.getInDrug());

              detailtxt+=("substances Tested: "+score.getSubTested()+"\n");
              detailtxt+=("substances Active: "+score.getSubActive()+"\n");
              detailtxt+=("assays Tested: "+score.getAsyTested()+"\n");
              detailtxt+=("assays Active: "+score.getAsyActive()+"\n");
              detailtxt+=("samples Tested: "+score.getSamTested()+"\n");
              detailtxt+=("samples Active: "+score.getSamActive()+"\n");
            }
            rhtm+=("<TD BGCOLOR=\""+bgcolor_scaf+"\" ALIGN=\"center\"><PRE>"+detailtxt+"</PRE></TD>\n");
          //}
          rhtm+=("</TR>");
          thtm+=(rhtm+"\n");

          // Output CSV: 1 line per scaffold.
          fout_writer.printf(""+i_mol);
          fout_writer.printf(",\""+MolExporter.exportToFormat(mol, "smiles:")+"\"");
          fout_writer.printf(",\""+mol.getName()+"\"");
          fout_writer.printf(",\""+MolExporter.exportToFormat(mol_scaf, "smiles:")+"\"");
          fout_writer.printf(","+((pscore==null)?0:pscore.intValue()));
          fout_writer.printf(","+(score.getInDrug()));
          fout_writer.printf(",\""+advisory+"\"");
          fout_writer.printf(","+(score.getSubTested()));
          fout_writer.printf(","+(score.getSubActive()));
          fout_writer.printf(","+(score.getAsyTested()));
          fout_writer.printf(","+(score.getAsyActive()));
          fout_writer.printf(","+(score.getSamTested()));
          fout_writer.printf(","+(score.getSamActive()));
          fout_writer.printf("\n");
        }
      }


//      String bgcolor="";
//      String advisory="";
//      if (scores==null || scores.size()==0)
//      {
//        advisory= (n_removed==0)?"No scaffold!":"No non-drug scaffold.";
//        bgcolor=colorgray;
//      }
//      else if (!isKnown)
//      {
//        advisory="None";
//        bgcolor=colorgray;
//      }
//      else if (pscore_mol>=PSCORE_CUTOFF_HIGH)
//      {
//        advisory="High pScore";
//        bgcolor=colorred;
//      }
//      else if (pscore_mol>=PSCORE_CUTOFF_MODERATE)
//      {
//        advisory="Moderate pScore";
//        bgcolor=coloryellow;
//      }
//      else
//      {
//        advisory="Low pScore";
//        bgcolor=colorgreen;
//      }
//      fout_writer.printf("\""+MolExporter.exportToFormat(mol,"smiles:")+"\"");
//      fout_writer.printf(",\""+mol.getName()+"\"");
//      fout_writer.printf(","+((pscore_mol==null)?0:pscore_mol.intValue()));
//      fout_writer.printf(","+((pscore_mol_nd==null)?0:pscore_mol_nd.intValue()));
//      fout_writer.printf(",\""+advisory+"\"\n");
//
//      String rhtm=("<TR BGCOLOR=\""+bgcolor+"\">");
//      rhtm+=("<TD ALIGN=\"right\">"+i_mol+"</TD>\n");
//      rhtm+=("<TD ALIGN=\"center\">");
//      if (!params.getVal("deptype").equalsIgnoreCase("none"))
//      {
//        String imghtm;
//        if (scores==null || scores.size()==0 || scafsmi==null)
//        {
//          imghtm=HtmUtils.Smi2ImgHtm(MolExporter.exportToFormat(mol,"smiles:"),"",
//		depsz,(int)Math.floor(1.25f*depsz),
//		MOL2IMG_SERVLETURL,true,4,"parent.formframe.go_zoom_smi2img");
//        }
//        else
//        {
//          // smilesmatch option allows "[nH]" to match.
//          imghtm=HtmUtils.Smi2ImgHtm(MolExporter.exportToFormat(mol,"smiles:"),
//		"&smilesmatch=true&smarts="+URLEncoder.encode(scafsmi,"UTF-8"),
//		depsz,(int)Math.floor(1.25f*depsz),
//		MOL2IMG_SERVLETURL,true,4,"parent.formframe.go_zoom_smi2img");
//        }
//        rhtm+=(imghtm+"<BR>\n");
//      }
//      String molname=(mol.getName().length()<20?mol.getName():mol.getName().substring(0,19)+"...");
//      rhtm+=(molname+"</TD>\n");
//      rhtm+=("<TD ALIGN=\"center\">"+((pscore_mol==null)?0:pscore_mol.intValue())+"</TD>\n");
//      rhtm+=("<TD ALIGN=\"center\">"+(inDrug?"TRUE":"FALSE")+"</TD>\n");
//      rhtm+=("<TD ALIGN=\"center\">"+advisory+"</TD>\n");
//      rhtm+=("</TR>\n");
//      thtm+=rhtm;


    }
    thtm+=("</TABLE>\n");


    outputs.add("<H3>Badapple Promiscuity Analysis Output:</H3>");
    //if (params.isChecked("nondrugonly"))
    //  outputs.add("<B>Non-drug-scaffold-only mode.</B>");
    //outputs.add("mols in: "+scoreses.size());
    outputs.add("molecule count: "+i_mol);
    if (i_mol>0) outputs.add(thtm);
    outputs.add("For each molecule, highest scoring scaffold determines overall score.");
    fout_writer.close();
    String fname = (SERVLETNAME+"_out.csv");
    String bhtm = (
      "<FORM METHOD=\"POST\" ACTION=\""+response.encodeURL(SERVLETNAME)+"\">\n"+
      "<INPUT TYPE=HIDDEN NAME=\"downloadfile\" VALUE=\""+fout.getAbsolutePath()+"\">\n"+
      "<INPUT TYPE=HIDDEN NAME=\"fname\" VALUE=\""+fname+"\">\n"+
      "<BUTTON TYPE=BUTTON onClick=\"this.form.submit()\"><B>"+
      "Download "+fname+" ("+file_utils.NiceBytes(fout.length())+")</B></BUTTON>\n</FORM>");
    outputs.add(bhtm);
    return i_mol;
  }
  /////////////////////////////////////////////////////////////////////////////
  private static String JavaScript()
  {
    return (
"var topframe=top.frames[0];\n"+
"var formframe=top.frames[1];\n"+
"var outframe=top.frames[2];\n"+
"var msgframe=top.frames[3];\n"+
"var smiles='';\n"+
"\n"+
"function go_reset(form)\n"+
"{\n"+
"  var i;\n"+
//"  for (i=0;i<form.deptype.length;++i)\n"+
//"  { if (form.deptype[i].value=='mol') form.deptype[i].checked=true; }\n"+
//"  for (i=0;i<form.sortby.length;++i)\n"+
//"  { if (form.sortby[i].value=='score') form.sortby[i].checked=true; }\n"+
"  for (i=0;i<form.depsize.length;++i)\n"+
"  {\n"+
"    if (form.depsize.options[i].value=='s')\n"+
"      form.depsize.options[i].selected=true;\n"+
"  }\n"+
"  form.verbose.checked=false;\n"+
//"  form.nondrugonly.checked=false;\n"+
"  form.file2txtDB.checked=true;\n"+
"}\n"+
"function checkform(form)\n"+
"{\n"+
"  if (!form.intxt.value && !form.infileDB.value) {\n"+
"    alert('ERROR: No input specified.');\n"+
"    return false;\n"+
"  }\n"+
"  return true;\n"+
"}\n"+
"function go_bad(form)\n"+
"{\n"+
"  if (!checkform(form)) return;\n"+
"  form.gobad.value='TRUE';\n"+
"  form.submit();\n"+
"}\n"+
"function go_demo(form)\n"+
"{\n"+
"  go_reset(form);\n"+
"  form.intxt.value='CCCc1nc-2c(=O)n(c(=O)nc2n(n1)C)C\\n';\n"+
"  form.intxt.value+='c1ccc2c(c1)c(=O)n(s2)c3ccccc3C(=O)N4CCCC4\\n';\n"+
"  form.intxt.value+='Cc1cc(nc(n1)N=C(N)Nc2cccc(c2)N)C\\n';\n"+
"  form.intxt.value+='CCc1c(c2ccccc2o1)C(=O)c3cc(c(c(c3)Br)O)Br\\n';\n"+
"  form.intxt.value+='OC(=O)C1=C2CCCC(C=C3C=CC(=O)C=C3)=C2NC2=CC=CC=C12\\n';\n"+
"  form.intxt.value+='c1ccc2c(c1)C(=O)c3ccoc3C2=O\\n';\n"+
"  form.gobad.value='TRUE';\n"+
"  form.submit();\n"+
"}\n"+
"/// JSME stuff:\n"+
"function StartJSME()\n"+
"{\n"+
"  window.open('"+JSMEURL+"','JSME','width=500,height=450,scrollbars=0,location=0,resizable=1');\n"+
"}\n"+
"function fromJSME(smiles)\n"+
"{\n"+
"  // this function is called from JSME window\n"+
"  if (smiles=='')\n"+
"  {\n"+
"    alert('ERROR: no molecule submitted');\n"+
"    return;\n"+
"  }\n"+
"  var form=document.mainform;\n"+
"  form.intxt.value=smiles;\n"+
"}\n"
    );
  }
  /////////////////////////////////////////////////////////////////////////////
  private String HelpHtm() throws IOException
  {
    return (
    "<H2>"+APPNAME+" help</H2>\n"+
    "<P>\n"+
    "<B>Badapple</B> = \n"+
    "<B>B</B>io<B>a</B>ctivity\n"+
    "<B>d</B>ata\n"+
    "<B>a</B>ssociative\n"+
    "<B>p</B>romiscuous\n"+
    "<B>p</B>attern\n"+
    "<B>l</B>earning\n"+
    "<B>e</B>ngine\n"+
    "These computational methods are among several\n"+
    "data mining tools developed at UNM for effective use of public data in\n"+
    "molecular discovery.\n"+
    "<P>\n"+
    "This web app analyzes each input query molecule,\n"+
    "by searching a database of bioactivity data experimentally produced by\n"+
    "the NIH Roadmap Molecular Libraries Program (MLP) screening centers.\n"+
    "For each scaffold in the query molecule,\n"+
    "the Badapple promiscuity score is computed\n"+
    "according to the following scaffold scoring formula:\n"+
    "</P>\n"+
    "<BLOCKQUOTE>\n"+
    "score = ((sActive) / (sTested + median(sTested)) *\n"+
    "        (aActive) / (aTested + median(aTested)) *\n"+
    "        (wActive) / (wTested + median(wTested)) *\n"+
    "        100) * 1000\n"+
    "</BLOCKQUOTE>\n"+
    "where:<BLOCKQUOTE>\n"+
    "sTested (substances tested)  = # tested substances containing this scaffold<BR>\n"+
    "sActive (substances active) = # active substances containing this scaffold<BR>\n"+
    "aTested (assays tested) = # assays with tested compounds containing this scaffold<BR>\n"+
    "aActive (assays active) = # assays with active compounds containing this scaffold<BR>\n"+
    "wTested (wells tested) = # wells (samples) containing this scaffold<BR>\n"+
    "wActive (wells active) = # active wells (samples) containing this scaffold<BR>\n"+
    "</BLOCKQUOTE>\n"+
    "</P>\n"+
    "<P>\n"+
    //"In single-molecule input mode, detailed output lists all scaffolds and their\n"+
    //"promiscuity scores.  In multi-molecule input mode, the output is based on scores of the\n"+
    //"highest scoring scaffold.\n"+
    //"</P>\n"+
    "<P>\n"+
    "The \"inDrug\" flag indicates whether the corresponding scaffold exists in any approved\n"+
    "drug.  A high score for an inDrug scaffold thus represents conflicting evidence,\n"+
    "but existence of an approved drug is normally much stronger evidence.\n"+
    "</P>\n"+
    "<P>\n"+
    SCORE_RANGE_KEY+"\n"+
    "<P>\n"+
    "Examples: <BR>\n"+
    "CCCc1nc-2c(=O)n(c(=O)nc2n(n1)C)C<BR>\n"+
    "c1ccc2c(c1)c(=O)n(s2)c3ccccc3C(=O)N4CCCC4<BR>\n"+
    "Cc1cc(nc(n1)/N=C(\\N)\\Nc2cccc(c2)N)C<BR>\n"+
    "CCc1c(c2ccccc2o1)C(=O)c3cc(c(c(c3)Br)O)Br<BR>\n"+
    "OC(=O)C1=C2CCCC(C=C3C=CC(=O)C=C3)=C2NC2=CC=CC=C12<BR>\n"+
    "c1ccc2c(c1)C(=O)c3ccoc3C2=O<BR>\n"+
    "<P>\n"+
    "Note that scaffold IDs are not intended to persist across versions,\n"+
    "but may be useful for inquiries and bug reports.\n"+
    "<P>\n"+
    "Refs:<OL>\n"+
    "<li> <a href=\"http://jcheminf.springeropen.com/articles/10.1186/s13321-016-0137-3\">Badapple: promiscuity patterns from noisy evidence</a>, Yang JJ, Ursu O, Lipinski CA, Sklar LA, Oprea TI Bologa CG, J. Cheminfo. 8:29 (2016), DOI: 10.1186/s13321-016-0137-3.\n"+
    "<li><a href=\"https://www.future-science.com/doi/10.4155/fmc-2018-0116\">PAIN(S) relievers for medicinal chemists: how computational methods can assist in hit evaluation</a>, Conrad Stork and Johannes Kirchmair, Future Med Chem, 29 June 2018, https://doi.org/10.4155/fmc-2018-0116.\n"+
    "<li> HierS: Hierarchical Scaffold Clustering, Wilkens et al., J. Med. Chem. 2005, 48, 3182-3193.\n"+
    "</OL>\n"+
    "<P>\n"+
    "algorithms:\n"+
    "Cristian Bologa, Oleg Ursu, Tudor Oprea, Jeremy Yang.<BR>\n"+
    "webapp: Jeremy Yang\n"+
    "<P>\n"+
    "Built with:\n"+
    "<UL>\n"+
    "<LI><A HREF=\"http://www.chemaxon.com\">JChem chemical toolkit by ChemAxon</A>.\n"+
    "<LI><A HREF=\"http://www.rdkit.org\">RDKit</A> PostgreSql cartridge.\n"+
    "<LI><A HREF=\"http://peter-ertl.com/jsme/\">JSME</A> molecular editor.\n"+
    "</UL>\n"
	);
  }
  /////////////////////////////////////////////////////////////////////////////
  /**	Read servlet parameters (from web.xml).
  */
  public void init(ServletConfig conf) throws ServletException
  {
    super.init(conf);
    CONTEXT = getServletContext();
    CONTEXTPATH = CONTEXT.getContextPath();

    try { APPNAME = conf.getInitParameter("APPNAME"); }
    catch (Exception e) { APPNAME = this.getServletName(); }
    UPLOADDIR = conf.getInitParameter("UPLOADDIR");
    if (UPLOADDIR==null) throw new ServletException("ERROR: UPLOADDIR parameter required.");
    SCRATCHDIR = conf.getInitParameter("SCRATCHDIR");
    if (SCRATCHDIR==null) SCRATCHDIR="/tmp";
    DBTYPE = conf.getInitParameter("DBTYPE");
    if (DBTYPE==null) throw new ServletException("ERROR: DBTYPE parameter required.");
    DBNAME = conf.getInitParameter("DBNAME");
    if (DBNAME==null) throw new ServletException("ERROR: DBNAME parameter required.");
    DBHOST = conf.getInitParameter("DBHOST");
    if (DBHOST==null) throw new ServletException("ERROR: DBHOST parameter required.");
    DBNAME = conf.getInitParameter("DBNAME");
    if (DBNAME==null) throw new ServletException("ERROR: DBNAME parameter required.");
    DBUSR = conf.getInitParameter("DBUSR");
    if (DBUSR==null) throw new ServletException("ERROR: DBUSR parameter required.");
    DBPW = conf.getInitParameter("DBPW");
    if (DBPW==null) throw new ServletException("ERROR: DBPW parameter required.");
    DBSCHEMA = conf.getInitParameter("DBSCHEMA");
    if (DBSCHEMA==null) throw new ServletException("ERROR: DBSCHEMA parameter required.");
    try { DBPORT = Integer.parseInt(conf.getInitParameter("DBPORT")); }
    catch (NumberFormatException e) { DBPORT=5432; }
    try { CHEMKIT = conf.getInitParameter("CHEMKIT"); }
    catch (Exception e) { CHEMKIT="rdkit"; }

    try { N_MAX = Integer.parseInt(conf.getInitParameter("N_MAX")); }
    catch (Exception e) { N_MAX=100; }
    try { MAX_POST_SIZE = Integer.parseInt(conf.getInitParameter("MAX_POST_SIZE")); }
    catch (Exception e) { MAX_POST_SIZE=10*1024*1024; }
    try { PSCORE_CUTOFF_MODERATE = Integer.parseInt(conf.getInitParameter("PSCORE_CUTOFF_MODERATE")); }
    catch (Exception e) { PSCORE_CUTOFF_MODERATE=100; }
    try { PSCORE_CUTOFF_HIGH = Integer.parseInt(conf.getInitParameter("PSCORE_CUTOFF_HIGH")); }
    catch (Exception e) { PSCORE_CUTOFF_HIGH=300; }

    try { String s = conf.getInitParameter("DEBUG"); if (s.equalsIgnoreCase("TRUE")) DEBUG=true; }
    catch (Exception e) { DEBUG=false; }

    /// Initialize persistent connection once per instantiation.
    try { DBCON = new DBCon(DBTYPE, DBHOST, DBPORT, DBNAME, DBUSR, DBPW); }
    catch (Exception e) { throw new ServletException("ERROR: DB ("+DBTYPE+") connection failed ("+DBUSR+"@"+DBHOST+"); <PRE>"+e.getMessage()+"</PRE>"); }
    if (DBCON==null) { throw new ServletException("ERROR: DB ("+DBTYPE+") connection failed ("+DBUSR+"@"+DBHOST+")."); }
    else { System.err.println("DEBUG: DB ("+DBTYPE+") connection ok ("+DBUSR+"@"+DBHOST+")."); }

    SCORE_RANGE_KEY=
      "<TABLE BORDER>\n"+
      "<TR><TH>pScore range</TH><TH>advisory</TH></TR>\n"+
      "<TR BGCOLOR=\""+colorgray+"\"><TD>~</TD>\n"+
      "<TD>unknown; no data</TD></TR>\n"+
      "<TR BGCOLOR=\""+colorgreen+"\"><TD>0.0-"+PSCORE_CUTOFF_MODERATE+"</TD>\n"+
      "<TD>low pScore; no indication</TD></TR>\n"+
      "<TR BGCOLOR=\""+coloryellow+"\"><TD>"+PSCORE_CUTOFF_MODERATE+"-"+PSCORE_CUTOFF_HIGH+"</TD>\n"+
      "<TD>moderate pScore; weak indication of promiscuity</TD></TR>\n"+
      "<TR BGCOLOR=\""+colorred+"\"><TD>&gt;"+PSCORE_CUTOFF_HIGH+"</TD>\n"+
      "<TD>high pScore; strong indication of promiscuity</TD></TR>\n"+
      "</TABLE>\n";

    PROXY_PREFIX = ((conf.getInitParameter("PROXY_PREFIX")!=null)?conf.getInitParameter("PROXY_PREFIX"):"");
  }
  /////////////////////////////////////////////////////////////////////////////
  public void doGet(HttpServletRequest request, HttpServletResponse response)
      throws IOException, ServletException
  {
    doPost(request, response);
  }
}

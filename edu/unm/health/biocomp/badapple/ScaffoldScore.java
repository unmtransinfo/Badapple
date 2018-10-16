package edu.unm.health.biocomp.badapple;

import java.io.*;
import java.util.*;

/////////////////////////////////////////////////////////////////////////////
/**	Promiscuity score information for a scaffold.
*/
public class ScaffoldScore implements Comparable<Object>
{
  private long id;
  private Float score;
  private String smiles;
  private boolean known;
  private boolean inDrug;
  private long cTested;
  private long cActive;
  private long sTested;
  private long sActive;
  private long aTested;
  private long aActive;
  private long wTested;
  private long wActive;

  public ScaffoldScore()
  {
    this.setScore(null);
    this.setKnown(false);
    this.setInDrug(false);
    this.setStats(0,0,0,0,0,0,0,0);
  }
  public ScaffoldScore(long id,String smi)
  {
    this.setID(id);
    this.setSmiles(smi);
    //this.setScore(0.0f);
    this.setScore(null); //ID may be new if scaf unknown, not in db.
    this.setKnown(true);
    this.setInDrug(false);
    this.setStats(0,0,0,0,0,0,0,0);
  }
  public void setID(long i) { this.id=i; }
  public long getID() { return this.id; }
  public void setSmiles(String s) { this.smiles=s; }
  public String getSmiles() { return this.smiles; }
  public void setScore(Float s) { this.score=s; }
  public Float getScore() { return this.score; }
  public void setKnown(boolean k) { this.known=k; }
  public boolean getKnown() { return this.known; }
  public void setInDrug(boolean d) { this.inDrug=d; }
  public boolean getInDrug() { return this.inDrug; }
  public void setCpdTested(long cT) { this.cTested=cT; }
  public void setCpdActive(long cA) { this.cActive=cA; }
  public void setSubTested(long sT) { this.sTested=sT; }
  public void setSubActive(long sA) { this.sActive=sA; }
  public void setAsyTested(long aT) { this.aTested=aT; }
  public void setAsyActive(long aA) { this.aActive=aA; }
  public void setSamTested(long wT) { this.wTested=wT; }
  public void setSamActive(long wA) { this.wActive=wA; }
  public long getCpdTested() { return this.cTested; }
  public long getCpdActive() { return this.cActive; }
  public long getSubTested() { return this.sTested; }
  public long getSubActive() { return this.sActive; }
  public long getAsyTested() { return this.aTested; }
  public long getAsyActive() { return this.aActive; }
  public long getSamTested() { return this.wTested; }
  public long getSamActive() { return this.wActive; }
  public void setStats(long cT,long cA,long sT,long sA,long aT,long aA,long wT,long wA)
  {
    this.cTested=cT;
    this.cActive=cA;
    this.sTested=sT;
    this.sActive=sA;
    this.aTested=aT;
    this.aActive=aA;
    this.wTested=wT;
    this.wActive=wA;
  }

  public int compareTo(Object o) throws ClassCastException
  {
    if (score==null && ((ScaffoldScore)o).score!=null) return 1;
    else if (score!=null && ((ScaffoldScore)o).score==null) return -1;
    else if (score==null && ((ScaffoldScore)o).score==null) return 0;
    return (score<((ScaffoldScore)o).score ? 1 : (score>((ScaffoldScore)o).score ? -1 : 0));
  }
}

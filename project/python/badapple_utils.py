#!/usr/bin/env python
'''
	Badapple utility functions.
	v2 includes gNova OpenChord functions.

	By calling cansmi from OpenChord, we assure that the canonicalization
	algorithm is the same as used when loading the db, and hence the
	lookup is robust, even if OpenChord has been upgraded to a new version since.

	Py-OpenBabel imported by this program only for client side validation of smiles,
	etc., and verbose logging.  For structural lookup, server side smiles canonicalization
	should always be used.

	Jeremy Yang
	28 Oct 2014
'''
import os,sys,getopt,re,time
import psycopg2
import psycopg2.extras
import openbabel

import ob_utils

PROG=os.path.basename(sys.argv[0])

DBHOST='localhost'
#DBHOST='carlsbad.health.unm.edu'
DBSCHEMA='badapple'
DBNAME='openchord'
DBUSR='www'
DBPW='foobar'

HIGH_THRESHOLD=300
MODERATE_THRESHOLD=100

#############################################################################
def Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW):
  '''Connect to BADAPPLE database.  Note that psycopg2.extras.DictCursor supports indexing, but
psycopg2.extras.RealDictCursor does not.
'''
  dsn=("host='%s' dbname='%s' user='%s' password='%s'"%(dbhost,dbname,dbusr,dbpw))
  dbcon=psycopg2.connect(dsn)
  dbcon.cursor_factory = psycopg2.extras.DictCursor
  return dbcon

#############################################################################
def ScafPScore(dbschema,scafid,dbcon):
  '''Return promiscuity score for given SCAFID.

	score =
	(sActive) / (sTested + median(sTested)) *
	(aActive) / (aTested + median(aTested)) *
	(wActive) / (wTested + median(wTested)) *
	100 * 1000

	where:
	  sTested (substances tested) = # tested substances containing this scaffold
	  sActive (substances active) = # active substances containing this scaffold
	  aTested (assays tested) = # assays with tested compounds containing this scaffold
	  aActive (assays active) = # assays with active compounds containing this scaffold
	  wTested (samples tested) = # samples (wells) containing this scaffold
	  wActive (samples active) = # active samples (wells) containing this scaffold
'''
  pscore=0.0

  try:
    smi,scaftree,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive = ScafIdLookup(dbschema,scafid,dbcon)
    print >>sys.stderr, "DEBUG: smi=%s,scaftree=%s,cTotal=%d,cTested=%d,cActive=%d,sTotal=%d,sTested=%d,sActive=%d,aTested=%d,aActive=%d,wTested=%d,wActive=%d"%(smi,scaftree,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive)

    desc,ts,median_cTested,median_sTested,median_aTested,median_wTested = GetMetadata(dbschema,dbcon)
    print >>sys.stderr, "DEBUG: median_cTested=%d,median_sTested=%d,median_aTested=%d,median_wTested=%d"%(median_cTested,median_sTested,median_aTested,median_wTested)

    pscore=float(sActive)/(sTested+median_sTested)
    pscore*=float(aActive)/(aTested+median_aTested)
    pscore*=float(wActive)/(wTested+median_wTested)
    pscore*=1e5
  except Exception,e:
    print >>sys.stderr, "ERROR: failed to generate pScore; Exception:",e

  return pscore

#############################################################################
def ScafIdLookup(dbschema,scafid,dbcon,verbose=0):
  '''Lookup scaffold by ID.'''
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
  sql=("SELECT scafsmi,scaftree,ncpd_total,ncpd_tested,ncpd_active,nsub_total,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active,in_drug,pscore,prank FROM %s.scaffold WHERE id=%d"%(dbschema,scafid))
  cur.execute(sql)
  row=cur.fetchone()
  cur.close()
  return row

#############################################################################
def ScafSmiLookup(dbschema,smi,iso,dbcon,verbose=0):
  '''Lookup scaffold by smiles.'''
  scafid = ScafSmi2Id(dbschema,smi,iso,dbcon,verbose)
  if not scafid:
    if verbose:
      print >>sys.stderr, 'scafsmi not found: %s'%smi
  row = ScafIdLookup(dbschema,scafid,dbcon,verbose) if scafid else []
  if row:
    row['id']=scafid
  return row

#############################################################################
def ScafSmi2Id(dbschema,smi,iso,dbcon,verbose=0):
  '''Lookup scaffold by smiles.  Requires that the database scafsmi column has been
canonicalized.'''
  #print >>sys.stderr, 'DEBUG: OBCansmi(iso=%s): %s'%(str(iso),ob_utils.OBCansmi(smi,iso))
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
  if iso: func="isosmiles"
  else: func="cansmiles"
  if re.search(r'\\',smi): smi=re.sub(r'\\',r'\\\\',smi)
  sql=("SELECT id FROM %s.scaffold WHERE scafsmi=openbabel.%s('%s')"%(dbschema,func,smi))
  cur.execute(sql)
  row=cur.fetchone()
  cur.close()
  if not row: return None
  return row['id']

#############################################################################
def CpdSmiLookup(dbschema,smi,iso,dbcon):
  '''Lookup compound[s] by smiles; return rows where each row tuple (cid,aTested,aActive,sTested,sActive,wTested,wActive).'''
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
  if re.search(r'\\',smi): smi=re.sub(r'\\',r'\\\\',smi)
  if iso:
    sql=("SELECT cid,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active FROM %s.compound WHERE isosmi=openbabel.isosmiles('%s')"%(dbschema,smi))
  else:
    sql=("SELECT cid,nsub_tested,nsub_active,nass_tested,nass_active,nsam_tested,nsam_active FROM %s.compound WHERE cansmi=openbabel.cansmiles('%s')"%(dbschema,smi))
  cur.execute(sql)
  rows=cur.fetchall()
  cur.close()
  return rows

#############################################################################
def Scafid2Cids(dbschema,scafid,dbcon):
  '''Return list of CIDs for given SCAFID.'''
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.DictCursor)
  cids=[]
  sql=("SELECT cid FROM %s.scaf2cpd WHERE scafid=%s"%(dbschema,scafid))
  cur.execute(sql)
  for row in cur:
    if row and row.has_key('cid'):
      cids.append(row['cid'])
  cur.close()
  return cids

#############################################################################
def Scafid2Sids(dbschema,scafid,dbcon):
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.DictCursor)
  sids = set()
  sql='''\
SELECT
	sid
FROM
	%(SCHEMA)s.sub2cpd,
	%(SCHEMA)s.scaf2cpd
WHERE
	%(SCHEMA)s.scaf2cpd.cid = %(SCHEMA)s.sub2cpd.cid
	AND %(SCHEMA)s.scaf2cpd.scafid = %(SCAFID)s
'''%{	'SCHEMA':dbschema,
	'SCAFID':scafid
	}
  cur.execute(sql)
  for row in cur:
    if row and row.has_key('sid'):
      sids.add(row['sid'])
  cur.close()
  return list(sids)

#############################################################################
def Scafid2Smi(dbschema,scafid,dbcon):
  '''Return SMILES for given SCAFID.'''
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
  sql=("SELECT scafsmi FROM %s.scaffold WHERE id=%s"%(dbschema,scafid))
  cur.execute(sql)
  row=cur.fetchone()
  cur.close()
  if not row: return None
  return row[0]

#############################################################################
def Cids2Smis(dbschema,cids,dbcon):
  '''Return list of SMILES for given list of CIDs.'''
  cur=dbcon.cursor()
  smis=[]
  for cid in cids:
    sql=("SELECT cansmi FROM %s.compound WHERE cid=%d"%(dbschema,cid))
    cur.execute(sql)
    rows=cur.fetchall()
    if not rows: smis.append(None)
    elif len(rows[0])<1:  smis.append(None)
    else: smis.append(rows[0][0])
  cur.close()
  return smis

#############################################################################
def DescribeSchema(dbschema,dbcon):
  '''Return human readable text describing the schema.'''
  cur=dbcon.cursor(cursor_factory=psycopg2.extras.DictCursor)
  sql=("select table_name from information_schema.tables where table_schema='%s'"%dbschema)
  cur.execute(sql)
  outtxt=""
  for row in cur:
    tablename=row[0]
    sql=("select column_name,data_type from information_schema.columns where table_schema='%s' and table_name = '%s'"%(dbschema,tablename))
    cur2=dbcon.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cur2.execute(sql)
    outtxt+=("table: %s.%s\n"%(dbschema,tablename))
    for row in cur2:
      outtxt+=("\t%s\n"%str(row))
    cur2.close()
  cur.close()
  return outtxt

#############################################################################
def DescribeCounts(dbschema,dbcon):
  '''Return human readable text listing the table rowcounts.'''
  cur=dbcon.cursor()
  outtxt=""
  sql=("select table_name from information_schema.tables where table_schema='%s' order by table_name"%dbschema)
  cur.execute(sql)
  outtxt+=("table rowcounts:\n")
  for row in cur:
    tablename=row[0]
    sql=("select count(*) from %s.%s"%(dbschema,tablename))
    cur2=dbcon.cursor()
    cur2.execute(sql)
    row=cur2.fetchone()
    outtxt+="%14s: %7d\n"%(tablename,row[0])
    cur2.close()
  cur.close()
  return outtxt
  
#############################################################################
def Summary(dbschema,dbcon):
  '''Return human readable text summary of content.'''
  cur=dbcon.cursor()
  outtxt=DescribeCounts(dbschema,dbcon)
  sql=("SELECT count(id) FROM %s.scaffold WHERE pscore < %d"%(dbschema,MODERATE_THRESHOLD))
  cur.execute(sql)
  row=cur.fetchone()
  n_low = row[0] if row else 0
  sql=("SELECT count(id) FROM %s.scaffold WHERE pscore < %d"%(dbschema,HIGH_THRESHOLD))
  cur.execute(sql)
  row=cur.fetchone()
  n_mod = (row[0] if row else 0) - n_low
  sql=("SELECT count(id) FROM %s.scaffold"%(dbschema))
  cur.execute(sql)
  row=cur.fetchone()
  n_hi = (row[0] if row else 0) - n_low - n_mod
  outtxt+='''
High score scaffolds: %(N_HI)d
Moderate score scaffolds: %(N_MOD)d
Low score scaffolds: %(N_LOW)d
Total scaffolds: %(N)d
'''%{'N_HI':n_hi,'N_MOD':n_mod,'N_LOW':n_low,'N':(n_hi+n_mod+n_low)}
  cur.close()
  return outtxt

#############################################################################
def GetMetadata(dbschema,dbcon):
  '''Return tuple of metadata from metadata table.'''
  desc,ts,median_cTested,median_sTested,median_aTested,median_wTested=(None,None,0,0,0,0)
  cur=dbcon.cursor()
  sql=("select db_description,db_date_built,median_ncpd_tested,median_nsub_tested,median_nass_tested,median_nsam_tested from %s.metadata"%dbschema)
  cur.execute(sql)
  rows=cur.fetchall()	##data rows
  if not rows:
    print >>sys.stderr, "ERROR: metadata not found in database."
  elif not len(rows[0])==6:
    print >>sys.stderr, "ERROR: metadata field count error."
  else:
    desc=rows[0][0]
    ts=rows[0][1]
    try:
      median_cTested=int(rows[0][2])
      median_sTested=int(rows[0][3])
      median_aTested=int(rows[0][4])
      median_wTested=int(rows[0][5])
    except:
      pass
  cur.close()
  return desc,ts,median_cTested,median_sTested,median_aTested,median_wTested

#############################################################################
def ScafVsAssayMatrix(dbschema,dbcon,scafids,aids,assay_id_tag,fout,verbose=0):
  ''' For the scafs and assays given, find how many compounds are active.
Output as CSV with one scaf per column, one assay (or exp) per row.
'''
  fout.write(assay_id_tag+','+(','.join(map(lambda x:str(x),scafids)))+'\n')
  n_cid=0; n_aid=0;
  cid_set = set()
  for aid in aids:
    n_aid+=1
    csvrow=[aid]
    for scafid in scafids:
      cids = Scafid2Cids(dbschema,scafid,dbcon)
      cid_set |= set(cids)
      n_act = CompoundActiveCount(dbschema,dbcon,aid,assay_id_tag,cids)
      csvrow.append(n_act)
      if verbose:
        print >>sys.stderr, 'scafid=%d, %s=%d, n_cid=%d, n_act=%d'%(scafid,assay_id_tag,aid,len(cids),n_act)
        if (n_aid%10)==0:
          print >>sys.stderr, '%d/%d (%.1f) %ss done.'%(n_aid,len(aids),100*n_aid/len(aids),assay_id_tag)
    fout.write((','.join(map(lambda x:str(x),csvrow)))+'\n')
  if verbose:
    print >>sys.stderr, 'total cids: %d'%len(cid_set)

#############################################################################
def ScafScoreVsAssayMatrix(dbschema,dbcon,scafids,aids,assay_id_tag,fout,verbose=0):
  ''' For the scafs and assays given, generate matrix, active well ratio (awr).
'''
  fout.write(assay_id_tag+','+(','.join(map(lambda x:str(x),scafids)))+'\n')
  n_cid=0; n_aid=0;
  sid_set = set()
  for aid in aids:
    n_aid+=1
    csvrow=[]
    for scafid in scafids:
      sids = Scafid2Sids(dbschema,scafid,dbcon)
      sid_set |= set(sids)

      awr = AssayActiveWellRatio(dbschema,dbcon,aid,assay_id_tag,sids)
      csvrow.append(awr)

      if verbose:
        print >>sys.stderr, 'scafid=%d, %s=%d, n_aid=%d, awr=%.2f'%(scafid,assay_id_tag,aid,n_aid,awr)
        if (n_aid%10)==0:
          print >>sys.stderr, '%d/%d (%.1f) %ss done.'%(n_aid,len(aids),100*n_aid/len(aids),assay_id_tag)

    fout.write(aid+','+(','.join(map(lambda x:('%.2f'%x),csvrow)))+'\n')
  if verbose:
    print >>sys.stderr, 'total sids: %d'%len(sid_set)

#############################################################################
def CompoundActiveCount(dbschema,dbcon,aid,assay_id_tag,cids):
  ''' How many of given CIDs are active in the given EID? '''
  cur=dbcon.cursor()
  sql='''\
SELECT
	COUNT(DISTINCT %(SCHEMA)s.sub2cpd.cid) AS "n"
FROM
	%(SCHEMA)s.activity,
	%(SCHEMA)s.sub2cpd
WHERE
	%(SCHEMA)s.activity.%(ASSAY_ID_TAG)s = %(AID)d
	AND %(SCHEMA)s.activity.sid = %(SCHEMA)s.sub2cpd.sid
	AND %(SCHEMA)s.activity.outcome = 2
	AND %(SCHEMA)s.sub2cpd.cid IN ( %(CIDS)s )
'''%{	'SCHEMA':dbschema,
	'AID':aid,
	'CIDS':(','.join(map(lambda x:str(x),cids))),
	'ASSAY_ID_TAG':assay_id_tag
	}
  cur.execute(sql)
  row=cur.fetchone()
  cur.close()
  if not row: return None
  if not row.has_key('n'): return None
  return row['n']

#############################################################################
def AssayActiveWellRatio(dbschema,dbcon,aid,assay_id_tag,sids):
  cur=dbcon.cursor()
  sql='''\
SELECT
	%(SCHEMA)s.activity.sid,
	%(SCHEMA)s.activity.outcome
FROM
	%(SCHEMA)s.activity
WHERE
	%(SCHEMA)s.activity.%(ASSAY_ID_TAG)s = %(AID)d
	AND %(SCHEMA)s.activity.sid IN ( %(SIDS)s )
'''%{	'SCHEMA':dbschema,
	'AID':aid,
	'SIDS':(','.join(map(lambda x:str(x),sids))),
	'ASSAY_ID_TAG':assay_id_tag
	}
  cur.execute(sql)
  n_active=0;
  n_tested=0;
  for row in cur:
    n_tested+=1
    if row['outcome']==2:
      n_active+=1
  cur.close()
  return (float(n_active)/n_tested if n_tested else 0)

#############################################################################
def AssayCount(dbschema,dbcon,assay_id_tag):
  cur=dbcon.cursor()
  sql='''SELECT COUNT(DISTINCT %(SCHEMA)s.activity.%(ASSAY_ID_TAG)s) FROM %(SCHEMA)s.activity
'''%{'SCHEMA':dbschema,'ASSAY_ID_TAG':assay_id_tag}
  cur.execute(sql)
  row=cur.fetchone()
  cur.close()
  if not row: return None
  return row[0]

#############################################################################
def ScaffoldCount(dbschema,dbcon):
  n_scaf=0; n_scaf_gtzero=0; n_scaf_zero=0; n_scaf_scoreless=0;
  n_scaf_high=0; n_scaf_moderate=0; n_scaf_low=0;
  cur=dbcon.cursor()
  cur.execute('''SELECT COUNT(DISTINCT id) FROM %(SCHEMA)s.scaffold'''%{'SCHEMA':dbschema})
  row=cur.fetchone()
  if row: n_scaf=row[0]
  cur.execute('''SELECT COUNT(DISTINCT id) FROM %(SCHEMA)s.scaffold WHERE pscore > 0'''%{'SCHEMA':dbschema})
  row=cur.fetchone()
  if row: n_scaf_gtzero=row[0]
  cur.execute('''SELECT COUNT(DISTINCT id) FROM %(SCHEMA)s.scaffold WHERE pscore = 0'''%{'SCHEMA':dbschema})
  row=cur.fetchone()
  if row: n_scaf_zero=row[0]
  cur.execute('''SELECT COUNT(DISTINCT id) FROM %(SCHEMA)s.scaffold WHERE pscore IS NULL'''%{'SCHEMA':dbschema})
  row=cur.fetchone()
  if row: n_scaf_scoreless=row[0]
  cur.execute('''SELECT COUNT(DISTINCT id) FROM %(SCHEMA)s.scaffold WHERE pscore >= %(HIGH_THRESHOLD)d'''%{'SCHEMA':dbschema,'HIGH_THRESHOLD':HIGH_THRESHOLD})
  row=cur.fetchone()
  if row: n_scaf_high=row[0]
  cur.execute('''SELECT COUNT(DISTINCT id) FROM %(SCHEMA)s.scaffold WHERE pscore >= %(MODERATE_THRESHOLD)d AND pscore < %(HIGH_THRESHOLD)d'''%{'SCHEMA':dbschema,'MODERATE_THRESHOLD':MODERATE_THRESHOLD,'HIGH_THRESHOLD':HIGH_THRESHOLD})
  row=cur.fetchone()
  if row: n_scaf_moderate=row[0]
  cur.close()
  print 'scaffold count: %d'%(n_scaf)
  print 'scaffold count, non-zero score: %d'%(n_scaf_gtzero)
  print 'scaffold count, zero score: %d'%(n_scaf_zero)
  print 'scaffold count, scoreless: %d'%(n_scaf_scoreless)
  print 'scaffold count, high score: %d'%(n_scaf_high)
  print 'scaffold count, moderate score: %d'%(n_scaf_moderate)
  n_scaf_low = n_scaf - n_scaf_high - n_scaf_moderate
  print 'scaffold count, low score: %d'%(n_scaf_low)
  print 'scaffold count, low score, non-zero: %d'%(n_scaf_low-n_scaf_zero-n_scaf_scoreless)
  return

#############################################################################
def TopScores(dbschema,dbcon,nmax,fout,verbose=0):
  cur=dbcon.cursor()
  if not nmax:
    sql=("SELECT id,scafsmi,in_drug,pscore,prank FROM %s.scaffold ORDER BY pscore DESC"%(dbschema))
  else:
    sql=("SELECT id,scafsmi,in_drug,pscore,prank FROM %s.scaffold ORDER BY pscore DESC LIMIT %d"%(dbschema,nmax))
  cur.execute(sql)
  if not cur: return
  fout.write('scafsmi,rank,scafid,in_drug,pscore\n')
  i=0;
  for row in cur:
    i+=1
    scafid,scafsmi,in_drug,pscore,prank = row
    #Should be i==prank.  Check?
    fout.write('"%s",%s,%d,%d,%s\n'%(scafsmi,(str(prank) if prank else ''),scafid,(1 if in_drug else 0),(str(pscore) if pscore else '')))
    if verbose>2:
      print >>sys.stderr, '%d. %7d: pscore=%4d, prank=%4d, in_drug[%s] %s'%(i,scafid,pscore,prank,('x' if in_drug else ' '),scafsmi)
  cur.close()
  print >>sys.stderr, 'TopScores: %d out'%i

#############################################################################
def TopScores_Compare(dbschemaA,dbschemaB,dbcon,nmax,non_null,non_zero,fout,verbose=0):
  '''Get top scores from schemaA, schemaB; use smiles to get scores for same scaffolds from
other schema for comparison and validation.
	- Is top-N A scaffold present in B?
	- Is top-N A scaffold top-N in B?
	- Is top-N B scaffold present in A?
	- Is top-N B scaffold top-N in A?

Spearman's Rank Correlation Coefficient?  For the common scafs?

NEW: Can we consider the non-null, w/ data scores?  I.e. differentiate between zero scores and
null scores.  Ideally, classify scores:

  - High
  - Moderate
  - Low
  - Zero w/ evidence
  - Zero no-evidence (null, scoreless)

'''
  cur=dbcon.cursor()
  fout.write('scafsmiA,scafsmiB,rankA,rankB,scafidA,scafidB,in_drugA,in_drugB,pscoreA,pscoreB\n')

  if verbose:
    print >>sys.stderr, 'NOTE: Comparing "%s" vs. "%s":'%(dbschemaA,dbschemaB)
  n_err=0;
  scafidAs=set();
  scafidBs=set();
  scafsmiAs=set();
  scafsmiBs=set();
  scafdata=[]  #list of lists

  wheres=[]
  if non_null: wheres.append("pscore IS NOT NULL")
  if non_zero: wheres.append("pscore != 0")

  ##Schema A: For each scaf, try to lookup in Schema B via smiles.
  ## If found:
  ##   - Increment n_found_AinB.
  ## Write full scaffold data.
  sql=("SELECT id,scafsmi,in_drug,pscore,prank FROM %s.scaffold"%(dbschemaA))
  if wheres:
    sql+=(" WHERE "+(" AND ".join(wheres)))
  if nmax:
    sql+=(" ORDER BY pscore DESC LIMIT %d"%(nmax))
  else:
    sql+=(" ORDER BY pscore DESC")
  cur.execute(sql)
  if not cur: return

  rankA=0;
  rankB=0;
  n_found_AinB=0;
  n_found_BinA=0;
  for row in cur:
    rankA+=1
    scafidA,scafsmiA,in_drugA,pscoreA,prankA = row
    #Should be rankA==prankA.  Check?
    scafidAs.add(int(scafidA))
    scafsmiAs.add(ob_utils.OBCansmi(scafsmiA,False))
    scafidB = ScafSmi2Id(dbschemaB,scafsmiA,iso=False,dbcon=dbcon,verbose=verbose)
    if scafidB:
      scafidBs.add(int(scafidB))
      row2 = ScafIdLookup(dbschemaB,scafidB,dbcon=dbcon,verbose=verbose)
      scafsmiB,in_drugB,pscoreB,prankB = row2[0],row2[12],row2[13],row2[14]
      n_found_AinB+=1
    else:
      scafsmiB,scafidB,in_drugB,pscoreB,prankB = None,None,None,None,None

    scafdata.append( [scafsmiA,scafsmiB,prankA,prankB,scafidA,scafidB,
	(1 if in_drugA else 0),('1' if in_drugB else ('0' if in_drugB!=None else '')),
	pscoreA,(str(int(pscoreB)) if pscoreB else '')] )

  ##Schema B: For each scaf:
  ## If already known (scafidB):
  ##   - Increment n_found_BinA.
  ## Try to lookup in Schema A via smiles.
  ## If found:
  ##   - Increment n_found_BinA.
  ## If new:
  ## Write full scaffold data.
  sql=("SELECT id,scafsmi,in_drug,pscore,prank FROM %s.scaffold"%(dbschemaB))
  if wheres:
    sql+=(" WHERE "+(" AND ".join(wheres)))
  if nmax:
    sql+=(" ORDER BY pscore DESC LIMIT %d"%(nmax))
  else:
    sql+=(" ORDER BY pscore DESC")
  cur.execute(sql)

  for row in cur:
    rankB+=1
    scafidB,scafsmiB,in_drugB,pscoreB,prankB = row
    #Should be rankB==prankB.  Check?
    scafsmiBs.add(ob_utils.OBCansmi(scafsmiB,False))
    if scafidB in scafidBs:
      n_found_BinA+=1
      continue
    scafidBs.add(int(scafidB))
    scafidA = ScafSmi2Id(dbschemaA,scafsmiB,iso=False,dbcon=dbcon,verbose=verbose)
    if scafidA:
      scafidAs.add(int(scafidA))
      row2 = ScafIdLookup(dbschemaA,scafidA,dbcon=dbcon,verbose=verbose)
      scafsmiA,in_drugA,pscoreA,prankA = row2[0],row2[12],row2[13],row2[14]
      n_found_BinA+=1
    else:
      scafsmiA,scafidA,in_drugA,pscoreA,prankA = None,None,None,None,None

    scafdata.append( [scafsmiA,scafsmiB,prankA,prankB,scafidA,scafidB,
	(1 if in_drugA else 0),('1' if in_drugB else ('0' if in_drugB!=None else '')),
	pscoreA,(str(int(pscoreB)) if pscoreB else '')] )

  for row in scafdata:

    scafsmiA,scafsmiB,prankA,prankB,scafidA,scafidB,in_drugA,in_drugB,pscoreA,pscoreB = row

    fout.write('"%s","%s",%s,%s,%s,%s,%s,%s,%s,%s\n'%(
	scafsmiA,
	scafsmiB,
	(str(int(prankA)) if prankA else ''),
	(str(int(prankB)) if prankB else ''),
	(str(int(scafidA)) if scafidA else ''),
	(str(int(scafidB)) if scafidB else ''),
	('1' if in_drugA else ('0' if in_drugA!=None else '')),
	('1' if in_drugB else ('0' if in_drugB!=None else '')),
	(str(int(pscoreA)) if pscoreA else ''),
	(str(int(pscoreB)) if pscoreB else '')))

  cur.close()
  print >>sys.stderr, 'TopScores_Compare: n=%d, n_err=%d'%(len(scafdata),n_err)
  print >>sys.stderr, 'TopScores_Compare Params: non_null: %s, non_zero: %s'%(str(non_null),str(non_zero))
  scafsmisCommon = scafsmiAs & scafsmiBs
  print >>sys.stderr, 'TopScores_Compare: Top scafs in common: %d'%(len(scafsmisCommon))
  print >>sys.stderr, 'TopScores_Compare: n_found(AinB)=%d (present in all B)'%(n_found_AinB)
  print >>sys.stderr, 'TopScores_Compare: n_found(BinA)=%d (present in all A)'%(n_found_BinA)

#############################################################################
def Test(dbschema,dbcon):
  cur=dbcon.cursor()

  scafsmis = [
  'c1cnc2n(c1=O)ccs2',
  'c1cc([nH]c1)C(=O)CSc2[nH]c(nn2)c3ccncc3',
  'c1csc(n1)SCC(=O)c2c[nH]c(=O)[nH]c2=O'
          ]
  
  for smi in scafsmis:
      fields=ScafSmiLookup(dbschema,smi,dbcon)
      print "scafsmi:",smi
      if not fields:
        print "\tnot found"
        continue
      print "\tscafid:",fields[0]
      print "\tcTotal:",fields[1]
      print "\tcTested:",fields[2]
      print "\tcActive:",fields[3]
      print "\tsTotal:",fields[4]
      print "\tsTested:",fields[5]
      print "\tsActive:",fields[6]
      print "\taTested:",fields[7]
      print "\taActive:",fields[8]
      print "\twTested:",fields[9]
      print "\twActive:",fields[10]
  
      cids=Scafid2Cids(dbschema,fields[0],dbcon)
      smis=Cids2Smis(dbschema,cids,dbcon)
      print "\tcids: %d"%len(cids)
      print "\tsmis: %d"%len(smis)
  
  smis = [
  'CC1=CC=CC=C1NC2=NC(=NC(=N2)N)CSC3=NN=NN3C4=CC=CC=C4',
  'CCOC(=O)CC1=CSC(=N1)SCC(=O)NC2=CC(=CC=C2)Cl',
  'CC1=CSC(=N1)SCC(=O)NC2=C(C3=C(S2)CCC3)C#N'
  'c1ccc(cc1)C[C@@H](C(=O)OCC(=O)Nc2ccc3c(c2)OCO3)N4C(=O)c5ccccc5C4=O',
  'CC(C)NC[C@H](COc1ccccc1CC=C)O'
  	]
  	
  for smi in smis:
    print "compound:",smi
    iso=True
    rows=CpdSmiLookup(dbschema,smi,iso,dbcon)
    iso=False
    if not rows: rows=CpdSmiLookup(dbschema,smi,iso,dbcon)
    if not rows:
      print "\tnot found"
      continue
    for i,fields in enumerate(rows):
      print "\t[%d]cid: %d"%(i+1,fields[0])
      print "\t[%d]sTested: %d"%(i+1,fields[1])
      print "\t[%d]sActive: %d"%(i+1,fields[2])
      print "\t[%d]aTested: %d"%(i+1,fields[3])
      print "\t[%d]aActive: %d"%(i+1,fields[4])
      print "\t[%d]wTested: %d"%(i+1,fields[5])
      print "\t[%d]wActive: %d"%(i+1,fields[6])
 
  print DescribeSchema(dbschema,dbcon)
  desc,ts,median_cTested,median_sTested,median_aTested,median_wTested=GetMetadata(dbschema,dbcon)
  print "Description:",desc
  print "Timestamp:",ts
  print "median_cTested: %d"%median_cTested
  print "median_sTested: %d"%median_sTested
  print "median_aTested: %d"%median_aTested
  print "median_wTested: %d"%median_wTested

  scafid=17
  print "ScafPScore (SCAFID=%d): %.2f"%(scafid,ScafPScore(dbschema,scafid,dbcon))


#############################################################################

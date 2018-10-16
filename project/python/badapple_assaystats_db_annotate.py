#!/usr/bin/env python
'''
badapple_assaystats_db_annotate.py
 
After badapple database has been otherwise fully populated, with:
   -> compound table (id, nass_tested, nass_active, nsam_tested, nsam_active )
   -> scaffold table (id, ... )
   -> scaf2cpd table (scafid, cid )
   -> activity table (sid, aid, outcome )
 
Generate activity statistics and annotate compound and scaffold tables.

Optional: Selected assays for custom score, e.g. date or target criteria.

scaffold columns affected:
     ncpd_total, ncpd_tested, ncpd_active, nsub_total, nsub_tested, nsub_active, nass_tested, nass_active, nsam_tested, nsam_active

compound columns affected:
     nsub_total, nsub_tested, nsub_active, nass_tested, nass_active, nsam_tested, nsam_active

MLP Outcome codes:

   1 = inactive
   2 = active
   3 = inconclusive
   4 = unspecified
   5 = probe
   multiple, differing 1, 2 or 3 = discrepant
   not 4 = tested

author: Jeremy Yang
17 Jan 2017
'''
#############################################################################
import sys,os,getopt,re,time
import pgdb

import time_utils
import badapple_utils

PROG=os.path.basename(sys.argv[0])

DBSCHEMA='public'
DBSCHEMA_ACTIVITY='badapple'
DBHOST='localhost'
DBNAME='badapple'
DBUSR='www'
DBPW='foobar'

ASSAY_ID_TAG='aid'

#############################################################################
def AnnotateCompounds(db,dbschema,dbschema_activity,assay_id_tag,assay_ids,no_write,n_max=0,n_skip=0,verbose=0):
  '''Loop over compounds.  For each compound call AnnotateCompound().
'''
  n_cpd_total=0; # total compounds processed
  n_sub_total=0; # total substances processed
  n_res_total=0; # total results (outcomes) processed
  n_write=0; # total table rows modified
  n_err=0;
  cur=db.cursor()
  sql='''SELECT cid FROM %(DBSCHEMA)s.compound'''%{'DBSCHEMA':dbschema}
  #if verbose>2: print >>sys.stderr, "DEBUG: sql=\"%s\""%(sql)
  cur.execute(sql)
  cpd_rowcount=cur.rowcount  ## use for progress msgs
  if verbose>2:
    print >>sys.stderr, "cpd rowcount=%d"%(cpd_rowcount)
  row=cur.fetchone()
  n=0
  t0=time.time()
  while row!=None:
    n+=1
    if n<=n_skip:
      row=cur.fetchone()
      continue
    n_cpd_total+=1
    cid=row[0]
    if verbose>2:
      print >>sys.stderr, "CID=%4d:"%(cid),
    sTotal,sTested,sActive,aTested,aActive,wTested,wActive,ok_write,n_err_this = AnnotateCompound(cid,db,dbschema,dbschema_activity,assay_id_tag,assay_ids,no_write,verbose)
    n_sub_total+=sTotal
    n_res_total+=wTested
    if ok_write: n_write+=1
    n_err+=n_err_this
    if (verbose>0 and (n%1000)==0) or verbose>2:
      print >>sys.stderr, "n_cpd: %d ; elapsed time: %s (%.1f%% done)"%(n_cpd_total,time_utils.NiceTime(time.time()-t0),100.0*n_cpd_total/cpd_rowcount)
    row=cur.fetchone()
    if n_cpd_total==n_max: break
  cur.close()
  db.close()
  return n_cpd_total,n_sub_total,n_res_total,n_write,n_err


#############################################################################
def AnnotateCompound(cid,db,dbschema,dbschema_activity,assay_id_tag,assay_ids,no_write,verbose=0):
  '''For this compound, loop over substances.  For each substance, loop over assay outcomes. 
Generate assay statistics.  Update compound row.
	sTotal	- substances containing scaffold
	sTested	- tested substances containing scaffold
	sActive	- active substances containing scaffold
	aTested	- assays involving substances containing scaffold
	aActive	- assays involving active substances containing scaffold
	wTested	- samples (wells) involving substances containing scaffold
	wActive	- active samples (wells) involving substances containing scaffold
'''
  sTotal=0;	# total substances, this compound
  sTested=0;	# substances tested, this compound
  sActive=0;	# substances active, this compound
  aTested=0;	# assays tested, this compound
  aActive=0;	# assays active, this compound
  wTested=0;	# wells (samples) tested, this compound
  wActive=0;	# wells (samples) active, this compound
  ok_write=False;	# flag true if write row update ok
  n_err=0;
  sql='''SELECT DISTINCT sid FROM %(DBSCHEMA)s.sub2cpd WHERE %(DBSCHEMA)s.sub2cpd.cid=%(CID)d'''%{'DBSCHEMA':dbschema,'CID':cid}
  cur1=db.cursor()
  #if verbose>2: print >>sys.stderr, "DEBUG: sql=\"%s\""%(sql)
  cur1.execute(sql)
  sub_rowcount=cur1.rowcount
  if verbose>2:
    print >>sys.stderr, "sub rowcount=%d"%(sub_rowcount)
  row1=cur1.fetchone()
  assays={} ##store unique assays for this compound
  while row1!=None:  ##substance loop
    sid=row1[0]
    sTotal+=1

    # Now get outcomes...
    sql='''\
SELECT
	%(ASSAY_ID_TAG)s,outcome
FROM
	%(DBSCHEMA_ACTIVITY)s.activity
WHERE
	%(DBSCHEMA_ACTIVITY)s.activity.sid=%(SID)d
'''%{'ASSAY_ID_TAG':assay_id_tag,'DBSCHEMA':dbschema,'DBSCHEMA_ACTIVITY':dbschema_activity,'SID':sid}
    #if verbose>2: print >>sys.stderr, "DEBUG: sql=\"%s\""%(sql)
    t0=time.time()
    cur2=db.cursor()
    cur2.execute(sql)
    res_rowcount=cur2.rowcount
    #if verbose>2: print >>sys.stderr, "outcome rowcount=%d"%(res_rowcount)
    row2=cur2.fetchone()
    if row2==None: ##no outcomes; not tested
      if verbose>2: print >>sys.stderr, "DEBUG: no outcomes; sql=\"%s\""%(sql)
      row1=cur1.fetchone()
      continue
    sTested+=1
    nres_sub_this=0; nres_sub_act_this=0;
    nass_sub_this=0; nass_sub_act_this=0;
    while row2!=None: ##outcome loop
      aid, outcome = row2
      if assay_ids and (aid not in assay_ids):	##custom selection
        row2=cur2.fetchone()
        continue
      wTested+=1
      nres_sub_this+=1
      if outcome in (2,5):  ##active or probe
        nres_sub_act_this+=1
        wActive+=1
        if assays.has_key(aid):
          assays[aid]=True
        else:
          assays[aid]=True
          nass_sub_this+=1
          nass_sub_act_this+=1
      elif outcome in (1,3): ##tested inactive
        if assays.has_key(aid):
          assays[aid]|=False
        else:
          assays[aid]=False
          nass_sub_this+=1
      row2=cur2.fetchone()
    cur2.close()
    row1=cur1.fetchone()
    if nres_sub_act_this>0:
      sActive+=1
    if verbose>2:
      print >>sys.stderr, '\t%4d. SID=%4d n_res: %4d ; n_res_act: %4d ; n_ass: %4d ; n_ass_act: %4d'%(sTested,sid,nres_sub_this,nres_sub_act_this,nass_sub_this,nass_sub_act_this)
  cur1.close()
  if verbose>2:
    print >>sys.stderr, 'n_sub: %4d ; n_ass: %4d'%(sTested,len(assays))
  for aid in assays.keys():
    aTested+=1
    if assays[aid]:
      aActive+=1

  ## update compound row ...
  sql='''\
UPDATE
	%(DBSCHEMA)s.compound
SET
	nsub_total = %(NSUB_TOTAL)d,
	nsub_tested = %(NSUB_TESTED)d,
	nsub_active = %(NSUB_ACTIVE)d,
	nass_tested = %(NASS_TESTED)d,
	nass_active = %(NASS_ACTIVE)d,
	nsam_tested = %(NSAM_TESTED)d,
	nsam_active = %(NSAM_ACTIVE)d
WHERE
	cid=%(CID)d
'''%{	'DBSCHEMA':dbschema,
	'CID':cid,
	'NSUB_TOTAL':sTotal,
	'NSUB_TESTED':sTested,
	'NSUB_ACTIVE':sActive,
	'NASS_TESTED':aTested,
	'NASS_ACTIVE':aActive,
	'NSAM_TESTED':wTested,
	'NSAM_ACTIVE':wActive}
  if not no_write:
    try:
      cur1=db.cursor()
      cur1.execute(sql)
      db.commit()
      cur1.close()
      ok_write=True
    except Exception,e:
      print >>sys.stderr,e
      n_err+=1
  if verbose>1:
    print >>sys.stderr, 'CID=%d,sTotal=%d,sTested=%d,sActive=%d,aTested=%d,aActive=%d,wTested=%d,wActive=%d'%(cid,sTotal,sTested,sActive,aTested,aActive,wTested,wActive)

  return sTotal,sTested,sActive,aTested,aActive,wTested,wActive,ok_write,n_err

#############################################################################
def AnnotateScaffolds(db,dbschema,dbschema_activity,assay_id_tag,assay_ids,no_write,n_max=0,n_skip=0,verbose=0):
  '''Loop over scaffolds.  For each scaffold call AnnotateScaffold().
NOTE: This function presumes that the compound annotations have already been accomplished
by AnnotateCompounds().
'''
  n_scaf_total=0; # total scaffolds processed
  n_cpd_total=0; # total compounds processed
  n_sub_total=0; # total substances processed
  n_res_total=0; # total results (outcomes) processed
  n_write=0; # total table rows modified
  n_err=0;
  cur=db.cursor()
  sql='''SELECT id FROM %(DBSCHEMA)s.scaffold ORDER BY id'''%{'DBSCHEMA':dbschema}
  #print >>sys.stderr, 'DEBUG: sql = "%s"'%sql
  cur.execute(sql)
  scaf_rowcount=cur.rowcount  ## use for progress msgs
  if verbose>2:
    print >>sys.stderr, "\tscaf rowcount=%d"%(scaf_rowcount)
  row=cur.fetchone()
  n=0
  t0=time.time()
  while row!=None:
    n+=1
    if n<=n_skip:
      row=cur.fetchone()
      continue
    n_scaf_total+=1
    scafid=row[0]
    if verbose>2:
      print >>sys.stderr, "SCAFID=%4d:"%(scafid),
    nres_this,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive,ok_write,n_err_this = AnnotateScaffold(scafid,db,dbschema,dbschema_activity,assay_id_tag,assay_ids,no_write,verbose)
    n_cpd_total+=cTotal
    n_sub_total+=sTotal
    n_res_total+=nres_this
    if ok_write: n_write+=1
    n_err+=n_err_this
    if (verbose>0 and (n%100)==0) or verbose>2:
      print >>sys.stderr, "n_scaf: %d ; elapsed time: %s (%.1f%% done)"%(n_scaf_total,time_utils.NiceTime(time.time()-t0),100.0*n_scaf_total/scaf_rowcount)
    row=cur.fetchone()
    if n_scaf_total==n_max: break
  cur.close()
  db.close()
  return n_scaf_total,n_cpd_total,n_sub_total,n_res_total,n_write,n_err

#############################################################################
def AnnotateScaffold(scafid,db,dbschema,dbschema_activity,assay_id_tag,assay_ids,no_write,verbose=0):
  '''For this scaffold, loop over compounds.  For each compound, loop over assay outcomes.
Generate assay statistics.  Update scaffold row. 
	cTotal	- compounds containing scaffold
	cTested	- tested compounds containing scaffold
	cActive	- active compounds containing scaffold
	sTotal	- substances containing scaffold
	sTested	- tested substances containing scaffold
	sActive	- active substances containing scaffold
	aTested	- assays involving compounds containing scaffold
	aActive	- assays involving active compounds containing scaffold
	wTested	- samples (wells) involving compounds containing scaffold
	wActive	- active samples (wells) involving compounds containing scaffold

NOTE: This function presumes that the compound annotations have already been completed.
'''
  cTotal=0;	# total compounds, this scaffold
  cTested=0;	# compounds tested, this scaffold
  cActive=0;	# compounds active, this scaffold
  sTotal=0;	# total substances, this scaffold
  sTested=0;	# substances tested, this scaffold
  sActive=0;	# substances active, this scaffold
  aTested=0;	# assays tested, this scaffold
  aActive=0;	# assays active, this scaffold
  wTested=0;	# wells (samples) tested, this scaffold
  wActive=0;	# wells (samples) active, this scaffold
  nres_total=0;	# total results (outcomes) processed, this scaffold
  ok_write=False;	# flag true if write row update ok
  n_err=0;
  sql='''\
SELECT
	compound.cid,
	compound.nsub_total,
	compound.nsub_tested,
	compound.nsub_active,
	compound.nass_tested,
	compound.nass_active,
	compound.nsam_tested,
	compound.nsam_active
FROM
	%(DBSCHEMA)s.compound,
	%(DBSCHEMA)s.scaf2cpd
WHERE
	%(DBSCHEMA)s.scaf2cpd.scafid=%(SCAFID)d
	AND %(DBSCHEMA)s.scaf2cpd.cid=%(DBSCHEMA)s.compound.cid
'''%{'DBSCHEMA':dbschema,'SCAFID':scafid}
  cur1=db.cursor()
  cur1.execute(sql)
  cpd_rowcount=cur1.rowcount
  if verbose>2:
    print >>sys.stderr, "\tcpd rowcount=%d"%(cpd_rowcount)
  row1=cur1.fetchone()
  assays={} ##store unique assays for this scaffold
  while row1!=None:  ##compound loop
    cid,c_sTotal,c_sTested,c_sActive,c_aTested,c_aActive,c_wTested,c_wActive = row1
    cTotal+=1
    if c_aTested>0: cTested+=1
    if c_aActive>0: cActive+=1
    sTotal +=  (c_sTotal if c_sTotal else 0)
    sTested += (c_sTested if c_sTested else 0)
    sActive += (c_sActive if c_sActive else 0)
    wTested += (c_wTested if c_wTested else 0)
    wActive += (c_wActive if c_wActive else 0)

    ## Compound statistics are used to derive sTotal,sTested, sActive, wTested, and wActive.
    ## However we cannot use the compound statistics to derive aTested and aActive
    ## because we want to count assays _per_ _scaffold_. So, for example, 2 compounds
    ## (with this scaffold) active in the same assay should increment aActive by only 1, not 2.

    # Now get substances...
    sql='''SELECT DISTINCT sid FROM %(DBSCHEMA)s.sub2cpd WHERE %(DBSCHEMA)s.sub2cpd.cid=%(CID)d'''%{'DBSCHEMA':dbschema,'CID':cid}
    cur2=db.cursor()
    cur2.execute(sql)
    sub_rowcount=cur2.rowcount
    if verbose>2:
      print >>sys.stderr, "\tsub rowcount=%d"%(sub_rowcount)
    row2=cur2.fetchone()
    nres_cpd_this=0;		# outcome count, this compound
    nres_cpd_act_this=0;	# active outcome count, this compound
    nass_cpd_this=0;		# assay count, this compound
    nass_cpd_act_this=0;	# active assay count, this compound
    while row2!=None:  ##substance loop
      sid=row2[0]

      # Now get outcomes...
      sql='''\
SELECT
	activity.%(ASSAY_ID_TAG)s,activity.outcome
FROM
	%(DBSCHEMA_ACTIVITY)s.activity
WHERE
	%(DBSCHEMA_ACTIVITY)s.activity.sid=%(SID)d
'''%{'ASSAY_ID_TAG':assay_id_tag,'DBSCHEMA_ACTIVITY':dbschema_activity,'SID':sid}
      t0=time.time()
      cur3=db.cursor()
      cur3.execute(sql)
      res_rowcount=cur3.rowcount
      if verbose>2:
        print >>sys.stderr, "\toutcome rowcount=%d"%(res_rowcount)
      row3=cur3.fetchone()
      if row3==None: ## No outcomes; normal, untested substance.
        #print >>sys.stderr, 'DEBUG: untested SID: %d'%sid
        row2=cur2.fetchone()
        continue
      while row3!=None: ##outcome loop
        aid, outcome = row3
        if assay_ids and (aid not in assay_ids):	##custom selection
          row3=cur3.fetchone()
          continue
        nres_total+=1
        nres_cpd_this+=1
        if outcome in (2,5):  ##active or probe
          nres_cpd_act_this+=1
          if assays.has_key(aid):
            assays[aid]=True
          else:
            assays[aid]=True
            nass_cpd_this+=1
            nass_cpd_act_this+=1
        elif outcome in (1,3): ##tested inactive
          if assays.has_key(aid):
            assays[aid]|=False
          else:
            assays[aid]=False
            nass_cpd_this+=1
        row3=cur3.fetchone() #END of outcome loop
      cur3.close()
      row2=cur2.fetchone() #END of substance loop
    cur2.close()
    if verbose>2:
      print >>sys.stderr, '\t%4d. CID=%4d n_res: %4d ; n_res_act: %4d ; n_ass: %4d ; n_ass_act: %4d'%(cTotal,cid,nres_cpd_this,nres_cpd_act_this,nass_cpd_this,nass_cpd_act_this)
      print >>sys.stderr, "\tcpd elapsed time: %s (%.1f%% done this scaf)"%(time_utils.NiceTime(time.time()-t0),100.0*cTotal/cpd_rowcount)
    row1=cur1.fetchone() #END of compound loop
  cur1.close()
  if verbose>2:
    print >>sys.stderr, '\tn_cpd: %4d ; n_ass: %4d'%(cTotal,len(assays))
  for aid in assays.keys():
    aTested+=1
    if assays[aid]:
      aActive+=1

  ## update scaffold row ...
  sql='''\
UPDATE
	%(DBSCHEMA)s.scaffold
SET
	ncpd_total = %(NCPD_TOTAL)d,
	ncpd_tested = %(NCPD_TESTED)d,
	ncpd_active = %(NCPD_ACTIVE)d,
	nsub_total = %(NSUB_TOTAL)d,
	nsub_tested = %(NSUB_TESTED)d,
	nsub_active = %(NSUB_ACTIVE)d,
	nass_tested = %(NASS_TESTED)d,
	nass_active = %(NASS_ACTIVE)d,
	nsam_tested = %(NSAM_TESTED)d,
	nsam_active = %(NSAM_ACTIVE)d
WHERE
	id=%(SCAFID)d
'''%{	'DBSCHEMA':dbschema,
	'SCAFID':scafid,
	'NCPD_TOTAL':cTotal,
	'NCPD_TESTED':cTested,
	'NCPD_ACTIVE':cActive,
	'NSUB_TOTAL':sTotal,
	'NSUB_TESTED':sTested,
	'NSUB_ACTIVE':sActive,
	'NASS_TESTED':aTested,
	'NASS_ACTIVE':aActive,
	'NSAM_TESTED':wTested,
	'NSAM_ACTIVE':wActive}
  if not no_write:
    try:
      cur1=db.cursor()
      cur1.execute(sql)
      db.commit()
      cur1.close()
      ok_write=True
    except Exception,e:
      print >>sys.stderr,e
      n_err+=1
  if verbose>1:
    print >>sys.stderr, 'SCAFID=%d,cTotal=%d,cTested=%d,cActive=%d,sTotal=%d,sTested=%d,sActive=%d,aTested=%d,aActive=%d,wTested=%d,wActive=%d'%(scafid,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive)
  return nres_total,cTotal,cTested,cActive,sTotal,sTested,sActive,aTested,aActive,wTested,wActive,ok_write,n_err

#############################################################################
if __name__=='__main__':
  usage='''
  %(PROG)s - annotate badapple with activity statistics

scaffold columns affected:
     ncpd_total, ncpd_tested, ncpd_active, nsub_total, nsub_tested, nsub_active, nass_tested, nass_active, nsam_tested, nsam_active

compound columns affected:
     nsub_total, nsub_tested, nsub_active, nass_tested, nass_active, nsam_tested, nsam_active

  required (one of):
  --annotate_compounds ......... update compound table (from activity table)
  --annotate_scaffolds ......... update scaffold table (from activity table)

  NOTE: --annotate_compounds required _before_ --annotate_scaffolds.

  options:
  --assay_id_file AIDF ......... selected IDs (for custom scores)
  --assay_id_tag TAG ........... [%(ASSAY_ID_TAG)s]
  --n_max NMAX ................. max scaffolds to annotate
  --n_skip NSKIP ............... skip first N
  --dbschema DBSCHEMA .......... [%(DBSCHEMA)s]
  --dbschema_activity DBS2 ..... activity table may be in separate schema [%(DBSCHEMA_ACTIVITY)s]
  --dbhost DBHOST .............. [%(DBHOST)s]
  --dbname DBNAME .............. [%(DBNAME)s]
  --dbusr DBUSR ................ [%(DBUSR)s]
  --dbpw DBPW .................. 
  --no_write ................... do not write to db; for testing
  --v[v[v]] .................... verbose [very [very]]
  --h .......................... this help
'''%{'PROG':PROG,
	'DBSCHEMA':DBSCHEMA,
	'DBSCHEMA_ACTIVITY':DBSCHEMA_ACTIVITY,
	'DBHOST':DBHOST,
	'DBNAME':DBNAME,
	'DBUSR':DBUSR,
	'ASSAY_ID_TAG':ASSAY_ID_TAG}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  verbose=0; n_max=0; n_skip=0;
  assay_id_file=None;
  annotate_scaffolds=False; annotate_compounds=False; no_write=False;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv','vvv',
	'annotate_scaffolds','annotate_compounds','no_write',
	'dbhost=','dbname=','dbusr=','dbpw=',
	'assay_id_tag=',
	'assay_id_file=',
	'n_max=','n_skip=','dbschema=','dbschema_activity='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--n_max': n_max=int(val)
    elif opt=='--n_skip': n_skip=int(val)
    elif opt=='--annotate_scaffolds': annotate_scaffolds=True
    elif opt=='--annotate_compounds': annotate_compounds=True
    elif opt=='--no_write': no_write=True
    elif opt=='--dbschema': DBSCHEMA=val
    elif opt=='--dbschema_activity': DBSCHEMA_ACTIVITY=val
    elif opt=='--dbhost': DBHOST=val
    elif opt=='--dbname': DBNAME=val
    elif opt=='--dbusr': DBUSR=val
    elif opt=='--dbpw': DBPW=val
    elif opt=='--assay_id_tag': ASSAY_ID_TAG=val
    elif opt=='--assay_id_file': assay_id_file=val
    elif opt=='--v': verbose=1
    elif opt=='--vv': verbose=2
    elif opt=='--vvv': verbose=3
    else: ErrorExit('Illegal option: %s'%val)

  print >>sys.stderr, "%s: database: %s:%s:%s"%(PROG,DBHOST,DBNAME,DBSCHEMA)

  if verbose>0:
    print >>sys.stderr, "%s: %s"%(PROG,time.strftime('%Y-%m-%d %H:%M:%S',time.localtime()))
  t0=time.time()

  dbcon = badapple_utils.Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW)

  assay_ids=set(); #optional selected IDs
  if assay_id_file:
    fin=open(assay_id_file)
    if not fin: ErrorExit('ERROR: cannot open: %s'%assay_id_file)
    while True:
      line=fin.readline()
      if not line: break
      try:
        assay_ids.add(int(line.rstrip()))
      except:
        print >>sys.stderr, 'ERROR: bad input ID: %s'%line
        continue
    if verbose:
      print >>sys.stderr, '%s: unique input IDs: %d'%(PROG,len(assay_ids))
    fin.close()

  if annotate_compounds:
    n_cpd_total,n_sub_total,n_res_total,n_write_total,n_err_total = AnnotateCompounds(dbcon,DBSCHEMA,DBSCHEMA_ACTIVITY,ASSAY_ID_TAG,assay_ids,no_write,n_max,n_skip,verbose)
    print >>sys.stderr, "%s: total substances: %d"%(PROG,n_sub_total)
    print >>sys.stderr, "%s: total compounds: %d"%(PROG,n_cpd_total)
    print >>sys.stderr, "%s: total outcomes: %d"%(PROG,n_res_total)
    print >>sys.stderr, "%s: total compound records modified: %d"%(PROG,n_write_total)
    print >>sys.stderr, "%s: total errors: %d"%(PROG,n_err_total)
  elif annotate_scaffolds:
    n_scaf_total,n_cpd_total,n_sub_total,n_res_total,n_write_total,n_err_total = AnnotateScaffolds(dbcon,DBSCHEMA,DBSCHEMA_ACTIVITY,ASSAY_ID_TAG,assay_ids,no_write,n_max,n_skip,verbose)
    print >>sys.stderr, "%s: total scaffolds: %d"%(PROG,n_scaf_total)
    print >>sys.stderr, "%s: total compounds: %d"%(PROG,n_cpd_total)
    print >>sys.stderr, "%s: total substances: %d"%(PROG,n_sub_total)
    print >>sys.stderr, "%s: total outcomes: %d"%(PROG,n_res_total)
    print >>sys.stderr, "%s: total scaffold records modified: %d"%(PROG,n_write_total)
    print >>sys.stderr, "%s: total errors: %d"%(PROG,n_err_total)
  else:
    ErrorExit('ERROR: no operation specified.')

  if verbose>0:
    print >>sys.stderr, "%s: total elapsed time: %s"%(PROG,time_utils.NiceTime(time.time()-t0))
    print >>sys.stderr, "%s: %s"%(PROG,time.strftime('%Y-%m-%d %H:%M:%S',time.localtime()))

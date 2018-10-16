#!/usr/bin/env python
#############################################################################
### scaf_assaystats_db_annotate.py
### 
### After badapple database has been otherwise fully populated, with:
###   -> compound table (id, nass_tested, nass_active, nsam_tested, nsam_active )
###   -> scaffold table (id, ... )
###   -> scaf2cpd table (scafid, cid )
###   -> activity table (cid, aid, result )
### 
### Generate assay statistics for scaffold table:
###	ncpd_total	- compounds containing scaffold
###	ncpd_tested	- tested compounds containing scaffold
###	ncpd_active	- active compounds containing scaffold
###	nsam_tested	- samples involving compounds containing scaffold
###	nsam_active	- active samples involving compounds containing scaffold
###	nass_tested	- assays involving compounds containing scaffold
###	nass_active	- assays involving active compounds containing scaffold
### 
### Generate db-global median scaffold statistics for metadata table:
###	median_ncpd_tested - median of scaffold.ncpd_tested
###	median_nass_tested - median of scaffold.nass_tested
###	median_nsam_tested - median of scaffold.nsam_tested
###
### Output (2): activity file, each line:
###   CID AID Outcome
###     where:
###   1 = inactive
###   2 = active
###   3 = inconclusive
###   4 = unspecified
###   5 = probe
###   multiple, differing 1, 2 or 3 = discrepant
###   not 4 = tested
### 
#############################################################################
### To do:
###   [ ] avoid pathological resource-hogging chiltepin-freezing behavior
###   [x] handle and report exceptions, errors
### 
#############################################################################
### Jeremy Yang
###   9 Aug 2012
#############################################################################
import sys,os,getopt,re,time
import pgdb

import badapple_utils

PROG=os.path.basename(sys.argv[0])

SCHEMA='badapple'
DBHOST='localhost'
DBNAME='openchord'
DBUSR='www'
DBPW='foobar'


#############################################################################
def AnnotateScafs(db,schema,no_write,n_max=0,n_skip=0,verbose=0):
  '''Loop over scaffolds.  For each scaffold call AnnotateScaf().'''

  n_scaf_total=0; n_cpd_total=0; n_res_total=0; n_write=0; n_err=0;

  cur=db.cursor()

  sql='''SELECT id FROM %(SCHEMA)s.scaffold ORDER BY id '''%{'SCHEMA':schema}
  cur.execute(sql)

  scaf_rowcount=cur.rowcount  ## use for progress msgs
  if verbose>2:
    print >>sys.stderr, "\tscaf rowcount=%d"%(scaf_rowcount)

  row=cur.fetchone()
  n=0
  while row!=None:
    n+=1
    if n<=n_skip:
      row=cur.fetchone()
      continue
    n_scaf_total+=1
    scafid=row[0]

    if verbose>2:
      print >>sys.stderr, "SCAFID=%4d:"%(scafid)
    t0=time.time()
    ncpd_this,nres_this,ncpd_tested,ncpd_active,nass_tested,nass_active,nsam_tested,nsam_active,ok_write,n_err_this = AnnotateScaf(scafid,db,schema,no_write,verbose)
    if verbose>2:
      print >>sys.stderr, "\tscaf elapsed time: %s (%.1f%% done)"%(badapple_utils.NiceTime(time.time()-t0),100.0*n_scaf_total/scaf_rowcount)

    n_cpd_total+=ncpd_this
    n_res_total+=nres_this
    if ok_write: n_write+=1
    n_err+=n_err_this

    row=cur.fetchone()

    if n_scaf_total==n_max: break

  cur.close()
  db.close()

  return n_scaf_total,n_cpd_total,n_res_total,n_write,n_err

#############################################################################
def AnnotateScaf(scafid,db,schema,no_write,verbose=0):
  '''For this scaffold, loop over compounds.  For each compound, loop over assay results.  Update scaffold row.'''

  ncpd_total=0;
  ncpd_tested=0; ncpd_active=0;
  nsam_tested=0; nsam_active=0;
  nass_tested=0; nass_active=0;
  nres_total=0;
  n_err=0;

  sql='''\
SELECT
	compound.cid,
	compound.nass_tested,
	compound.nass_active,
	compound.nsam_tested,
	compound.nsam_active
FROM
	%(SCHEMA)s.compound,
	%(SCHEMA)s.scaf2cpd
WHERE
	%(SCHEMA)s.scaf2cpd.scafid=%(SCAFID)d
	AND %(SCHEMA)s.scaf2cpd.cid=%(SCHEMA)s.compound.cid
'''%{'SCHEMA':schema,'SCAFID':scafid}
  cur1=db.cursor()
  cur1.execute(sql)
  cpd_rowcount=cur1.rowcount
  if verbose>2:
    print >>sys.stderr, "\tcpd rowcount=%d"%(cpd_rowcount)
  row1=cur1.fetchone()
  assays={} ##store unique aids for this scaffold
  while row1!=None:  ##compound loop
    c_id, c_nass_tested, c_nass_active, c_nsam_tested, c_nsam_active = row1
    ncpd_total+=1
    if c_nass_tested>0: ncpd_tested+=1
    if c_nass_active>0: ncpd_active+=1
    nsam_tested+=c_nsam_tested
    nsam_active+=c_nsam_active

    # Now get results...

    sql='''\
SELECT
	activity.aid,
	activity.result
FROM
	%(SCHEMA)s.activity
WHERE
	%(SCHEMA)s.activity.cid=%(CID)d
'''%{'SCHEMA':schema,'CID':c_id}

    t0=time.time()
    cur2=db.cursor()
    cur2.execute(sql)
    res_rowcount=cur2.rowcount
    if verbose>2:
      print >>sys.stderr, "\tresult rowcount=%d"%(res_rowcount)
    row2=cur2.fetchone()
    #if row2==None: ## No results; normal.
    #  print >>sys.stderr, 'DEBUG: no results for CID: %d'%c_id

    nres_cpd_this=0; nres_cpd_act_this=0;
    nass_cpd_this=0; nass_cpd_act_this=0;
    while row2!=None: ##result loop
      aid, result = row2
      nres_total+=1
      nres_cpd_this+=1
      if result in (2,5):  ##active or probe
        nres_cpd_act_this+=1
        if assays.has_key(aid):
          assays[aid]=True
        else:
          assays[aid]=True
          nass_cpd_this+=1
          nass_cpd_act_this+=1
      elif result in (1,3): ##tested inactive
        if assays.has_key(aid):
          assays[aid]|=False
        else:
          assays[aid]=False
          nass_cpd_this+=1

      row2=cur2.fetchone()

    cur2.close()

    row1=cur1.fetchone()

    if verbose>2:
      print >>sys.stderr, '\t%4d. CID=%4d n_res: %4d ; n_res_act: %4d ; n_ass: %4d ; n_ass_act: %4d'%(ncpd_total,c_id,nres_cpd_this,nres_cpd_act_this,nass_cpd_this,nass_cpd_act_this)
      print >>sys.stderr, "\tcpd elapsed time: %s (%.1f%% done this scaf)"%(badapple_utils.NiceTime(time.time()-t0),100.0*ncpd_total/cpd_rowcount)
 
  cur1.close()

  if verbose>2:
    print >>sys.stderr, '\tn_cpd: %4d ; n_ass: %4d'%(ncpd_total,len(assays))

  for aid in assays.keys():
    nass_tested+=1
    if assays[aid]:
      nass_active+=1

  ## update scaffold row ...

  sql='''\
UPDATE
	%(SCHEMA)s.scaffold
SET
	ncpd_total = %(NCPD_TOTAL)d,
	ncpd_tested = %(NCPD_TESTED)d,
	ncpd_active = %(NCPD_ACTIVE)d,
	nass_tested = %(NASS_TESTED)d,
	nass_active = %(NASS_ACTIVE)d,
	nsam_tested = %(NSAM_TESTED)d,
	nsam_active = %(NSAM_ACTIVE)d
WHERE
	id=%(SCAFID)d
'''%{	'SCHEMA':schema,
	'SCAFID':scafid,
	'NCPD_TOTAL':ncpd_total,
	'NCPD_TESTED':ncpd_tested,
	'NCPD_ACTIVE':ncpd_active,
	'NASS_TESTED':nass_tested,
	'NASS_ACTIVE':nass_active,
	'NSAM_TESTED':nsam_tested,
	'NSAM_ACTIVE':nsam_active}

  ok_write=False
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
    print >>sys.stderr, 'SCAFID=%d,ncpd_total=%d,ncpd_tested=%d,ncpd_active=%d,nass_tested=%d,nass_active=%d,nsam_tested=%d,nsam_active=%d'%(scafid,ncpd_total,ncpd_tested,ncpd_active,nass_tested,nass_active,nsam_tested,nsam_active)

  return ncpd_total,nres_total,ncpd_tested,ncpd_active,nass_tested,nass_active,nsam_tested,nsam_active,ok_write,n_err

#############################################################################
if __name__=='__main__':
  usage='''
  %(PROG)s - annotate badapple scaffold table with activity statistics

  required (one of):
  --annotate ............. write to database
  --no_write ............. do not write to database; for testing

  options:
  --n_max=<NMAX> ......... max scaffolds to annotate
  --n_skip=<NSKIP> ....... skip first N
  --schema=<SCHEMA> ...... [default="%(SCHEMA)s"]
  --dbhost=<DBHOST> ...... 
  --dbname=<DBNAME> ...... 
  --dbusr=<DBUSR> ........ 
  --dbpw=<DBPW> .......... 
  --v .................... verbose
  --vv ................... very verbose
  --vvv .................. very very verbose
  --h .................... this help
'''%{'PROG':PROG,'SCHEMA':SCHEMA}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  verbose=0; n_max=0; n_skip=0; annotate=False; no_write=False;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv','vvv','no_write',
	'dbhost=','dbname=','dbusr=','dbpw=',
	'annotate','n_max=','n_skip=','schema='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--n_max': n_max=int(val)
    elif opt=='--n_skip': n_skip=int(val)
    elif opt=='--annotate': annotate=True
    elif opt=='--no_write': no_write=True
    elif opt=='--schema': SCHEMA=val
    elif opt=='--dbhost': DBHOST=val
    elif opt=='--dbname': DBNAME=val
    elif opt=='--dbusr': DBUSR=val
    elif opt=='--dbpw': DBPW=val
    elif opt=='--v': verbose=1
    elif opt=='--vv': verbose=2
    elif opt=='--vvv': verbose=3
    else: ErrorExit('Illegal option: %s'%val)

  if annotate and no_write:
    ErrorExit('ERROR: --annotate OR --no_write required.')
  elif not (annotate or no_write):
    ErrorExit('ERROR: no operation specified.')

  t0=time.time()
  db,cur = badapple_utils.Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW)
  cur.close()
  n_scaf_total,n_cpd_total,n_res_total,n_write_total,n_err_total = AnnotateScafs(db,SCHEMA,no_write,n_max,n_skip,verbose)

  print >>sys.stderr, "%s: total scaffolds: %d"%(PROG,n_scaf_total)
  print >>sys.stderr, "%s: total compounds: %d"%(PROG,n_cpd_total)
  print >>sys.stderr, "%s: total results: %d"%(PROG,n_res_total)
  print >>sys.stderr, "%s: total scaffold records modified: %d"%(PROG,n_write_total)
  print >>sys.stderr, "%s: total errors: %d"%(PROG,n_err_total)
  if verbose>0:
    print >>sys.stderr, "%s: total elapsed time: %s"%(PROG,badapple_utils.NiceTime(time.time()-t0))


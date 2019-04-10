#!/usr/bin/env python
'''
	ABBA (Activity Bitvector Based Analysis) fingerprint generator.

	Jeremy Yang
	11 Oct 2012
'''
import os,sys,getopt,re,time
import pgdb

import badapple_utils

PROG=os.path.basename(sys.argv[0])

DBSCHEMA='badapple'
DBHOST='localhost'
DBNAME='openchord'
DBUSR='www'
DBPW='foobar'

#############################################################################
if __name__=='__main__':

  usage='''
  %(PROG)s - ABBA (Activity Bitvector Based Analysis) fingerprint generator.

  Special purpose app generates activity FPs for each CID (compound) in
  activity table of database.  FP bitmap length is the number of assays
  (AIDs) in table.

  Relies on BADAPPLE promiscuity analysis data.

  required:
  --o=<OFILE> .............. output file (format "CID FP")

  options:
  --o_aid=<OFILE_AID> ...... output file of assay IDs in bitvector order
  --dbschema=<DBSCHEMA> .... [default="%(DBSCHEMA)s"]
  --dbhost=<DBHOST> ........ [default="%(DBHOST)s"]
  --dbname=<DBNAME> ........ [default="%(DBNAME)s"]
  --dbusr=<DBUSR> .......... 
  --dbpw=<DBPW> ............ 
  --nmax=<NMAX> ............ quit after NMAX (mostly for testing)
  --v ...................... verbose
  --h ...................... this help
'''%{'PROG':PROG,'DBSCHEMA':DBSCHEMA,'DBHOST':DBHOST,'DBNAME':DBNAME}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  verbose=0;
  ofile=None;
  ofile_aid=None;
  nmax=0;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv',
	'o=','o_aid=','nmax=','dbhost=','dbname=','dbusr=','dbpw=','dbschema='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--o': ofile=val
    elif opt=='--o_aid': ofile_aid=val
    elif opt=='--dbschema': DBSCHEMA=val
    elif opt=='--dbhost': DBHOST=val
    elif opt=='--dbname': DBNAME=val
    elif opt=='--dbusr': DBUSR=val
    elif opt=='--dbpw': DBPW=val
    elif opt=='--nmax': nmax=int(val)
    elif opt=='--vv': verbose=2
    elif opt=='--v': verbose=1
    else: ErrorExit('Illegal option: %s'%val)

  if not ofile:
    ErrorExit('-o required')

  print 'database: %s:%s:%s'%(DBHOST,DBNAME,DBSCHEMA)

  db,cur = badapple_utils.Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW)
  cur.close()

  fout=open(ofile,"w")
  if not fout:
    ErrorExit('ERROR: could not open %s'%ofile)

  fout_aid=None
  if ofile_aid:
    fout_aid=open(ofile_aid,"w")
    if not fout_aid:
      ErrorExit('ERROR: could not open %s'%ofile_aid)

  badapple_utils.abbafp_dump(db,DBSCHEMA,nmax,fout,fout_aid,verbose)

  fout.close()
  if fout_aid:
    fout_aid.close()
  db.close()

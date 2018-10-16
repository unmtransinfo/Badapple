#!/usr/bin/env python
'''
	Badapple promiscuity client.

	Currently handles scaffold scores only, since ChemAxon JChem HScaf not accesible via Python.

	Jeremy Yang
	 2 Jun 2014
'''
import os,sys,getopt,re,time,types

import badapple_utils

PROG=os.path.basename(sys.argv[0])

DBHOST='localhost'
#DBHOST='carlsbad.health.unm.edu'
#DBSCHEMA='badapple2'
DBSCHEMA='public'
DBNAME='badapple'
DBUSR='www'
DBPW='foobar'

NMAX=100;
ASSAY_ID_TAG='aid'

#############################################################################
if __name__=='__main__':
  usage='''
  %(PROG)s - Badapple promiscuity scoring and database utility (PostgreSQL client)

operations (one of):
  --getdata ................ get scaffold scores, etc. for input IDs or SMILES
  --describeschema ......... describe schema
  --tablecounts ............ table row counts
  --assaycount ............. assay count (requires activity table)
  --scafcount .............. scaffold count (and scoreless count)
  --summary ................ summarize contents
  --info ................... show info (metadata)
  --topscores .............. top scaffolds
  --topscores_compare ...... top scaffolds, compare scores
  --scaf_assay_matrix ...... extract scaf-vs-assay activity matrix 

i/o:
  --scafid ID ..............
  --scafsmi SMILES .........
  --scafidfile IDFILE ...... file of scaffold IDs
  --scafsmifile SMIFILE .... file of scaffold SMILES
  --assayids IDFILE ........ file of assay IDs
  --o OFILE ................ output file (usually CSV)

parameters:
  --assay_id_tag TAG ....... [%(ASSAY_ID_TAG)s]
  --nmax NMAX .............. for topscores [%(NMAX)d] (NMAX=0 means all)
  --non_null ............... only consider non_null scores/scaffolds, i.e. w/ evidence
  --non_zero ............... only consider non_zero scores/scaffolds (implies non_null)

options:
  --dbschema DBSCHEMA ...... [default="%(DBSCHEMA)s"]
  --dbschema2 DBSCHEMA2 .... for compare operations
  --dbhost DBHOST .......... [default="%(DBHOST)s"]
  --dbname DBNAME .......... [default="%(DBNAME)s"]
  --dbusr DBUSR ............ [default="%(DBUSR)s"]
  --dbpw DBPW .............. 
  --v ...................... verbose
  --h ...................... this help
'''%{'PROG':PROG,'DBHOST':DBHOST,'DBSCHEMA':DBSCHEMA,'DBNAME':DBNAME,'DBUSR':DBUSR,'NMAX':NMAX,
	'ASSAY_ID_TAG':ASSAY_ID_TAG}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  verbose=0;
  describeschema=False;
  info=False;
  non_zero=False;
  non_null=False;
  summary=False;
  tablecounts=False;
  assaycount=False;
  scafcount=False;
  test=False;
  getdata=False;
  scaf_assay_matrix=False;
  show_load_rate=False;
  scafid=None; scafsmi=None;
  topscores=False;
  topscores_compare=False;
  dbschema2=None;
  isomeric=False;
  scafidfile=None;
  scafsmifile=None;
  aidfile=None;
  ofile=None;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv','o=',
	'dbschema=','dbhost=','dbname=','dbusr=','dbpw=',
	'dbschema2=',
	'getdata','topscores',
	'topscores_compare',
	'nmax=',
	'assay_id_tag=',
	'scafidfile=',
	'scafsmifile=',
	'assayids=',
	'scafid=','scafsmi=',
	'scaf_assay_matrix',
	'assaycount',
	'scafcount',
	'non_zero',
	'non_null',
	'info','summary','describeschema','tablecounts','isomeric','test'])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--scafidfile': scafidfile=val
    elif opt=='--scafsmifile': scafsmifile=val
    elif opt=='--assayids': aidfile=val
    elif opt=='--o': ofile=val
    elif opt=='--scafid': scafid=int(val)
    elif opt=='--scafsmi': scafsmi=val
    elif opt=='--getdata': getdata=True
    elif opt=='--scaf_assay_matrix': scaf_assay_matrix=True
    elif opt=='--describeschema': describeschema=True
    elif opt=='--tablecounts': tablecounts=True
    elif opt=='--assaycount': assaycount=True
    elif opt=='--scafcount': scafcount=True
    elif opt=='--info': info=True
    elif opt=='--summary': summary=True
    elif opt=='--topscores': topscores=True
    elif opt=='--topscores_compare': topscores_compare=True
    elif opt=='--nmax': NMAX=int(val)
    elif opt=='--assay_id_tag': ASSAY_ID_TAG=val
    elif opt=='--test': test=True
    elif opt=='--non_zero': non_zero=True
    elif opt=='--non_null': non_null=True
    elif opt=='--isomeric': isomeric=True
    elif opt=='--dbschema': DBSCHEMA=val
    elif opt=='--dbschema2': dbschema2=val
    elif opt=='--dbhost': DBHOST=val
    elif opt=='--dbname': DBNAME=val
    elif opt=='--dbusr': DBUSR=val
    elif opt=='--dbpw': DBPW=val
    elif opt=='--vv': verbose=2
    elif opt=='--v': verbose=1
    else: ErrorExit('Illegal option: %s'%val)

  print 'database: %s:%s:%s'%(DBHOST,DBNAME,DBSCHEMA)

  if ofile:
    fout=open(ofile,"w+")
    if not fout: ErrorExit('ERROR: cannot open outfile: %s'%ofile)
  else:
    fout=sys.stdout

  dbcon = badapple_utils.Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW)

  aids=[]
  if aidfile:
    fin=open(aidfile)
    if not fin: ErrorExit('ERROR: cannot open aidfile: %s'%aidfile)
    while True:
      line=fin.readline()
      if not line: break
      try:
        aids.append(int(line.rstrip()))
      except:
        print >>sys.stderr, 'ERROR: bad input EID: %s'%line
        continue
    if verbose:
      print >>sys.stderr, '%s: input EIDs: %d'%(PROG,len(aids))
    fin.close()

  scafids=[]
  if scafidfile:
    fin=open(scafidfile)
    if not fin: ErrorExit('ERROR: cannot open scafidfile: %s'%scafidfile)
    while True:
      line=fin.readline()
      if not line: break
      try:
        scafids.append(int(line.rstrip()))
      except:
        print >>sys.stderr, 'ERROR: bad input ID: %s'%line
        continue
    if verbose:
      print >>sys.stderr, '%s: input scaf IDs: %d'%(PROG,len(scafids))
    fin.close()
  elif scafid:
    scafids=[scafid]

  scafsmis=[]
  if scafsmifile:
    fin=open(scafsmifile)
    if not fin: ErrorExit('ERROR: cannot open scafsmifile: %s'%scafsmifile)
    while True:
      line=fin.readline()
      if not line: break
      if line.rstrip():
        scafsmis.append(line.rstrip())
    if verbose:
      print >>sys.stderr, '%s: input scaf SMILESs: %d'%(PROG,len(scafsmis))
    fin.close()
  elif scafsmi:
    scafsmis=[scafsmi]

  if scafsmis and not scafids:
    n_found=0;
    for i,scafsmi in enumerate(scafsmis):
      if verbose>1:
        print >>sys.stderr, "scafsmi:",scafsmi, 
      scafid = badapple_utils.ScafSmi2Id(DBSCHEMA,scafsmi,isomeric,dbcon,verbose)
      if scafid:
        n_found+=1
        scafids.append(scafid)
        if verbose>1:
          print >>sys.stderr, '\tscafid: %d'%(scafid)
      else:
        print >>sys.stderr, '\t[%d] scafsmi not found: %s'%((i+1),scafsmi)
    print >>sys.stderr, '%s: scafsmis: %d,  found: %d'%(PROG,len(scafsmis),n_found)


  if getdata:
    if scafids:
      n_found=0;
      for i,scafid in enumerate(scafids):
        row=badapple_utils.ScafIdLookup(DBSCHEMA,scafid,dbcon,verbose)
        if row:
          if i==0: fout.write('id,'+(','.join(sorted(row.keys())))+'\n')
          fout.write(
		(','.join(map(lambda x:(('"%s"'%x) if type(x) in types.StringTypes else str(x)),[scafid]+
			[row[key] for key in sorted(row.keys())]
		)))
		+'\n')
          if verbose>1:
            print >>sys.stderr, '%s %d %d'%(row['scafsmi'],scafid,row['pscore'])
          n_found+=1
        else:
          print >>sys.stderr, '\t[%d] scafid not found.'%(i+1)
      print >>sys.stderr, '%s: scafids: %d,  found: %d'%(PROG,len(scafids),n_found)
    else:
      ErrorExit('ERROR: --getdata requires scaf ID[s] or SMILES[s].')

  elif scaf_assay_matrix:
    #badapple_utils.ScafVsAssayMatrix(DBSCHEMA,dbcon,scafids,aids,ASSAY_ID_TAG,fout,verbose)
    badapple_utils.ScafScoreVsAssayMatrix(DBSCHEMA,dbcon,scafids,aids,ASSAY_ID_TAG,fout,verbose)

  elif describeschema:
    print badapple_utils.DescribeSchema(DBSCHEMA,dbcon)

  elif tablecounts:
    print badapple_utils.DescribeCounts(DBSCHEMA,dbcon)

  elif assaycount:
    print badapple_utils.AssayCount(DBSCHEMA,dbcon,ASSAY_ID_TAG)

  elif scafcount:
    badapple_utils.ScaffoldCount(DBSCHEMA,dbcon)
    
  elif topscores:
    badapple_utils.TopScores(DBSCHEMA,dbcon,NMAX,fout,verbose)

  elif topscores_compare:
    if not dbschema2: ErrorExit('ERROR: --topscores_compare requires --dbschema2.')
    non_null |= non_zero
    badapple_utils.TopScores_Compare(DBSCHEMA,dbschema2,dbcon,NMAX,non_null,non_zero,fout,verbose)

  elif info:
    desc,ts,median_cTested,median_sTested,median_aTested,median_wTested=badapple_utils.GetMetadata(DBSCHEMA,dbcon)
    print ('%s [created: %s]'%(desc,ts))
    print "Description:",desc
    print "Timestamp:",ts
    print "median_cTested:",median_cTested
    print "median_sTested:",median_sTested
    print "median_aTested:",median_aTested
    print "median_wTested:",median_wTested

  elif summary:
    print badapple_utils.Summary(DBSCHEMA,dbcon)

  elif test:
    Test(DBSCHEMA,isomeric,dbcon,verbose)

  else:
    ErrorExit('ERROR: No operation specified.')

  dbcon.close()


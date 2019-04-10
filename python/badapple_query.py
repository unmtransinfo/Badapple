#!/usr/bin/env python
#############################################################################
### badapple_query.py
### 
### 
### Jeremy Yang
###  20 Sep 2015
#############################################################################
import sys,os,re,getopt,time,types,codecs
import urllib,urllib2,httplib
import json

import time_utils
import rest_utils
#
API_HOST='pasilla.health.unm.edu'
BASE_PATH='/tomcat/bardplugins/badapple'
API_BASE_URL='http://'+API_HOST+BASE_PATH
#
##############################################################################
def Analyze(base_url, qrys, fout, verbose):
  n_mol=0; n_found=0;
  fout.write('query,score,scafid,scafsmi\n')
  for qry in qrys:
    n_mol+=1;
    url=(base_url+'/prom/analyze?smiles=%s'%urllib2.quote(qry,''))
    try:
      rval=rest_utils.GetURL(url,parse_json=True,verbose=verbose)
    except urllib2.HTTPError, e:
      print >>sys.stderr, 'HTTP Error: %s'%(e)

    if type(rval) is not types.DictType:
      print >>sys.stderr, 'DEBUG: ERROR: rval = "%s"'%str(rval)
      break

    highscore = rval['highscore'] if rval.has_key('highscore') else 0
    query = rval['query'] if rval.has_key('query') else None
    hscafs = rval['hscafs'] if rval.has_key('hscafs') else []
    pscore_high=0; scafsmi_high=''; scafid_high=0;
    for hscaf in hscafs:
      if hscaf['pScore']> pscore_high:
        pscore_high = hscaf['pScore']
        scafsmi_high = hscaf['smiles']
        scafid_high = hscaf['scafid']

    fout.write('"%s",%d,%d,"%s"\n'%(query,pscore_high,scafid_high,scafsmi_high))
    if scafid_high: n_found+=1

  print >>sys.stderr, 'molecules processed: %d'%n_mol
  print >>sys.stderr, 'molecules with scaffolds found: %d'%n_found


##############################################################################
if __name__=='__main__':
  PROG=os.path.basename(sys.argv[0])
  usage='''\
%(PROG)s - Badapple REST client

operations (one of):
	--show_info ................. show db metadata
	--analyze ................... analyze input molecules (SMILES)

options:
	--query QRY ................. SMILES (molecule or scaffold)
	--qfile QFILE ............... query file
	--o OFILE ................... output file (CSV)
	--api_host HOST ............. [%(API_HOST)s]
	--v[v[v]] ................... verbose [very [very]]
	--h ......................... this help

'''%{	'PROG':PROG,
	'API_HOST':API_HOST
	}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  ofile=None;
  qfile=None;
  query=None;

  show_info=False; 
  analyze=False; 
  verbose=0;
  opts,pargs=getopt.getopt(sys.argv[1:],'',['o=','qfile=',
    'show_info',
    'analyze',
    'query=',
    'api_host=',
    'help','v','vv','vvv'])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--help': ErrorExit(usage)
    elif opt=='--show_info': show_info=True
    elif opt=='--analyze': analyze=True
    elif opt=='--qfile': qfile=val
    elif opt=='--query': query=val
    elif opt=='--o': ofile=val
    elif opt=='--api_host': API_HOST=val
    elif opt=='--api_key': API_KEY=val
    elif opt=='--v': verbose=1
    elif opt=='--vv': verbose=2
    elif opt=='--vvv': verbose=3
    else: ErrorExit('Illegal option: %s\n%s'%(opt,usage))

  API_BASE_URL='http://'+API_HOST+BASE_PATH

  if ofile:
    fout=codecs.open(ofile,"w","utf8","replace")
    if not fout: ErrorExit('ERROR: cannot open outfile: %s'%ofile)
  else:
    fout=codecs.getwriter('utf8')(sys.stdout,errors="replace")

  t0=time.time()
  
  qrys=[];
  if qfile:
    fin=open(qfile)
    if not fin: ErrorExit('ERROR: cannot open qfile: %s'%qfile)
    while True:
      line=fin.readline()
      if not line: break
      if line.rstrip(): qrys.append(line.rstrip())
    if verbose:
      print >>sys.stderr, '%s: input queries: %d'%(PROG,len(qrys))
    fin.close()
  elif query:
    qrys.append(query)

  if show_info:
    rval=rest_utils.GetURL(API_BASE_URL+'/_info',verbose=verbose)
    print rval

  elif analyze:
    if not qrys:  ErrorExit('ERROR: query smiles[s] required.')
    Analyze(API_BASE_URL, qrys, fout, verbose)

  else:
    ErrorExit("No operation specified.")

  if ofile:
    fout.close()

  if verbose:
    print >>sys.stderr, ('%s: elapsed time: %s'%(PROG,time.strftime('%Hh:%Mm:%Ss',time.gmtime(time.time()-t0))))

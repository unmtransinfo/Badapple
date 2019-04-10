#!/usr/bin/env python
#############################################################################
### cpdscaf_2csv.py
###
### Input: compound file from hier_scaffolds w/ scaffold list for each compound.
### Output: csv to populate scaf2cpd table.
###
### input columns:
###   smiles cid S:scafidlist
### output columns:
###   scafid,cid
###
### Jeremy Yang
###  7 Dec 2012
#############################################################################
import sys,os,getopt,re

PROG=os.path.basename(sys.argv[0])

#############################################################################
if __name__=='__main__':

  usage='''
  %(PROG)s - hscaf cpd-scaf output to CSV

  required:
  --i INFILE ................... input file
  --o OUTFILE .................. output CSV file
  options:
  --v .......................... verbose
  --h .......................... this help
'''%{'PROG':PROG}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  ifile=None; ofile=None; 
  verbose=0;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv', 'i=','o=','dbschema='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--i': ifile=val
    elif opt=='--o': ofile=val
    elif opt=='--dbschema': DBSCHEMA=val
    elif opt=='--v': verbose=1
    else: ErrorExit('Illegal option: %s'%val)

  fin=file(ifile)
  if not fin:
    ErrorExit('ERROR: cannot open %s'%ifile)
  fout=file(ofile,"w")
  if not fout:
    ErrorExit('ERROR: cannot open %s'%ofile)

  fout.write('scafid,cid\n')
  
  n_lines=0; n_inserts=0;
  n_noscaf=0; n_err=0;
  while True:
    line=fin.readline()
    if not line: break
    line=line.strip()
    if not line or line[0]=='#': continue
    n_lines+=1
    fields=re.split('\s',line)
  
    try:
      cid=int(fields[1])
    except:
      print >>sys.stderr, "ERROR: Bad line (cid): %s"%line
      n_err+=1
      continue
  
    if len(fields)<3:
      if verbose>0:
        print >>sys.stderr, "no scafs [%d]: CID=%d"%(n_lines,cid)
      n_noscaf+=1
      continue
  
    if not re.match(r'S:',fields[2]):
      print >>sys.stderr, "ERROR: Bad line (scafids): %s"%line
      n_err+=1
      continue
  
    scafids=re.split(',',re.sub('^S:','',fields[2] ))
    if not scafids:
      continue
  
    for scafid in scafids:
      if not scafid: continue
      try:
        scafid=int(scafid)
      except:
        continue
      fout.write('%d,%d\n'%(scafid,cid))
      n_inserts+=1
      
  fout.close()
  print >>sys.stderr, "%s: input data lines: %d"%(PROG,n_lines)
  print >>sys.stderr, "%s: output lines: %d"%(PROG,n_inserts)
  print >>sys.stderr, "%s: cpds w/ no scafs: %d"%(PROG,n_noscaf)
  print >>sys.stderr, "%s: errors: %d"%(PROG,n_err)

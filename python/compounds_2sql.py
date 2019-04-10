#!/usr/bin/env python
#############################################################################
## compounds_2sql.py
##
## input columns:
##   smiles cid
##
## Jeremy Yang
##  13 Jan 2017
#############################################################################
import sys,os,getopt,re

PROG=os.path.basename(sys.argv[0])

#############################################################################
if __name__=='__main__':

  DBSCHEMA='public'

  usage='''
%(PROG)s - compounds to SQL

required:
  --i INFILE ................... input file

options:
  --o OUTFILE .................. output file [stdout]
  --dbschema DBSCHEMA .......... [default="%(DBSCHEMA)s"]
  --nmax NMAX .................. quit after NMAX cpds
  --nskip NSKIP ................ skip first NSKIP cpds
  --v .......................... verbose
  --h .......................... this help
'''%{'PROG':PROG,'DBSCHEMA':DBSCHEMA}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  ifile=None; ofile=None; update=False;
  nmax=0; nskip=0;
  verbose=0;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv',
        'i=','o=','nmax=','nskip=','dbschema='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--i': ifile=val
    elif opt=='--o': ofile=val
    elif opt=='--dbschema': DBSCHEMA=val
    elif opt=='--nmax': nmax=int(val)
    elif opt=='--nskip': nskip=int(val)
    elif opt=='--vv': verbose=2
    elif opt=='--v': verbose=1
    else: ErrorExit('Illegal option: %s'%val)

  fin=file(ifile)
  if not fin:
    ErrorExit('ERROR: cannot open %s'%ifile)
  if ofile:
    fout=file(ofile,"w")
  else:
    fout=sys.stdout

  n_in=0
  n_out=0
  n_err=0
  while True:
    line=fin.readline()
    if not line: break
    n_in+=1
    if nskip>0 and n_in<=nskip:
      continue
    line=line.strip()
    if not line or line[0]=='#': continue
    fields=re.split('\s',line)
    if len(fields)<2:
      print >>sys.stderr, "Bad line: %s"%line
      n_err+=1
      continue

    smi=fields[0]
    smi=re.sub(r'\\',r"'||E'\\\\'||'",smi)
    fout.write("INSERT INTO %s.compound (cid,isosmi,cansmi) VALUES (%s,'%s','');\n"
	%(DBSCHEMA,fields[1],smi))
    n_out+=1
    if nmax>0 and (n_in-nskip)>=nmax:
      break

  fin.close()
  fout.close()
  print >>sys.stderr, "%s: lines in: %d ; converted to sql: %d"%(PROG,n_in,n_out)
  print >>sys.stderr, "%s: errors: %d"%(PROG,n_err)

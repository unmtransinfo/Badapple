#!/usr/bin/env python
#############################################################################
## drug_scafs_2sql.py
##
## Input smiles file SMILES<space>NAME.
##
## Jeremy Yang
##  18 Jan 2017
#############################################################################
import sys,os,getopt,re

PROG=os.path.basename(sys.argv[0])

#############################################################################
if __name__=='__main__':

  DBSCHEMA='public'
  CHEMKIT='rdkit'

  usage='''
  %(PROG)s - drug scaffolds, for inDrug annotation, to SQL UPDATEs

  required:
  --i INFILE ................... input file

  options:
  --o OUTFILE .................. output file [stdout]
  --dbschema DBSCHEMA .......... [%(DBSCHEMA)s]
  --chemkit CHEMKIT ............ rdkit|openchord [%(CHEMKIT)s]
  --v .......................... verbose
  --h .......................... this help
'''%{'PROG':PROG,'DBSCHEMA':DBSCHEMA,'CHEMKIT':CHEMKIT}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  ifile=None; ofile=None; 
  verbose=0;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv', 'i=','o=','dbschema=',
	'chemkit='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--i': ifile=val
    elif opt=='--o': ofile=val
    elif opt=='--dbschema': DBSCHEMA=val
    elif opt=='--chemkit': CHEMKIT=val
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
  while True:
    line=fin.readline()
    if not line: break
    n_in+=1
    line=line.strip()
    if not line or line[0]=='#': continue
    fields=re.split('\s',line)

    smi=fields[0]
    smi=re.sub(r'\\',r"'||E'\\\\'||'",smi)
    fout.write("UPDATE %s.scaffold SET in_drug=TRUE "%DBSCHEMA)
    if CHEMKIT=='openchord':
      fout.write("WHERE scafsmi=openbabel.cansmiles('%s');\n"%smi)
    else:
      fout.write("FROM mols_scaf WHERE mols_scaf.scafmol @= '%s'::mol AND scaffold.id = mols_scaf.id;\n"%smi)
    n_out+=1

  fin.close()
  if ofile:
    fout.close()
  print >>sys.stderr, "%s: lines in: %d ; converted to sql: %d"%(PROG,n_in,n_out)

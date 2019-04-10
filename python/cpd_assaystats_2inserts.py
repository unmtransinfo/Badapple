#!/usr/bin/env python
#############################################################################
## cpd_assaystats_2inserts.py
##
## input columns:
##   cid smiles isosmi aTested aActive sTested sActive
##
## This rev for pgsql 
###smiles cid aTested aActive sTested sActive
##
##
## Jeremy Yang
##   7 Dec 2010
#############################################################################
import sys,os,re

PROG=os.path.basename(sys.argv[0])

if len(sys.argv)<4:
  print "syntax: %s <SCHEMA> <ASSAYSTATS> <INSERTSQL>"%(PROG)
  sys.exit()

schema=sys.argv[1]
fin=file(sys.argv[2])
fout=file(sys.argv[3],"w")

n_lines=0
while True:
  line=fin.readline()
  if not line: break
  line=line.strip()
  if not line or line[0]=='#': continue
  fields=re.split('\s',line)
  if len(fields)!=6:
    print >>sys.stderr, "Bad line: %s"%line
    continue

  smi=fields[0]
  smi=re.sub(r'\\',r"'||E'\\\\'||'",smi)
  fout.write("INSERT INTO %s.compound (cid,cansmi,isosmi,nass_tested,nass_active,nsam_tested,nsam_active) VALUES\n"%schema)
  fout.write("\t(%s,\n"%fields[1])
  fout.write("\topenbabel.cansmiles('%s'),\n"%smi)
  fout.write("\topenbabel.isosmiles('%s'),\n"%smi)
  fout.write("\t%s, %s, %s, %s);\n"%(fields[2],fields[3],fields[4],fields[5]))
  n_lines+=1

fout.close()
print >>sys.stderr, "%s: lines converted to inserts: %d"%(PROG,n_lines)

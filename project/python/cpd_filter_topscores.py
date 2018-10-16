#!/usr/bin/env python
#############################################################################
### Filter output of edu.unm.health.biocomp.badapple.badapple output file containing
### compounds and data including scores.  Example line:
### OC(=O)C(F)(F)F.CCOC(=O)C1CCN(CC1)C(=O)C(C)(C)NC(=O)NC1=CC(F)=C(F)C=C1   60138128 19,24 1250.5,0.0 C1CCCNC1,O=C(NCC(=O)N1CCCCC1)Nc1ccccc1
#############################################################################
import sys,os,re

PROG=os.path.basename(sys.argv[0])

SCORE_CUTOFF=4000.0

n_in,n_out,n_noscore,n_err = 0,0,0,0

while True:
  line=sys.stdin.readline()
  if not line: break
  line=line.strip()
  n_in+=1
  fields=re.split(r'\s',line)
  if len(fields)<5:
    #print >>sys.stderr, "NOTE: [%d] no scores/scaffolds \"%s\""%(n_in,line)
    n_noscore+=1
    continue

  topscore=re.sub(',.*$','',fields[3])
  try:
    topscore=float(topscore)
  except:
    print >>sys.stderr, "ERROR: [%d] unparseable score \"%s\""%(n_in,line)
    n_err+=1
    continue

  if topscore>SCORE_CUTOFF:
    print "%s %.2f"%(' '.join(fields),topscore)  ## redundant topscore for spreadsheet sorting
    n_out+=1


print >>sys.stderr, "%s: n_in: %d"%(PROG,n_in)
print >>sys.stderr, "%s: n_out: %d"%(PROG,n_out)
print >>sys.stderr, "%s: n_noscore: %d"%(PROG,n_noscore)
print >>sys.stderr, "%s: n_err: %d"%(PROG,n_err)

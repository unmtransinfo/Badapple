#!/usr/bin/env python
'''
Input: (1) AID file, (2) Activity CSV file

How many activity values in CSV file are for assays in AID file.

#pc_mlp_selected_assays_pre-20110101.aid
#pc_mlsmr_assaystats_act.csv.gz
'''
#############################################################################
import sys,os,getopt,gzip,csv

import csv_utils

AID_TAG='aid'

PROG=os.path.basename(sys.argv[0])

#############################################################################
if __name__=='__main__':
  usage='''
  %(PROG)s - 

  required:
  --i_act IFILE ................ input activity CSV file
  --i_aid IFILE ................ input assay ID file

  parameters:
  --aid_tag TAG ................ [%(AID_TAG)s]

  options:
  --v .......................... verbose
  --h .......................... help
'''%{'PROG':PROG,'AID_TAG':AID_TAG}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  verbose=0; ifile_act=None; ifile_aid=None;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','i_act=','i_aid=','aid_tag='])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--i_act': ifile_act=val
    elif opt=='--i_aid': ifile_aid=val
    elif opt=='--aid_tag': AID_TAG=val
    elif opt=='--v': verbose=1
    else: ErrorExit('Illegal option: %s'%val)

  if not ifile_aid:
    ErrorExit("%s: ERROR: --i_aid required."%PROG)

  n_aid=0
  aids=set()
  fin_aid=open(ifile_aid)
  if not fin_aid: ErrorExit('ERROR: cannot open: %s'%ifile_aid)
  while True:
    line=fin_aid.readline()
    if not line: break
    try:
      aids.add(int(line.rstrip()))
      n_aid+=1
    except:
      print >>sys.stderr, 'ERROR: bad input AID: %s'%line
      continue
  if verbose:
    print >>sys.stderr, '%s: input AIDs: %d, unique: %d'%(PROG,n_aid,len(aids))
  fin_aid.close()

  if not ifile_act:
    ErrorExit("%s: ERROR: --i_act required."%PROG)

  if ifile_act[-3:]=='.gz':
    if verbose: print >>sys.stderr, 'gzip input file'
    fin_act = gzip.open(ifile_act)
  else:
    fin_act = open(ifile_act)


  csvReader=csv.DictReader(fin_act,fieldnames=None,restkey=None,restval=None,dialect='excel',delimiter=',',quotechar='"')

  n_in=0; n_data=0; n_data_ok=0; aid_col=0;
  while True:
    try:
      csvrow=csvReader.next()
      n_in+=1
      if n_in==1:
        if verbose: print >>sys.stderr, 'tags:  %s'%(','.join(csvReader.fieldnames))
        for j,coltag in enumerate(csvReader.fieldnames):
          if coltag==AID_TAG: aid_col = j+1
        if aid_col<1:
          ErrorExit('aid_tag "%s" not found, tags: %s'%(AID_TAG,(','.join(csvReader.fieldnames))))
        else:
          if verbose: print >>sys.stderr, 'aid_tag col: %d'%(aid_col)
        continue #skip header
    except Exception, e:
      if verbose: print >>sys.stderr, 'DEBUG: %s'%str(e)
      break
    aid = int(csvrow[csvReader.fieldnames[aid_col-1]])
    n_data+=1
    if n_data%1000000==0:
      print >>sys.stderr, '%.3g / %6g (%4.1f%%)...'%(n_data_ok,n_data,100.0*n_data_ok/n_data)
    if aid in aids:
      n_data_ok+=1

  print >>sys.stderr, '%s: n_data: %d, n_data_ok: %d (%.1f%%)'%(PROG,n_data,n_data_ok,100.0*n_data_ok/n_data)

#!/usr/bin/env python
'''
	Badapple utility functions.

	Jeremy Yang
	30 Jan 2013
'''
import os,sys,getopt,re,time
import MySQLdb
import openbabel

PROG=os.path.basename(sys.argv[0])

DBHOST='localhost'
#DBHOST='carlsbad.health.unm.edu'
DBNAME='badapple'
DBUSR='www'
DBPW='foobar'

#############################################################################
def Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW):
  '''Connect to BADAPPLE database.'''
  #dsn='%s:%s:%s:%s'%(dbhost,dbname,dbusr,dbpw)
  #db=MySQLdb.connect(dsn=dsn)
  db=MySQLdb.connect(host=DBHOST,user=DBUSR,passwd=DBPW,db=DBNAME)
  cur=db.cursor()
  return db,cur

#############################################################################
def ListTables(dbname,dbcon=None):
  if dbcon:
    db=dbcon
    cur=db.cursor()
  else:
    db,cur = Connect()
  cur.execute('SHOW TABLES ;')
  rows=cur.fetchall()
  tables=[]
  for row in rows:
    tables.append(row[0])
  tables.sort()
  return tables

#############################################################################
def Describe(dbname,dbcon=None):
  if dbcon:
    db=dbcon
    cur=db.cursor()
  else:
    db,cur = Connect()
  cur.execute('SHOW TABLES ;')
  rows=cur.fetchall()
  tables=ListTables(dbname,db)
  outtxt=''
  for table in tables:
    outtxt+=('%s:\n'%table)
    cur.execute('DESCRIBE '+table+';')
    rows2=cur.fetchall()
    outtxt+=Table2Str(rows2)
  return outtxt

#############################################################################
def Table2Str(t):
  outtxt=''
  for row in t:
    for cell in row:
      outtxt+=("%18s"%cell)
    outtxt+=("\n")
  return outtxt

#############################################################################
def DescribeCounts(dbname,dbcon=None):
  if dbcon:
    db=dbcon
    cur=db.cursor()
  else:
    db,cur = Connect()
  cur.execute('SHOW TABLES ;')
  rows=cur.fetchall()
  tables=ListTables(dbname,db)
  outtxt=''
  for table in tables:
    cur.execute('SELECT count(*) FROM '+table+';')
    rows2=cur.fetchall()
    outtxt+=('%s: %d rows\n'%(table,rows2[0][0]))
  return outtxt

#############################################################################
def GetMetadata(dbname,dbcon=None):
  '''Return tuple of metadata from metadata table.'''
  desc,ts,median_cTested,median_sTested,median_aTested,median_wTested=(None,None,0,0,0,0)
  if dbcon:
    db=dbcon
    cur=db.cursor()
  else:
    db,cur = Connect()
  sql=("select db_description,db_date_built,median_ncpd_tested,median_nsub_tested,median_nass_tested,median_nsam_tested from %s.metadata"%dbname)
  cur.execute(sql)
  rows=cur.fetchall()	##data rows
  if not rows:
    print >>sys.stderr, "ERROR: metadata not found in database."
  elif not len(rows[0])==6:
    print >>sys.stderr, "ERROR: metadata field count error."
  else:
    desc=rows[0][0]
    ts=rows[0][1]
    try:
      median_cTested=int(rows[0][2])
      median_sTested=int(rows[0][3])
      median_aTested=int(rows[0][4])
      median_wTested=int(rows[0][5])
    except:
      pass
  cur.close()
  if not dbcon:
    db.close()
  return desc,ts,median_cTested,median_sTested,median_aTested,median_wTested

#############################################################################
if __name__=='__main__':

  usage='''
  %(PROG)s - 

  required:
  --describe .......... describe db %(DBNAME)s ; summarize contents
  --tablecounts ....... table row counts for db %(DBNAME)s 
  --info .............. show info (metadata) for db %(DBNAME)s 
  --test .............. 
  --v            ... verbose
  --h            ... this help
'''%{'PROG':PROG,'DBNAME':DBNAME}

  def ErrorExit(msg):
    print >>sys.stderr,msg
    sys.exit(1)

  verbose=0;
  describe=False;
  info=False;
  tablecounts=False;
  test=False;
  opts,pargs = getopt.getopt(sys.argv[1:],'',['h','v','vv',
  'info','describe','tablecounts','test','show_load_rate'])
  if not opts: ErrorExit(usage)
  for (opt,val) in opts:
    if opt=='--h': ErrorExit(usage)
    elif opt=='--describe': describe=True
    elif opt=='--tablecounts': tablecounts=True
    elif opt=='--info': info=True
    elif opt=='--test': test=True
    elif opt=='--vv': verbose=2
    elif opt=='--v': verbose=1
    else: ErrorExit('Illegal option: %s'%val)

  if not (describe or tablecounts or info or test):
    ErrorExit('ERROR: No operation specified.')

  db,cur = Connect(dbhost=DBHOST,dbname=DBNAME,dbusr=DBUSR,dbpw=DBPW)
  cur.close()

  if describe:
    print Describe(DBNAME,db)

  elif tablecounts:
    print DescribeCounts(DBNAME,db)

  elif info:

    desc,ts,median_cTested,median_sTested,median_aTested,median_wTested=GetMetadata(DBNAME,db)
    print ('%s [created: %s]'%(desc,ts))
    print "Description:",desc
    print "Timestamp:",ts
    print "median_cTested:",median_cTested
    print "median_sTested:",median_sTested
    print "median_aTested:",median_aTested
    print "median_wTested:",median_wTested

  else:
    ErrorExit('ERROR: No operation specified.')

  db.close()

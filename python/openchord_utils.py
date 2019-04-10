#!/usr/bin/env python
#############################################################################
### openchord_utils.py - 
###
### to do:
###  [ ] 
###
### Jeremy Yang
#############################################################################
import os,sys,re
import pgdb


#############################################################################
def Connect():
  db=pgdb.connect(dsn='localhost:openchord:jjyang:assword')
  #db=pgdb.connect(dsn='agave.health.unm.edu:openchord:jjyang:assword')
  cur=db.cursor()
  return db,cur

#############################################################################
def DescribeCounts(schema):
  outtxt=""
  db,cur = Connect()
  sql=("select table_name from information_schema.tables where table_schema='%s'"%schema)
  cur.execute(sql)
  rows=cur.fetchall()	##data rows
  outtxt+=("tables:\n")
  for row in rows:
    tablename=row[0]
    sql=("select count(*) from %s.%s"%(schema,tablename))
    cur.execute(sql)
    rows=cur.fetchall()	##data rows
    outtxt+="count(%s): %d\n"%(tablename,rows[0][0])
  cur.close()
  db.close()
  return outtxt
  
#############################################################################
def DescribeDB(schema):
  outtxt=DescribeCounts(schema)
  db,cur = Connect()
  sql=("SELECT table_name FROM information_schema.tables WHERE table_schema='%s'"%schema)
  cur.execute(sql)
  rows=cur.fetchall()	##data rows
  for row in rows:
    tablename=row[0]
    sql=("SELECT column_name,data_type FROM information_schema.columns WHERe table_schema = '%s' AND table_name = '%s'"%(schema,tablename))
    cur.execute(sql)
    rows=cur.fetchall()	##data rows
    outtxt+=("table: %s\n"%tablename)
    for row in rows:
      outtxt+=("\t%s\n"%str(row))
  cur.close()
  db.close()
  return outtxt

#############################################################################
def SmiLookup(db,schema,smi):
  sql=("SELECT cid, sid FROM %s.COMPOUND WHERE cansmi=openbabel.cansmiles('%s')"%(schema,smi))
  cur=db.cursor()
  cur.execute(sql)
  rows=cur.fetchall()   ##data rows
  cur.close()
  if not rows: return None
  return rows

#############################################################################
if __name__=='__main__':

  schema="mlp"
  print DescribeDB(schema)

  smis=[
	'CC(C)(C)C(=O)Nc1ccc(cc1)F',		##310095 103073359
	'Cc1cc(c(cc1)C)OCCCC(C)(C)C(=O)O',		##3463 11112705
	'C=CCC(c1cc(c(cc1)O)F)O'		##23777123 50117098
	]

  db,cur = Connect()
  for smi in smis:
    print "compound:",smi
    rows=SmiLookup(db,schema,smi)
    if not rows:
      print "\tnot found"
      continue
    for fields in rows:
      print "\tcid: %s\tsid: %s"%(fields[0],fields[1])
  db.close()

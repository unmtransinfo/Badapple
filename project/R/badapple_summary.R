#############################################################################
### badapple_summary.R - summarize Badapple database.
### 
### smiles,scafid,cTested,cActive,sTested,sActive,aTested,aActive,wTested,wActive,pScore,inDrug
### 
###
### Jeremy Yang
#############################################################################
library(DBI)
library(RPostgreSQL, quietly = T)
library(dplyr, quietly = T)
library(plotly, quietly = T)

PSCORE_CUTOFF_MODERATE <- 100
PSCORE_CUTOFF_HIGH <- 300
TOP_PCT <- 5

args <- commandArgs(trailingOnly=TRUE)
if (length(args)>0) { DBNAME <- args[1] } else { 
  DBNAME <- "badapple"
}

dbcon <- dbConnect(PostgreSQL(), host="localhost", dbname=DBNAME, user="jjyang", password="assword")


metadata <- dbGetQuery(dbcon, 'SELECT * FROM metadata')
metadata <- as.vector(metadata[1,])
for (name in names(metadata))
{
  print(sprintf("%22s: %s", name, metadata[[name]]))
}
n_cpd <- dbGetQuery(dbcon, 'SELECT count(*) FROM compound')$count
n_scaf <- dbGetQuery(dbcon, 'SELECT count(*) FROM scaffold')$count

print(sprintf("%22s: %9d", "n_cpd", n_cpd))
print(sprintf("%22s: %9d", "n_scaf", n_scaf))

color_low <- "#BBFFBB"
color_moderate <- "#DDDD00"
color_high <-"#DD0000"
score2color <- function(s) {
  if (is.na(s)){return(NA)}
  if (s < PSCORE_CUTOFF_MODERATE) { return(color_low) }
  else if (s < PSCORE_CUTOFF_HIGH) { return(color_moderate) }
  else { return(color_high) }
}

#
scafscores <- dbGetQuery(dbcon, 'SELECT * FROM scaffold')

nscaf <- nrow(scafscores)
print(sprintf("Nscaf: %d",nscaf))

## fix datatypes of interest
scoretag <- "pscore"
scafscores[[scoretag]] <- as.numeric(scafscores[[scoretag]])
scafscores[["in_drug"]] <- sapply(scafscores[["in_drug"]],
                                  function(s) { return(grepl("^[T1]",s,ignore.case=TRUE)) }, simplify=TRUE)
for (tag in c("ncpd_tested","ncpd_active","nsub_tested","nsub_active","nass_tested","nass_active","nsam_tested","nsam_active"))
{
  scafscores[[tag]] <- as.integer(scafscores[[tag]]);
}

## Report some means, std, quantiles.
for (tag in c("nsub_tested","nsub_active","nass_tested","nass_active","nsam_tested","nsam_active"))
{
  vals <- scafscores[[tag]]
  print(sprintf("%s mean: %f stddev: %f",tag,mean(vals),sd(vals)))
  qs <- quantile(vals, probs = c(.50, .75, .80, .85, .90, .95, .97, .99))
  for (name in names(qs))
  {
    print(sprintf("%s %s quantile: %5d", tag, name, as.integer(qs[[name]])))
  } 
}



## How many drugs?
scafscores_drug <- scafscores[scafscores[["in_drug"]],]
nscaf_drug <- nrow(scafscores_drug)
print(sprintf("nscaf_drug: %d  (%.1f%%)",nscaf_drug,nscaf_drug*100/nscaf))

## How many scores zero vs. nonzero?
nscores_nonzero <- nrow(scafscores[scafscores[[scoretag]]>0,])
nscores_zero <- nscaf-nscores_nonzero
print(sprintf("Nonzero scores: %d  (%.1f%%)",nscores_nonzero,nscores_nonzero*100/nscaf))
print(sprintf("Zero scores: %d (%.1f%%)",nscores_zero,(nscores_zero)*100/nscaf))

## How many scores zero due to no data?
nscores_null <- nrow(scafscores[scafscores[[scoretag]]==0 && scafscores[["nsam_tested"]]==0,])
print(sprintf("Zero scores due to no data: %d (%.1f%%)",nscores_null,(nscores_null)*100/nscaf))

## How many scores high, moderate, low?
nscores_low <- nrow(scafscores[scafscores[[scoretag]]<PSCORE_CUTOFF_MODERATE,])
nscores_moderate <- nrow(scafscores[scafscores[[scoretag]]<PSCORE_CUTOFF_HIGH,]) - nscores_low
nscores_high <- nscaf - nscores_moderate - nscores_low
pct_low <- nscores_low*100/nscaf
pct_moderate <- nscores_moderate*100/nscaf
pct_high <- nscores_high*100/nscaf
print(sprintf("Low scores: %d  (%.1f%%)",nscores_low,pct_low))
print(sprintf("Nonzero Low scores: %d  (%.1f%%)",nscores_low-nscores_zero,(nscores_low-nscores_zero)*100/nscaf))
print(sprintf("Moderate scores: %d  (%.1f%%)",nscores_moderate,pct_moderate))
print(sprintf("High scores: %d  (%.1f%%)",nscores_high,pct_high))

## Sort by pScore.
scafscores <- scafscores[ order(-scafscores[[scoretag]]), ]

## select top TOP_PCT%
n_top <- as.integer(nscaf * TOP_PCT / 100)
print(sprintf("n_top (%d%%): %d",TOP_PCT,n_top))
scafscores_top <- scafscores[1:n_top,]

### Histogram of pScore
xrange <- range(c(0,0),scafscores_top[[scoretag]])
print(sprintf("pScore range: [%.1f,%.1f]",xrange[1],xrange[2]))

scafscores$pscore[is.na(scafscores$pscore)] <- 0
scores <- scafscores$pscore

print(sprintf("pScores mean: %f stddev: %f", mean(scores), sd(scores)))
qs <- quantile(scores, probs = c(.97, .99, .999), na.rm=TRUE)
for (name in names(qs))
{
  print(sprintf("pScore %s quantile: %5d", name, as.integer(qs[[name]])))
}

scores_top <- scafscores_top[[scoretag]]
print(sprintf("Mean score (%d%%): %.2f  Median score: %.2f", TOP_PCT, mean(scores_top), median(scores_top)))
pScore_max <- max(scores_top)
pScore_min <- scores_top[n_top]

dbDisconnect(dbcon)

#############################################################################
### badapple_analysis.R - analyze and summarize Badapple scaffold data.
### Input: CSV 
### smiles,scafid,cTested,cActive,sTested,sActive,aTested,aActive,wTested,wActive,pScore,inDrug
### 
### 
### Jeremy Yang
#############################################################################
library(lattice)
library(ggplot2)

args <- commandArgs(trailingOnly=TRUE)
for (i in 1:length(args)) { print(sprintf("args[%d]: %s",i,args[i])) }

if (length(args)>0) { IFILE <- args[1] } else { 
  #IFILE <- paste(Sys.getenv("HOME"),"/projects/badapple/data/bard_mlsmr_scaf_scores.csv",sep="")
  IFILE <- paste(Sys.getenv("HOME"),"/projects/badapple/data/pc_mlsmr_scaf_scores.csv",sep="")
  #stop("Input CSV file must be specified.") 
}
if (length(args)>1) { OFILE_PREFIX <- args[2] } else { 
  OFILE_PREFIX <- NULL
}
print(sprintf("output file prefix: %s",OFILE_PREFIX))
if (length(args)>2) { TITLE_PREFIX <- args[3] } else {
  TITLE_PREFIX <- "Badapple Scaffold Promiscuity" 
}
if (length(args)>3) { TOP_PCT <- as.integer(args[4]) } else { TOP_PCT <- 5L }
if (length(args)>4) { PSCORE_CUTOFF_MODERATE <- as.integer(args[5]) } else { PSCORE_CUTOFF_MODERATE <- 100L }
if (length(args)>5) { PSCORE_CUTOFF_HIGH <- as.integer(args[6]) } else { PSCORE_CUTOFF_HIGH <- 300L }
print(sprintf("PSCORE_CUTOFF_MODERATE: %d  PSCORE_CUTOFF_HIGH: %d",PSCORE_CUTOFF_MODERATE,PSCORE_CUTOFF_HIGH))

color_low <- "#BBFFBB"
color_moderate <- "#DDDD00"
color_high <-"#DD0000"
score2color <- function(s) {
  if (is.na(s)){return(NA)}
  if (s < PSCORE_CUTOFF_MODERATE) { return(color_low) }
  else if (s < PSCORE_CUTOFF_HIGH) { return(color_moderate) }
  else { return(color_high) }
}

## read dataframe
scafscores <- read.csv(IFILE,colClasses="character")
print(names(scafscores))

nscaf <- nrow(scafscores)
print(sprintf("Nscaf: %d",nscaf))

## fix datatypes of interest
scoretag <- "pScore"
scafscores[[scoretag]] <- as.numeric(scafscores[[scoretag]])
#scafscores[["inDrug"]] <- as.logical(scafscores[["inDrug"]]) #not ok for "0" or "1", converts to NA
scafscores[["inDrug"]] <- sapply(scafscores[["inDrug"]],function(s) { return(grepl("^[T1]",s,ignore.case=TRUE)) },simplify=TRUE)
for (tag in c("cTested","cActive","sTested","sActive","aTested","aActive","wTested","wActive"))
{
  scafscores[[tag]] <- as.integer(scafscores[[tag]]);
}

## Report some means, std, quantiles.
for (tag in c("sTested","sActive","aTested","aActive","wTested","wActive"))
{
  vals <- scafscores[[tag]]
  print(sprintf("%s mean: %f stddev: %f",tag,mean(vals),sd(vals)))
  qs <- quantile(vals, probs = c(.50, .75, .80, .85, .90, .95, .97, .99))
  for (name in names(qs))
  {
    print(sprintf("%s %s quantile: %s",tag,name,qs[[name]]))
  } 
}

## How many drugs?
scafscores_drug <- scafscores[scafscores[["inDrug"]],]
nscaf_drug <- nrow(scafscores_drug)
print(sprintf("nscaf_drug: %d  (%.1f%%)",nscaf_drug,nscaf_drug*100/nscaf))

## How many scores zero vs. nonzero?
nscores_nonzero <- nrow(scafscores[scafscores[[scoretag]]>0,])
nscores_zero <- nscaf-nscores_nonzero
print(sprintf("Nonzero scores: %d  (%.1f%%)",nscores_nonzero,nscores_nonzero*100/nscaf))
print(sprintf("Zero scores: %d (%.1f%%)",nscores_zero,(nscores_zero)*100/nscaf))

## How many scores zero due to no data?
nscores_null <- nrow(scafscores[scafscores[[scoretag]]==0 && scafscores[["wTested"]]==0,])
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
#xrange <- c(0,quantile(scafscores_top[[scoretag]], probs=c(0.97),na.rm=TRUE))

scores <- scafscores[[scoretag]]

print(sprintf("pScores mean: %f stddev: %f",mean(scores),sd(scores)))
qs <- quantile(scores, probs = c(.97, .99, .999), na.rm=TRUE)
for (name in names(qs))
{
  print(sprintf("pScore %s quantile: %s",name,qs[[name]]))
}
rank2score <- function(rank) {
  if (is.na(rank)){return(NA)}
  return(scores[min(rank,length(scores))])
}
rank2color <- function(rank) {
  return(score2color(rank2score(rank)))
}
scores_top <- scafscores_top[[scoretag]]
print(sprintf("Mean score: %.2f  Median score: %.2f",mean(scores_top),median(scores_top)))
pScore_max <- max(scores_top)
pScore_min <- scores_top[n_top]

if (!is.null(OFILE_PREFIX))
{
  ofile <- paste(OFILE_PREFIX,"_analysis.pdf",sep="")
  print(sprintf("output file: %s",ofile))
  trellis.device(device="pdf",file=ofile,new=TRUE)
} else { print("output plot to default device") }

xlimit <- 500L
nbins <- 100
color <- sapply((1:nbins + 2)*xlimit/nbins,score2color,simplify=TRUE)
title <- sprintf("%s:\npScore distribution (Top %d%%)",TITLE_PREFIX,TOP_PCT)
subtitle <- sprintf("Top %d%% (%d / %d) pScore range: [%d, %d]",TOP_PCT,n_top,nscaf,as.integer(pScore_min),as.integer(pScore_max))
xlab <- "pScore"
low_text <- sprintf("LOW\n%.1f%%\n%d",pct_low,nscores_low)
moderate_text <- sprintf("MODERATE\n%.1f%%\n%d",pct_moderate,nscores_moderate)
high_text <- sprintf("HIGH\n%.1f%%\n%d",pct_high,nscores_high)
n_beyond_xlimit <- length(scores[scores>xlimit])
p <- histogram(sapply(scores_top, function(s) { min(s,xlimit) },simplify=TRUE),
	type="count",
	nint=nbins,
	main=title,
	sub=subtitle,
	xlim=c(0,xlimit+50),
	xlab=xlab,
	panel = function(...) {
		panel.histogram(...,col=color)
		panel.abline(v=PSCORE_CUTOFF_MODERATE, lty=3)
		panel.abline(v=PSCORE_CUTOFF_HIGH, lty=3)
		panel.rect(0,0,pScore_min,current.panel.limits()$ylim[2],col='#DDFFDD',border=NA)
		panel.text(pScore_min/2,current.panel.limits()$ylim[2]/2,labels=c(sprintf("The %d%%",100L-TOP_PCT)),srt=90)
		panel.text(PSCORE_CUTOFF_MODERATE/2,current.panel.limits()$ylim[2]*0.9,labels=c(low_text))
		panel.text((PSCORE_CUTOFF_MODERATE+PSCORE_CUTOFF_HIGH)/2,current.panel.limits()$ylim[2]*0.9,labels=c(moderate_text))
		panel.text((PSCORE_CUTOFF_HIGH+current.panel.limits()$xlim[2])/2,current.panel.limits()$ylim[2]*0.9,labels=c(high_text))
		panel.text(current.panel.limits()$xlim[2]*0.9,current.panel.limits()$ylim[2]/2,labels=c(sprintf("N > %d: %d",xlimit,n_beyond_xlimit)),srt=90)
	}
)

print(p)

#if (interactive()) {
#  ans <-  readline("DEBUG: continue [y]/n ? ")
#  if (ans == 'n') { stop() }
#}

#############################################################################
### Cumulative active well (wActive) vs. N scaffold
### ... AND on same plot, pScore vs. N scaffold
### (Note that the sum of wActive is actually greater than
### the total number of active wells, since a single well
### can belong to multiple scaffolds.  This is ok.
### We calculate pcts using the larger total so 
### stats are not exaggerated.  
### This total =  number of scaffolds in active wells.)
#############################################################################

title <- sprintf("%s:\nActive samples ROC (Top %d%%)",TITLE_PREFIX,TOP_PCT)
subtitle <- sprintf("Top %d%% (%d / %d)",TOP_PCT,n_top,nscaf)
wActive_total <- sum(scafscores[["wActive"]])
print(sprintf("wActive_total: %d",wActive_total))
ylab <- "Active samples, cumulative %ile"
xlab <- "Scaffold pScore Rank"
wActive_cum <- cumsum(scafscores_top[["wActive"]])
wActive_cum_pct <- wActive_cum*100/wActive_total


## Find at which scaffold does wActive_cum_pct reach 50%, etc.?
for (p in seq(50,90,5))
{
  for (i in 1:n_top)
  {
    if (wActive_cum_pct[i] >= p) {
      print(sprintf("%.1f%% activity by %d (%.1f%%) scafs",wActive_cum_pct[i],i,i*100/nscaf))
      break;
    }
  }
}
print(sprintf("%.1f%% activity by %d (%d%%) scafs ",wActive_cum_pct[n_top],n_top,TOP_PCT))

## For drugs: Find at which scaffold does wActive_cum_pct reach 50%, etc.?
wActive_total_drug <- sum(scafscores_drug[["wActive"]])
print(sprintf("wActive_total_drug: %d",wActive_total_drug))
wActive_cum_drug <- cumsum(scafscores_drug[["wActive"]])
wActive_cum_pct_drug <- wActive_cum_drug*100/wActive_total_drug
for (p in seq(50,90,5))
{
  for (i in 1:n_top)
  {
    if (wActive_cum_pct_drug[i] >= p) {
      print(sprintf("drugs: %.1f%% activity by %d (%.1f%%) scafs",wActive_cum_pct_drug[i],i,i*100/nscaf_drug))
      break;
    }
  }
}



wActive_high <- wActive_cum[nscores_high]
wActive_high_pct <- wActive_high*100/wActive_total
print(sprintf("wActive, high score scaffolds: %.1f%%",wActive_high_pct))

wActive_high_and_mod <- wActive_cum[nscores_high+nscores_moderate]
wActive_high_and_mod_pct <- wActive_high_and_mod*100/wActive_total
print(sprintf("wActive, high+moderate score scaffolds: %.1f%%",wActive_high_and_mod_pct))

p <- xyplot(wActive_cum_pct ~ 1:n_top,
	main=title,
	sub=subtitle,
	xlim=c(0,n_top),
	xlab=xlab,
	ylab=ylab,
	panel = function(x, y, ...) {
		panel.xyplot(x, y, ..., col=sapply(1:n_top,rank2color,simplify=TRUE))
		panel.abline(v=nscores_high, lty=3)
		panel.abline(v=nscores_high+nscores_moderate, lty=3)
		panel.text(nscores_high/2,current.panel.limits()$ylim[2]*0.9,labels=c(high_text))
		panel.text((nscores_high*2+nscores_moderate)/2,current.panel.limits()$ylim[2]*0.9,labels=c(moderate_text))
		panel.text((nscores_high+nscores_moderate+current.panel.limits()$xlim[2])/2,current.panel.limits()$ylim[2]*0.9,labels=c(low_text))
		panel.text(current.panel.limits()$xlim[2]*0.95,current.panel.limits()$ylim[2]/2,labels=c(sprintf("The %d%%",100L-TOP_PCT)),srt=90)
	}
	)

print(p)

#if (interactive()) {
#  ans <-  readline("DEBUG: continue [y]/n ? ")
#  if (ans == 'n') { stop() }
#}

ylab <- "pScore %ile"
title <- sprintf("%s:\nScores (Top %d%%)",TITLE_PREFIX,TOP_PCT)

p <- xyplot(scores_top*100/pScore_max ~ 1:n_top,
	main=title,
	sub=subtitle,
	xlim=c(0,n_top),
	xlab=xlab,
	ylab=ylab,
	panel = function(x, y, ...) {
		panel.xyplot(x, y, ..., col=sapply(y*pScore_max/100,score2color,simplify=TRUE))
		panel.abline(v=nscores_high, lty=3)
		panel.abline(v=nscores_high+nscores_moderate, lty=3)
		panel.text(nscores_high/2,current.panel.limits()$ylim[2]*0.9,labels=c(high_text))
		panel.text((nscores_high*2+nscores_moderate)/2,current.panel.limits()$ylim[2]*0.9,labels=c(moderate_text))
		panel.text((nscores_high+nscores_moderate+current.panel.limits()$xlim[2])/2,current.panel.limits()$ylim[2]*0.9,labels=c(low_text))
		panel.text(current.panel.limits()$xlim[2]*0.95,current.panel.limits()$ylim[2]/2,labels=c(sprintf("The %d%%",100L-TOP_PCT)),srt=90)
	},
	pch=2)
print(p)

#if (interactive()) {  ans <-  readline("DEBUG: continue [y]/n ? ");  if (ans == 'n') { stop() } }

#############################################################################
## Consider inDrug category; analyze and display separately.
## How many scores high, moderate, low?
#############################################################################
in_drug <- sprintf("inDrug: %s",scafscores[["inDrug"]])

xlimit <- 500L
nbins <- 100
color <- sapply((1:nbins + 2)*xlimit/nbins,score2color,simplify=TRUE)
title <- sprintf("%s:\npScore distribution (Top %d%%)",TITLE_PREFIX,TOP_PCT)
subtitle <- sprintf("Top %d%% (%d / %d) pScore range: [%d, %d]",TOP_PCT,n_top,nscaf,as.integer(pScore_min),as.integer(pScore_max))
xlab <- "pScore"
low_text <- sprintf("LOW\n%.1f%%\n%d",pct_low,nscores_low)
moderate_text <- sprintf("MODERATE\n%.1f%%\n%d",pct_moderate,nscores_moderate)
high_text <- sprintf("HIGH\n%.1f%%\n%d",pct_high,nscores_high)
n_beyond_xlimit <- length(scores[scores>xlimit])
p <- histogram( ~ scores_top | in_drug,
	type="count",
	main=title,
	sub=subtitle,
	layout=c(1,2),
	nint=nbins,
	xlim=c(0,xlimit+50),
	xlab=xlab,
	panel = function(x, ...) {
		panel.histogram(sapply(x,function(s) { min(s,xlimit) },simplify=TRUE), ...,col=color)
		nscaf_this <- length(x)
		scores_this <- x
		nscores_low_this <- length(scores_this[scores_this<PSCORE_CUTOFF_MODERATE])
		nscores_moderate_this <- length(scores_this[scores_this<PSCORE_CUTOFF_HIGH]) - nscores_low_this
		nscores_high_this <- nscaf_this - nscores_low_this - nscores_moderate_this
		pct_low_this <- nscores_low_this*100/nscaf_this
		pct_moderate_this <- nscores_moderate_this*100/nscaf_this
		pct_high_this <- nscores_high_this*100/nscaf_this
		low_text <- sprintf("LOW\n%.1f%%\n%d",pct_low_this,nscores_low_this)
		moderate_text <- sprintf("MODERATE\n%.1f%%\n%d",pct_moderate_this,nscores_moderate_this)
		high_text <- sprintf("HIGH\n%.1f%%\n%d",pct_high_this,nscores_high_this)
		panel.abline(v=PSCORE_CUTOFF_MODERATE, lty=3)
		panel.abline(v=PSCORE_CUTOFF_HIGH, lty=3)
		panel.rect(0,0,pScore_min,current.panel.limits()$ylim[2],col='#DDFFDD',border=NA)
		panel.text(pScore_min/2,current.panel.limits()$ylim[2]/2,labels=c(sprintf("The %d%%",100L-TOP_PCT)),srt=90)
		panel.text(PSCORE_CUTOFF_MODERATE/2,current.panel.limits()$ylim[2]*0.9,labels=c(low_text))
		panel.text((PSCORE_CUTOFF_MODERATE+PSCORE_CUTOFF_HIGH)/2,current.panel.limits()$ylim[2]*0.9,labels=c(moderate_text))
		panel.text((PSCORE_CUTOFF_HIGH+current.panel.limits()$xlim[2])/2,current.panel.limits()$ylim[2]*0.9,labels=c(high_text))
		panel.text(current.panel.limits()$xlim[2]*0.9,current.panel.limits()$ylim[2]/2,labels=c(sprintf("N > %d: %d",xlimit,n_beyond_xlimit)),srt=90)
	}
)

print(p)

#if (interactive()) {  ans <-  readline("DEBUG: continue [y]/n ? ") ; if (ans == 'n') { stop() } }


title <- sprintf("%s:\nActive samples ROC (Top %d%%)",TITLE_PREFIX,TOP_PCT)
subtitle <- sprintf("Top %d%% (%d / %d)",TOP_PCT,n_top,nscaf)
wActive_total <- sum(scafscores[["wActive"]])
print(sprintf("wActive_total: %d",wActive_total))
ylab <- "Active samples, cumulative %ile"
xlab <- "Scaffold pScore Rank"
wActive_cum <- cumsum(scafscores[["wActive"]])*100/wActive_total
p <- xyplot(wActive_cum ~ 1:n_top | in_drug,
	main=title,
	sub=subtitle,
	layout=c(1,2),
	xlim=c(-50,n_top),
	xlab=xlab,
	ylab=ylab,
	panel = function(x, y, ...) {
		panel.xyplot(x, y, ..., col=sapply(x,rank2color,simplify=TRUE))
		nscaf_this <- length(y)
		scores_this <- sapply(x,rank2score,simplify=TRUE)
		nscores_low_this <- length(scores_this[scores_this<PSCORE_CUTOFF_MODERATE])
		nscores_moderate_this <- length(scores_this[scores_this<PSCORE_CUTOFF_HIGH]) - nscores_low_this
		nscores_high_this <- nscaf_this - nscores_low_this - nscores_moderate_this
		pct_low_this <- nscores_low_this*100/nscaf_this
		pct_moderate_this <- nscores_moderate_this*100/nscaf_this
		pct_high_this <- nscores_high_this*100/nscaf_this
		low_text <- sprintf("LOW\n%.1f%%\n%d",pct_low_this,nscores_low_this)
		moderate_text <- sprintf("MODERATE\n%.1f%%\n%d",pct_moderate_this,nscores_moderate_this)
		high_text <- sprintf("HIGH\n%.1f%%\n%d",pct_high_this,nscores_high_this)
		panel.abline(v=nscores_high, lty=3)
		panel.abline(v=nscores_high+nscores_moderate, lty=3)
		panel.text(nscores_high/2,current.panel.limits()$ylim[2]*0.8,labels=c(high_text))
		panel.text((nscores_high*2+nscores_moderate)/2,current.panel.limits()$ylim[2]*0.8,labels=c(moderate_text))
		panel.text((nscores_high+nscores_moderate+current.panel.limits()$xlim[2])/2,current.panel.limits()$ylim[2]*0.8,labels=c(low_text))
		panel.text(current.panel.limits()$xlim[2]/2,current.panel.limits()$ylim[2]*0.6,labels=c(sprintf("N = %d",nscaf_this)))
		panel.text(current.panel.limits()$xlim[2]*0.95,current.panel.limits()$ylim[2]/2,labels=c(sprintf("The %d%%",100L-TOP_PCT)),srt=90)
	}
	)

print(p)

#############################################################################

ylab <- "pScore %ile"
p <- xyplot(scores*100/pScore_max ~ 1:n_top | in_drug,
	main=title,
	sub=subtitle,
	layout=c(1,2),
	xlim=c(-50,n_top),
	xlab=xlab,
	ylab=ylab,
	panel = function(x, y, ...) {
		panel.xyplot(x, y, ..., col=sapply(y*pScore_max/100,score2color,simplify=TRUE))
		nscaf_this <- length(y)
		scores_this <- y*pScore_max/100
		nscores_low_this <- length(scores_this[scores_this<PSCORE_CUTOFF_MODERATE])
		nscores_moderate_this <- length(scores_this[scores_this<PSCORE_CUTOFF_HIGH]) - nscores_low_this
		nscores_high_this <- nscaf_this - nscores_low_this - nscores_moderate_this
		pct_low_this <- nscores_low_this*100/nscaf_this
		pct_moderate_this <- nscores_moderate_this*100/nscaf_this
		pct_high_this <- nscores_high_this*100/nscaf_this
		low_text <- sprintf("LOW\n%.1f%%\n%d",pct_low_this,nscores_low_this)
		moderate_text <- sprintf("MODERATE\n%.1f%%\n%d",pct_moderate_this,nscores_moderate_this)
		high_text <- sprintf("HIGH\n%.1f%%\n%d",pct_high_this,nscores_high_this)
		panel.abline(v=nscores_high,lty=3)
		panel.abline(v=nscores_high+nscores_moderate,lty=3)
		panel.text(nscores_high/2,current.panel.limits()$ylim[2]*0.8,labels=c(high_text))
		panel.text((nscores_high*2+nscores_moderate)/2,current.panel.limits()$ylim[2]*0.8,labels=c(moderate_text))
		panel.text((nscores_high+nscores_moderate+current.panel.limits()$xlim[2])/2,current.panel.limits()$ylim[2]*0.8,labels=c(low_text))
		panel.text(current.panel.limits()$xlim[2]/2,current.panel.limits()$ylim[2]*0.6,labels=c(sprintf("N = %d",nscaf_this)))
		panel.text(current.panel.limits()$xlim[2]*0.95,current.panel.limits()$ylim[2]/2,labels=c(sprintf("The %d%%",100L-TOP_PCT)),srt=90)
	},
	pch=2)
print(p)

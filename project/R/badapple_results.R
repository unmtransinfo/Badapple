#!/usr/bin/env Rscript
#############################################################################
### Process output TSV from Badapple, and optionally, logfile.
#############################################################################
library(readr)
library(dplyr)
library(plotly)

args <- commandArgs(trailingOnly=T)

#if (length(args)<1) {
#  writeLines(sprintf("ERROR: Syntax: badapple_results.R RESULTSFILE [LOGFILE]"))
#  quit()
#}

if (length(args)>0) {
  (infile <- args[1])
} else {
  infile <- "~/projects/probeminer/data/probeminer_badapple.tsv"
}


if (length(args)>1) {
  (logfile <- args[2])
} else {
  logfile <- "data/log.tsv"
}


pscore_high_cutoff <- 300
pscore_med_cutoff <- 100

prefix <- "badapple"
###
# LOGFILE:
log <- read_delim(logfile, "\t")

log[['Total_elapsed_sec']] <- as.integer(sub(":.*$", "", log$`Total elapsed time`))*60 + as.integer(sub("^.*:(\\d\\d):00", "\\1", log$`Total elapsed time`))
log$`Total elapsed time` <- NULL

writeLines(sprintf("===\nLOGFILE statistics:"))
for (colname in names(log)) {
  if (typeof(log[[colname]]) %in% c("integer","double")) {
    writeLines(sprintf("TOTAL %24s: %8d", colname, sum(log[[colname]])))
  }
}
writeLines(sprintf("Total elapsed compute time: %.1f hours\n", sum(log$Total_elapsed_sec/60/60)))
###
# RESULTS:
bap <- read_delim(infile, "\t", 
	col_names = c("SMILES", "COMPOUND_ID", "STATUS", "SCORES", "SCAFIDS", "SCAFINDRUG", "SCAFSMIS"),
	col_types = cols(SCAFIDS = col_character()))

writeLines(sprintf("===\nRESULTSFILE statistics:"))
writeLines(sprintf("Mols: %d ; results: %d", nrow(bap), nrow(bap[!is.na(bap$SCORES),])))

# Keep only highest scoring scaffold for each mol.

bap[["SCORE"]] <- as.numeric(sub(',.*$', '', bap$SCORES))
bap[["SCAFID"]] <- sub(',.*$', '', bap$SCAFIDS)
bap[["SCAFSMI"]] <- sub(',.*$', '', bap$SCAFSMIS)

print(quantile(bap$SCORE, na.rm=T, seq(0, 1, .1)))

###

#

bap$STATUS[is.na(bap$SCORE) & grepl("^Scores computed", bap$STATUS)] <- sub(
  "Scores computed", "No score, scafs unknown",
  bap$STATUS[is.na(bap$SCORE) & grepl("^Scores computed", bap$STATUS)]
)

bap[['STATUS_TYPE']] <- sub(' \\(.*$', '', bap$STATUS)

tbl <- table(bap$STATUS_TYPE, useNA="ifany")
writeLines(sprintf("===\nSTATUS_TYPES:"))
writeLines(sprintf("%28s: %6d (%4.1f%%)", names(tbl), tbl, 100*tbl/sum(tbl)))

bap[['ADVISORY']] <- ifelse(bap$SCORE>=pscore_high_cutoff, "HIGH SCORE",
                      ifelse(bap$SCORE>=pscore_med_cutoff, "MODERATE SCORE",
                      ifelse(bap$SCORE>=0, "LOW SCORE", NA)))

bap$ADVISORY <- ifelse((is.na(bap$ADVISORY)&grepl("^No scaffolds", bap$STATUS)), "NO SCORE, UNKNOWN", bap$ADVISORY)
bap$ADVISORY <- ifelse((is.na(bap$ADVISORY)&grepl("^No score, scafs unknown", bap$STATUS)), "NO SCORE, UNKNOWN", bap$ADVISORY)
bap$ADVISORY <- ifelse((is.na(bap$ADVISORY)&grepl("^Skipped", bap$STATUS)), "SKIPPED", bap$ADVISORY)
tbl <- table(bap$ADVISORY, useNA="ifany")
writeLines(sprintf("===\nSCORE_LEVEL_ADVISORYS:"))
writeLines(sprintf("%20s: %6d (%4.1f%%)", names(tbl), tbl, 100*tbl/sum(tbl)))

writeLines(sprintf("Writing: %s", sprintf("data/%s_molscores.tsv", prefix)))
write_delim(bap[, c("COMPOUND_ID", "SMILES", "STATUS", "STATUS_TYPE", "ADVISORY", "SCORE", "SCAFID", "SCAFSMI")], sprintf("data/%s_molscores.tsv", prefix))


###
# Extract table of scaffolds:
scafs <- bap[!is.na(bap$SCAFSMIS),c("SCAFIDS","SCAFSMIS","SCAFINDRUG","SCORES")]
scafs$SCAFIDS <- strsplit(scafs$SCAFIDS, ",")
scafs$SCAFSMIS <- strsplit(scafs$SCAFSMIS, ",")
scafs$SCAFINDRUG <- strsplit(scafs$SCAFINDRUG, ",")
scafs$SCORES <- strsplit(scafs$SCORES, ",")
scafs <- data.frame(ID=unlist(scafs$SCAFIDS), SMI=unlist(scafs$SCAFSMIS), INDRUG=as.logical(unlist(scafs$SCAFINDRUG)),
                    SCORE=as.numeric(unlist(scafs$SCORES)))
#
writeLines(sprintf("===\nScaffold counts:"))
writeLines(sprintf("Scaffold (instances) in dataset: %d ; in_drug: %d (%.1f%%)", 
                   nrow(scafs), nrow(scafs[scafs$INDRUG,]), 100*nrow(scafs[scafs$INDRUG,])/nrow(scafs)))
#
scafs <- unique(scafs)
scafs <- scafs[order(scafs$ID),]
rownames(scafs) <- NULL
#
writeLines(sprintf("Scaffolds (unique) in dataset: %d ; in_drug: %d (%.1f%%)", 
                   nrow(scafs), nrow(scafs[scafs$INDRUG,]), 100*nrow(scafs[scafs$INDRUG,])/nrow(scafs)))

###
# mol2scaf table
mol2scaf <- bap[!is.na(bap$SCAFSMIS),c("COMPOUND_ID","SCAFIDS")]
mol2scaf$SCAFIDS <- strsplit(mol2scaf$SCAFIDS, ",")
mol2scaf <- data.frame(ID=unlist(mapply(rep, mol2scaf$COMPOUND_ID, mapply(length, mol2scaf$SCAFIDS))), 
                       SCAFID=unlist(mol2scaf$SCAFIDS))
mol2scaf <- merge(mol2scaf, scafs, by.x="SCAFID", by.y="ID")
mol2scaf <- mol2scaf[order(mol2scaf$ID, mol2scaf$SCAFID),]
rownames(mol2scaf) <- NULL
###
# Scores ignoring in_drug scaffolds
molscores_nodrugs <- mol2scaf[!mol2scaf$INDRUG,c("ID","SCORE")]
molscores_nodrugs <- aggregate(molscores_nodrugs, by=list(molscores_nodrugs$ID), max)
#
###
# PLOTS:
#Histograms, color by advisory.
my_pal <- c(rep("green",1), rep("yellow",2), rep("red",9))
#
p1 <- plot_ly(type="histogram", x=bap$SCORE[!is.na(bap$SCORE)],
              autobinx=F, xbins=list(size=100, start=0, end=800),
              marker=list(color=my_pal)
) %>%
  #add_segments(x=pscore_med_cutoff, xend=pscore_med_cutoff, xref="x", y=0, yend=1, yref="paper") %>%
  layout(title=paste0("Probeminer Badapple Scores", sprintf("<br>N_total = %d ; N_calc = %d ; N_unknown = %d", 
                                                            nrow(bap),
                                                            nrow(bap[!is.na(bap$SCORE),]),
                                                            nrow(bap[is.na(bap$SCORE),])
  )),
  xaxis=list(title=""),yaxis=list(type="linear",title=""),
  showlegend=F,
  margin=list(t=100,l=80,b=80,r=80),
  annotations=list(x=c(50, 200, 400),y=c(0.9, 0.9, 0.9),
                   xanchor="center", xref="x", yref="paper", showarrow=F,
                   align=c("center", "center", "left"),
                   text=c("LOW","MODERATE","HIGH")),
  font=list(family="Arial",size=16),titlefont=list(size=22))
p1
#
p2 <- plot_ly(type="histogram", x=molscores_nodrugs$SCORE,
              autobinx=F, xbins=list(size=100, start=0, end=800),
              marker=list(color=my_pal)
) %>%
  layout(title=paste0("Probeminer Badapple Scores (IGNORING IN_DRUG SCAFFOLDS)", 
                      sprintf("<br>N_calc_nodrugs = %d ; N_total = %d ; N_calc = %d ; N_unknown = %d", 
                                                            nrow(molscores_nodrugs), nrow(bap),
                                                            nrow(bap[!is.na(bap$SCORE),]),
                                                            nrow(bap[is.na(bap$SCORE),])
  )),
  xaxis=list(title=""),yaxis=list(type="linear",title=""),
  showlegend=F,
  margin=list(t=100,l=80,b=80,r=80),
  annotations=list(x=c(50, 200, 400),y=c(0.9, 0.9, 0.9),
                   xanchor="center", xref="x", yref="paper", showarrow=F,
                   align=c("center", "center", "left"),
                   text=c("LOW","MODERATE","HIGH")),
  font=list(family="Arial",size=16),titlefont=list(size=22))
p2
#
xax=list(type="linear", title="")
yax=list(type="linear", title="")
subplot(list(p1,p2), nrows=2, margin=0.02, shareX=T, shareY=T, titleX=F, titleY=F) %>%
  layout(title=paste0("Probeminer Badapple Scores", sprintf("<br>N_total = %d ; N_calc = %d ; N_unknown = %d", 
            nrow(bap), nrow(bap[!is.na(bap$SCORE),]), nrow(bap[is.na(bap$SCORE),]))), 
         margin=list(t=80, b=60, l=30),
         xaxis=xax, yaxis=yax,
         font=list(family="Arial", size=14), showlegend=F) %>%
  add_annotations(text=c("ALL (CALCULATED)","(IGNORING IN_DRUG SCAFFOLDS)"), x=c(1,1), y=c(.8,.2), xref="paper", yref="paper", align="right", font=list(family="Arial", size=24), showarrow=F) %>%
  add_annotations(sprintf("<br>N_calc_nodrugs = %d",nrow(molscores_nodrugs)), x=.5, y=.1, xref="paper", yref="paper", align="center", font=list(family="Arial", size=18), showarrow=F)
###

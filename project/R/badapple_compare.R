args <- commandArgs(trailingOnly=TRUE)
print(args)
(ifile <- args[1])
(nameA <- args[2])
(nameB <- args[3])

proc.time()

badata <- read.csv(ifile,header=TRUE)
print(sprintf("Total: %d, Number missing (A not in B): %d",nrow(badata),nrow(badata[is.na(badata$pscoreB),])))
badata <- badata[!is.na(badata$pscoreB),]
mx <- max(badata$pscoreA,badata$pscoreB,na.rm=TRUE)
plot(badata$pscoreA,badata$pscoreB,
     xlab="pScore1",ylab="pScore2",
     xlim=c(0,mx),ylim=c(0,mx),
     pch=20,col="red",
     main=sprintf("Badapple %s vs %s Top scaffold scores",nameA,nameB))
s_cor <- cor(badata$pscoreA,badata$pscoreB,use="complete.obs")
print(sprintf("Badapple %s vs %s scores Pearson correlation: %.2f",nameA,nameB,s_cor))
r_cor <- cor(badata$rankA,badata$rankB,use="complete.obs")
print(sprintf("Badapple %s vs %s scores Spearman-Rank correlation: %.2f",nameA,nameB,r_cor))
# 

proc.time()


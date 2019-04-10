xval_pscores <- read.csv("data/xval_pscores.csv", header=T)

#colnames(xval_pscores) <- c("cid","pscore_orig","pscore_test")

n_test <- nrow(xval_pscores)
print(sprintf("test compounds: %d",n_test))

scored_orig <- nrow(xval_pscores[!is.na(xval_pscores$pscore_orig),])
scored_test <- nrow(xval_pscores[!is.na(xval_pscores$pscore_test),])
print(sprintf("scored orig: %d ; test: %d ; difference: %d (%.1f%%)",
              scored_orig, scored_test, scored_test-scored_orig,
              100*(scored_test-scored_orig)/scored_orig))

unscored_orig <- nrow(xval_pscores[is.na(xval_pscores$pscore_orig),])
unscored_test <- nrow(xval_pscores[is.na(xval_pscores$pscore_test),])
print(sprintf("unscored orig: %d ; test: %d ; difference: %d (%.1f%%)",
              unscored_orig, unscored_test, unscored_test-unscored_orig,
              100*(unscored_test-unscored_orig)/unscored_orig))


c <- cor(xval_pscores$pscore_orig, xval_pscores$pscore_test, use="complete.obs")
print(sprintf("test vs. orig scores correlation (scored): %.8f",c))

#Replace test NA with zero for previously scored cpds.
xval_pscores$pscore_test[!is.na(xval_pscores$pscore_orig) & is.na(xval_pscores$pscore_test)] <- 0

c <- cor(xval_pscores$pscore_orig, xval_pscores$pscore_test, use="complete.obs")
print(sprintf("test vs. orig scores correlation (all testset): %.8f",c))


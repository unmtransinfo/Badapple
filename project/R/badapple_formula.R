#############################################################################
### Plots illustrating the behavior of the Badapple scoring function.
###
### score = 
###	sActive / (sTested + median(sTested)) * 
###	aActive / (aTested + median(aTested)) * 
###	wActive / (wTested + median(wTested)) * 
###	1e5 
###
###
### min_sTotal | max_sTotal 
### ------------+------------
###   1 |      35884
### 
### min_sTested | med_sTested | max_sTested | min_sActive | med_sActive | max_sActive 
### -------------+-------------+-------------+-------------+-------------+-------------
###   0 |           2 |       32346 |           0 |           1 |       20074
### 
### min_aTested | med_aTested | max_aTested | min_aActive | med_aActive | max_aActive 
### -------------+-------------+-------------+-------------+-------------+-------------
###   0 |         453 |         528 |           0 |           3 |         508
### 
### min_wTested | med_wTested | max_wTested | min_wActive | med_wActive | max_wActive 
### -------------+-------------+-------------+-------------+-------------+-------------
###   0 |         517 |    11603660 |           0 |           3 |       93128
### 
#############################################################################
### Jeremy Yang
#############################################################################


median_sTested <- 2
median_sActive <- 1
pct80_sActive <- 4
median_aTested <- 453
median_aActive <- 3
pct80_aActive <- 12
median_wTested <- 517
median_wActive <- 3
pct80_wActive <- 14

##   

xmax <- 500; 
#xstep <- xmax / 100;
xstep <- 1;
ymax <- 500; 
#ystep <- ymax / 100;
ystep <- 1;
plot(0,0,xlab="aTested",ylab="aActive",type="n",xlim=c(0,xmax),ylim=c(0,ymax))
title("Badapple score dependence on assay active:tested ratio")
text(xmax*0.2,ymax*0.9,
     sprintf("sActive, wActive = 80th percentile\nsTested, wTested = median\nmedian_aTested = %d",median_aTested))
legend(0,ymax*0.7,
       legend=c("High [300,inf)","Moderate [100,300)","Low [0,100)"),
       col=c("red","yellow","green"),pch=19,bty="o")

for (aTested in seq(0,xmax,xstep))
{  
  for (aActive in seq(0,min(ymax,aTested),ystep))
  {
    score <- aActive / ( aTested + median_aTested) ;
    score <- score * pct80_sActive / (2 * median_sTested) ;
    score <- score * pct80_wActive / (2 * median_wTested) ;
    score <- score * 100000;
    if (score <100) { color = "green"; }
    else if (score < 300) { color = "yellow"; }
    else { color = "red"; }
    points(aTested,aActive,pch=20,col=color)
  }
}


xmax <- 400; 
#xstep <- xmax / 100;
ymax <- 400; 
#ystep <- ymax / 100;
plot(0,0,xlab="wTested",ylab="wActive",type="n",xlim=c(0,xmax),ylim=c(0,ymax))
title("Badapple score dependence on sample active:tested ratio")
text(xmax*0.2,ymax*0.9,
  sprintf("sActive, aActive = 80th percentile\nsTested, aTested = median\nmedian_wTested = %d",median_wTested))
legend(0,ymax*0.7,
       legend=c("High [300,inf)","Moderate [100,300)","Low [0,100)"),
       col=c("red","yellow","green"),pch=19,bty="o")

for (wTested in seq(0,xmax,xstep))
{ 
  for (wActive in seq(0,min(ymax,wTested),ystep))
  {
    score <- wActive / ( wTested + median_wTested) ;
    score <- score * pct80_sActive / (2 * median_sTested) ;
    score <- score * pct80_aActive / (2 * median_aTested) ;
    score <- score * 100000;
    
    if (score <100) { color = "green"; }
    else if (score < 300) { color = "yellow"; }
    else { color = "red"; }
    points(wTested,wActive,pch=20,col=color)
  }
}



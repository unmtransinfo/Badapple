bard_exp <- read.csv("~/projects/bard/data/bard_experiments_straw.csv",stringsAsFactors=FALSE)
print(sprintf("rows: %d",nrow(bard_exp)))
bard_exp <- bard_exp[(bard_exp$target.biology != ""),]
print(sprintf("rows with biology: %d",nrow(bard_exp)))
             


bios <- table(bard_exp$target.biology)
for (name in names(bios))
{
  print(sprintf("%4d : %s",bios[name],name))
}


bard_exp$project.labName[bard_exp$project.labName == ""] <- "None"

labs <- table(bard_exp$project.labName)

for (name in names(labs))
{
  print(sprintf("%4d : %s",labs[name],name))
}

targets <- bard_exp$target.name
print(sprintf("targets: %d",length(targets)))
print(sprintf("unique targets: %d",length(levels(as.factor(targets)))))

bard_exp <- bard_exp[bard_exp$compounds > 20000,]
targets <- as.character(bard_exp$target.name)
print(sprintf("hts targets: %d",length(targets)))
print(sprintf("unique hts targets: %d",length(levels(as.factor(targets)))))

hist(bard_exp$compounds)

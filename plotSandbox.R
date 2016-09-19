# tack open orders onto order book
# show account value as tile
# show account returns MTD (month-to-date) as tile
# margin account summary chart to show positions taken (not currently in account/currency charts)
# lending rates




pair <- "BTC_XMR"
# date.range <- "2016-07-02::2016-07-05"
# period <- "hours" # "seconds", "minutes", "hours", "days", "weeks", "months", "quarters", and "years"
# type <- "line"
depth <- 50
market <- "lending"

plotWeights <- function(weights.name=NULL){
  start_t <- Sys.time()
  weights.var <- readRDS(relativePath(paste0("data/clean/",weights.name,".RDS")))
  plot.name <- paste0("figures/final/",weights.name,".pdf")
  png(plot.name)
  chart.StackedBar(weights.var, colorset=tol12qualitative #rainbow12equal
                   , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                   , main=weights.name)
  dev.off()
  end_t <- Sys.time()
  print(paste0("Weight plotting time: ",end_t - start_t))
}

pl <- accountAllocationChart(scale.by.total.value = FALSE)
print(pl)
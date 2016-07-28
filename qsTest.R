#!/usr/bin/Rscript

qsTest <- function(){
  print(sessionInfo())
  source("systemConfig.R")
  simulateSubsystem(pair="BTC_CLAM")
}

qmTest <- function(){
  library(quantmod)
  library(xts)
  
  getSymbols("SPY", src="google", from = "2004-01-01")
  x1 <- SPY['2006-01/2007-12']
  
  x2 <- apply.monthly(x1,mean)
  print(x2['2006-01/2007-12'])
  
  x3 <- as.xts(coredata(x2),order.by = as.yearmon(index(x2)))
  print(x3['2006-01/2007-12'])
}

qsTest()
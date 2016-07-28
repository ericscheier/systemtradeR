#!/usr/bin/Rscript

qsTest <- function(){
  print(sessionInfo())
  source("systemConfig.R")
  simulateSubsystem(pair="BTC_CLAM")
}
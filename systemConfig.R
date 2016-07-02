#!/usr/bin/Rscript

library(xts)
library(lubridate)
library(TTR)
library(PerformanceAnalytics)
library(PortfolioAnalytics)
library(DEoptim)
library(doParallel)
library(httr)
library(plyr)
library(digest)
library(RCurl)
library(stringr)
library(slackr)

source("SystematicTrading.R")
source("PoloniexAPI.R")
source("executionLogic.R")
source("portfolioLogic.R")
source("updatePricing.R")
source("monitoring.R")
# source("simulateSubsystem.R")

Sys.setenv(TZ = "UTC")
set_config(timeout(seconds = 30))

filterPairs <- function(){
  # update universe of pairs I am interested in
  
  # right now only want BTC pairs with leverage available
  bases <- c("BTC")
  
  # volatility should be higher than benchmark
  volatility.benchmark <- 0.001
  
  # if account size isn't big enough to support maximum position, exclude it
  
  portfolio.pairs <- c("BTC_BTS", "BTC_CLAM", "BTC_DASH", "BTC_DOGE", "BTC_ETH", "BTC_FCT"
                       , "BTC_LTC", "BTC_MAID", "BTC_STR", "BTC_XMR", "BTC_XRP")
  
  return(portfolio.pairs)
}

slackr_setup(config_file=paste0(getwd(),"/.slackr"))
config <- new.env(parent = emptyenv())
config$volatility.lookback <- 101 #hours
config$volatility.target <- .005 # hourly target volatility in % terms [started at 0.0005, bumped up 10x to reflect vol of market & underinvestment]
config$minimum.order.size <- 0.0001 #BTC, true minimum is 0.0001 for order size
config$minimum.position.change <- .1 # % position should change before transacting
config$transaction.fee <- 0.0025 #% of each transaction
config$portfolio.pairs <- filterPairs()
config$poloniex.key <- "O2NT3UJT-04WVU41J-52ETHGHN-WCGM7DUM"
config$poloniex.secret <- "6dfb2b35a571a745a6190cbf6989b7d52409dbf6f40541fc8823c725b1c352fa2b04edceba44d37cb7c216c6f2a062fc538a3119abcbe8e317f8eee32165168d"
if(is.null(config$poloniex.margin.value)){try(config$poloniex.margin.value <- accountValue())}

source("SystemMaster.R")


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

Sys.setenv(TZ = "UTC")

filterPairs <- function(){
  # update universe of pairs I am interested in
  
  # right now only want BTC pairs with leverage available
  bases <- c("BTC")
  
  # volatility should be higher than benchmark
  volatility.benchmark <- 0.001
  
  portfolio.pairs <- c("BTC_BTS", "BTC_CLAM", "BTC_DASH", "BTC_DOGE", "BTC_ETH", "BTC_FCT"
                       , "BTC_LTC", "BTC_MAID", "BTC_STR", "BTC_XMR", "BTC_XRP")
  
  return(portfolio.pairs)
}

config <- new.env(parent = emptyenv())
config$volatility.lookback <- 101 #hours
config$volatility.target <- .0005 # hourly target volatility in % terms
config$minimum.order.size <- 0.0001 #BTC, true minimum is 0.0001
config$minimum.position.change <- .1 # % position should change before transacting
config$transaction.fee <- 0.0025 #% of each transaction
config$portfolio.pairs <- filterPairs()


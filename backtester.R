source("libraries.R")
# library(doMC) # install.packages("doMC", repos="http://R-Forge.R-project.org")
# registerDoMC(cores=detectCores())
rm(list = ls())

source("SystematicTrading.R")
Sys.setenv(TZ = "UTC")
config <- new.env(parent = emptyenv())
config$volatility.lookback <- 101 #hours
config$volatility.target <- .005 # hourly target volatility in % terms 
# started at 0.0005
# bumped up 10x to reflect vol of market & underinvestment
config$minimum.order.size <- 0.0001 #BTC, true minimum is 0.0001 for order size
config$minimum.position.change <- .1 # % position should change before transacting
config$transaction.fee <- 0.0025 #% of each transaction
# poloniex.ohlc.30m <- content(GET("https://poloniex.com/public?command=returnChartData&currencyPair=BTC_ETH&start=1439010600&end=9999999999&period=1800"))  # https://poloniex.com/support/api/
base <- 'BTC'
asset <- 'ETH'
pair <- paste0(base,'_',asset)


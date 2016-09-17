
source("backtestConfig.R")

backtest.config$backtest.pairs <- system.config$portfolio.pairs  #c("BTC_ETH") # c("BTC_LTC") #
backtest.config$backtest.forecast <- "auto_arima_1"

simulateBacktest()
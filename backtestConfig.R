
source("backtest.R")
source("forecasts.R")

if(inherits(try(bactest.config, silent=TRUE), "try-error")){backtest.config <- new.env(parent = emptyenv())}


backtest.config$end.date <- Sys.Date() -1
backtest.config$backtest.length <- 24*7*4 # hours

backtest.config$lookback.hours <- 96 #system.config$lookback.hours
backtest.config$volatility.lookback <- system.config$ volatility.lookback
backtest.config$forecast.cap <- system.config$forecast.cap

backtest.config$volatility.target <- system.config$volatility.target
backtest.config$minimum.order.size <- system.config$minimum.order.size
backtest.config$minimum.position.change <- system.config$minimum.position.change

backtest.config$backtest.pairs <- system.config$portfolio.pairs #c("BTC_ETH")
backtest.config$backtest.forecast <- system.config$portfolio.forecasts #"auto_arima_24" # "combinedForecast"

backtest.config$initial.account.value <- 1

backtest.config$debug <- TRUE
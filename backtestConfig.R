


if(inherits(try(bactest.config, silent=TRUE), "try-error")){backtest.config <- new.env(parent = emptyenv())}


backtest.config$end.date <- Sys.Date() -1
backtest.config$backtest.length <- 200 # hours

backtest.config$lookback.hours <- system.config$lookback.hours

backtest.config$volatility.target <- system.config$volatility.target
backtest.config$minimum.order.size <- system.config$minimum.order.size
backtest.config$minimum.position.change <- system.config$minimum.position.change

backtest.config$backtest.pairs <- system.config$portfolio.pairs #c("BTC_ETH")
backtest.config$backtest.forecast <- system.config$portfolio.forecasts #"auto_arima_24" # "combinedForecast"

backtest.config$initial.account.value <- 1

backtest.config$debug <- TRUE
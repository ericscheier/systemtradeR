rm(list=ls())

source("systemConfig.R")
# source("getSymbols_custom.R")

start_time <- Sys.time()

pairs <- system.config$portfolio.pairs
# pairs <- pairs[1:2]
forecast.name <- "no_forecast_long"

test.equity <- simulateBacktest(pairs=pairs, forecast.name=forecast.name)

end_time <- Sys.time()
print(end_time - start_time)
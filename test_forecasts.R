# "breakout_8",
# "breakout_512",
# "auto_arima_24",
# "ewma_1_4"
# "ewma_32_128",
# "ewma_64_256", 
# "ewma_128_512", 
# "ewma_256_1024",
# "ewma_512_2048", 
# "ewma_1024_4096",

forecasts.to.test <- c(
  "breakout_96",
  "breakout_72",
  "breakout_48",
  "breakout_24",
  "breakhout_12",
  "ewma_6_24",
  "ewma_12_48",
  "ewma_18_72",
  "ewma_24_96"
  )

breakout_96 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 96))
}

breakout_72 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 72))
}

breakout_48 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 48))
}

breakout_24 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 24))
}

breakout_12 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 12))
}

ewma_24_96 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 24, slow.n=96))
}

ewma_18_72 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 18, slow.n=72))
}

ewma_12_48 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 12, slow.n=48))
}

ewma_6_24 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 6, slow.n=24))
}

ewma_1_4 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 1, slow.n=4))
}

testForecasts <- function(forecasts.to.test=forecasts.to.test){
  start.time <- Sys.time()
  portfolio.forecasts <- forecasts.to.test
  portfolio.pairs <- backtest.config$backtest.pairs
  
  results.matrix <- 
    foreach(forecast.name=portfolio.forecasts, .combine='merge') %dopar% {
      forecast.returns <- simulateBacktest(pairs=portfolio.pairs, forecast.name=forecast.name)
      file.name <- paste0("/data/clean/",forecast.name,"_forecast_returns.RDS")
      colnames(forecast.returns) <- forecast.name
      saveRDS(forecast.returns, file=relativePath(file.name))
      return(forecast.returns)
    }
  
  results.matrix <- na.omit(results.matrix)
  forecast.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
  saveRDS(forecast.returns, file=relativePath("/data/clean/forecast_returns.RDS"))
  
  execution.time <- round(difftime(Sys.time(), start.time, units="mins"),2)
  print(paste0("Finished simulating forecast returns in ",execution.time," mins."))
}
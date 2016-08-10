getPortfolioForecasts <- function(){
  portfolio.forecasts <- c("ewma_2_8", "ewma_4_16", "ewma_8_32", "ewma_16_64",
                           "ewma_32_128", "ewma_64_256", "ewma_128_512", "ewma_256_1024",
                           "ewma_512_2048", "ewma_1024_4096",
                           "no_forecast_long", "no_forecast_short")
  return(portfolio.forecasts)
}

ewmaRawForecast <- function(price.xts, fast.n=8, slow.n=32){
  # price is in 5-minute intervals, so rescale lookbacks
  fast.n <- fast.n * (60/5)
  slow.n <- slow.n * (60/5)
  slow.ema <- EMA(price.xts, n = slow.n)
  fast.ema <- EMA(price.xts, n = fast.n)
  raw.forecast <- fast.ema - slow.ema
  return(raw.forecast)
}

breakoutRawForecast <- function(price.xts, lookback=system.config$volatility.lookback){
  lookback <- lookback * (60/5)
  # http://qoppac.blogspot.co.uk/2016/05/a-simple-breakout-trading-rule.html
  # may want to use stoch function from TTR
}

constantRawForecast <- function(constant, price.xts){
  return(xts(x=rep(constant, times=length(index(price.xts))), order.by = index(price.xts)))
}

# 8_32, 16_64, 32_128, 64_256, 128_512, 256_1024

no_forecast_long <- function(price.xts){
  return(constantRawForecast(constant=10, price.xts=price.xts))
}

no_forecast_short <- function(price.xts){
  return(constantRawForecast(constant=-10, price.xts=price.xts))
}

ewma_2_8 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 2, slow.n=8))
}

ewma_4_16 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 4, slow.n=16))
}

ewma_8_32 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 8, slow.n=32))
}

ewma_16_64 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 16, slow.n=64))
}

ewma_32_128 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 32, slow.n=128))
}

ewma_64_256 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 64, slow.n=256))
}

ewma_128_512 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 128, slow.n=512))
}

ewma_256_1024 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 256, slow.n=1024))
}

ewma_512_2048 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 512, slow.n=2048))
}

ewma_1024_4096 <- function(price.xts){
  return(ewmaRawForecast(price.xts, fast.n = 1024, slow.n=4096))
}
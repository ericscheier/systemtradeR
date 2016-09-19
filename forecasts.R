# price.xts <- Cl(getHourlyPairData(pair="BTC_ETH"))

getPortfolioForecasts <- function(){
  portfolio.forecasts <- c(
    "ewma_128_512",
    "no_forecast_long",
    "no_forecast_short"
    )
  
  if(system.config$long.only){portfolio.forecasts<-"no_forecast_long"}
  return(portfolio.forecasts)
}

ewmaRawForecast <- function(price.xts, fast.n=8, slow.n=32){
  # price is in 5-minute intervals, so rescale lookbacks
  fast.n <- fast.n #* (60/5)
  slow.n <- slow.n #* (60/5)
  slow.ema <- EMA(price.xts, n = slow.n)
  fast.ema <- EMA(price.xts, n = fast.n)
  raw.forecast <- fast.ema - slow.ema
  return(raw.forecast)
}

autoArimaRawForecast <- function(price.xts, hours.ahead=24, current=FALSE, trailing.hours=24*7){
  forecast.index <- index(price.xts)
  price.series <- coredata(price.xts)
  price.series <- diff(log(price.series))
  start.value <- max(trailing.hours+1,1)
  if(current){
    start.value <- length(price.series)
    forecast.index <- last(forecast.index)
  }
  # price.series <- price.series[1:50]
  forecast.series <- foreach(n=start.value:length(price.series), .combine = "c", .inorder = TRUE) %do% {
    fit <- auto.arima(price.series[(n-trailing.hours):n], parallel = TRUE)
    forecast.value <- sum(forecast(fit, h=hours.ahead)$mean)
    gc()
    return(forecast.value)
  }
  forecast.series <- c(rep(0,start.value), forecast.series)
  
  forecast.result <- xts(x=forecast.series, order.by=forecast.index)
  return(forecast.result)
}

breakoutRawForecast <- function(price.xts, lookback=backtest.config$lookback.hours){
  raw.stoch <- SMI(price.xts,n=lookback)
  # http://qoppac.blogspot.co.uk/2016/05/a-simple-breakout-trading-rule.html
  # may want to use stoch function from TTR
  return(raw.stoch$SMI)
}

meanRevertingRawForecast <- function(price.xts, lookback=system.config$volatility.lookback){
  # simly invert the breakout logic
  raw.stoch <- SMI(price.xts,n=lookback)
  return(-1 * raw.stoch$SMI)
}

constantRawForecast <- function(constant, price.xts){
  return(xts(x=rep(constant, times=length(index(price.xts))), order.by = index(price.xts)))
}

# 8_32, 16_64, 32_128, 64_256, 128_512, 256_1024

breakout_8 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 8))
}

breakout_16 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 16))
}

breakout_32 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 32))
}

breakout_64 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 64))
}

breakout_128 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 128))
}

breakout_512 <- function(price.xts){
  return(breakoutRawForecast(price.xts, lookback = 512))
}

no_forecast_long <- function(price.xts){
  return(constantRawForecast(constant=10, price.xts=price.xts))
}

no_forecast_short <- function(price.xts){
  return(constantRawForecast(constant=-10, price.xts=price.xts))
}

auto_arima_24 <- function(price.xts){
  return(autoArimaRawForecast(price.xts = price.xts, hours.ahead = 24))
}

auto_arima_1 <- function(price.xts){
  return(autoArimaRawForecast(price.xts = Cl(price.xts), hours.ahead = 1, trailing.hours = 48))
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
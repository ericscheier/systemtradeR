volatilityAdjustedForecast <- function(price.xts, raw.forecast){
  
  price.xts <- if (is.OHLC(price.xts)) {
    Cl(price.xts)
  }
  else price.xts
  
  volatility.ema <- emaVolatility(price.xts)
  volatility.adjusted.forecast <- (raw.forecast)/(volatility.ema * price.xts)
  
  # Get rid of infinities when there is no volatility etc.
  volatility.adjusted.forecast <- replace(volatility.adjusted.forecast,
                                          which(volatility.adjusted.forecast==-Inf),
                                          c(-100))
  volatility.adjusted.forecast <- replace(volatility.adjusted.forecast,
                                          which(volatility.adjusted.forecast==Inf),
                                          c(100))
  return(volatility.adjusted.forecast)
}

scaledForecast <- function(volatility.adjusted.forecast){
  # apply.fromstart function doesn't work and is too slow. Consider using roll or RcppROll package for true scalar
  # forecast.scalar <- 10/apply.fromstart(abs(volatility.adjusted.ema), "mean")
  weighted.forecast.scalar <- 10/SMA(abs(volatility.adjusted.forecast),n=system.config$volatility.lookback*12)
  scaled.forecast <- volatility.adjusted.forecast * weighted.forecast.scalar
  # mean(abs(scaled.forecast), na.rm=T) # should be ~10 before capping
  return(scaled.forecast)
}

cappedForecast <- function(scaled.forecast){
  forecast.max <- system.config$forecast.cap
  forecast.min <- -1 * forecast.max
  
  capped.forecast <- xts(x=pmax(forecast.min,pmin(forecast.max, scaled.forecast)), order.by = index(scaled.forecast))
  return(capped.forecast)
}

cappedScaledForecast <- function(price.xts=NULL, forecast.name=NULL, ...){
  
  price.xts <- if (is.OHLC(price.xts)) {
    Cl(price.xts)
  }
  else price.xts
  
  raw.forecast <- do.call(forecast.name, args=list(price.xts))
  volatility.adjusted.forecast <- volatilityAdjustedForecast(price.xts, raw.forecast)
  scaled.forecast <- scaledForecast(volatility.adjusted.forecast)
  capped.forecast <- cappedForecast(scaled.forecast)
  
  return(capped.forecast)
}

rawForecastWeights <- function(){
  forecast.return.path <- "data/clean/forecast_returns.RDS"
  raw.forecast.weights <- rawWeights(return.path=forecast.return.path)
  saveRDS(raw.forecast.weights, relativePath("/data/clean/raw_forecast_weights.RDS"))
  
  plotWeights(weights.var=raw.forecast.weights, weights.name="raw_forecast_weights")
  return()
}

smoothedForecastWeights <- function(){
  raw.forecast.weights.path <- "/data/clean/raw_forecast_weights.RDS"
  smoothed.forecast.weights <- smoothedWeights(raw.weights.path=raw.forecast.weights.path)
  
  saveRDS(smoothed.forecast.weights, relativePath("/data/clean/smoothed_forecast_weights.RDS"))
  
  plotWeights(weights.var=smoothed.forecast.weights, weights.name="smoothed_forecast_weights")
  return(smoothed.forecast.weights)
}

simulateForecasts <- function(){
  start.time <- Sys.time()
  portfolio.forecasts <- system.config$portfolio.forecasts
  portfolio.pairs <- system.config$portfolio.pairs
  
  results.matrix <- 
    foreach(forecast.name=portfolio.forecasts, .combine='merge') %dopar% {
      poolForecasts(forecast.name=forecast.name)
    }
  
  results.matrix <- na.omit(results.matrix)
  forecast.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
  saveRDS(forecast.returns, file=relativePath("/data/clean/forecast_returns.RDS"))
  
  execution.time <- round(difftime(Sys.time(), start.time, units="mins"),2)
  print(paste0("Finished simulating forecast returns in ",execution.time," mins."))
}

poolForecasts <- function(forecast.name=NULL){
  portfolio.pairs <- system.config$portfolio.pairs
  pooled.results <- foreach(pair=portfolio.pairs, .combine="merge", .multicombine=FALSE
                            # , .export="system.config"
                            , .verbose=TRUE
  ) %dopar% {
    # forecast.name="no_forecast_long"
    # system.config$live
    # result.name <- paste(pair, forecast.name, sep="_")
    price.xts <- getPairData(pair=pair)
    capped.scaled.forecast <- simulateBacktest(pair=pair, forecast.name=forecast.name)
    names(capped.scaled.forecast) <- pair
    return(capped.scaled.forecast)
  }
  file.name <- paste0("/data/clean/",forecast.name,"_forecast_returns.RDS")
  saveRDS(pooled.results, file=relativePath(file.name))
  
  pooled.forecast <- rowSumXts(pooled.results, name=forecast.name)
  return(pooled.forecast)
}
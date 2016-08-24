
fullComboSimulation <- function(){
  functions <- c("simulateAllCombos", "rawComboWeights", "smoothedComboWeights", "parseCombos", "fullSystemBacktest")
  sapply(functions, runParallelFunc)
  backupComboSimulation()
}

backupCombosSimulation <- function(){
  # create a folder structure for backups: data, figures
    # http://stackoverflow.com/questions/4216753/check-existence-of-directory-and-create-if-doesnt-exist
  # save specs environment as RDS in top level
  # move all relevant data from data/clean to [backup]/data
    # combos(portfolio.forecasts, portfolio.pairs)_forecast_returns.RDS
    # combo_returns.RDS
    # raw_combo_weights.RDS
    # smoothed_combo_weights.RDS
    # (portfolio.pairs)_smoothed_forecast_weights.RDS
    # smoothed_instrument_weights.RDS
    # (portfolio.pairs)_forecast_returns.RDS
    # instrument_returns.RDS
    # (portfolio.forecasts)_instrument_returns.RDS
    # forecast_returns.RDS
  # move all relevant figures from figures/final to [backup]/figures
    # combos(portfolio.forecasts, portfolio.pairs)_ForecastSimulation.pdf
    # paste.together(portfolio.pairs)_fullSystem_ForecastSimulation.pdf
  return()
}

simulateAllCombos <- function(){
  start.time <- Sys.time()
  portfolio.forecasts <- system.config$portfolio.forecasts
  portfolio.pairs <- system.config$portfolio.pairs
  
  results.matrix <- 
    foreach(forecast.name=portfolio.forecasts, .combine='merge') %:%
    foreach(pair=portfolio.pairs, .combine = 'merge') %dopar% {
      combo.returns <- simulateBacktest(pairs=pair, forecast.name=forecast.name)
      combo.name <- paste(pairToSymbol(pair),forecast.name,sep="_")
      file.name <- paste0("/data/clean/",combo.name,"_forecast_returns.RDS")
      colnames(combo.returns) <- combo.name
      saveRDS(combo.returns, file=relativePath(file.name))
      return(combo.returns)
    }
  
  results.matrix <- na.locf(na.trim(results.matrix, sides = "left", is.na = "all"), na.rm=FALSE)
  results.matrx <- results.matrix[!duplicated(index(results.matrix)),]
  
  saveRDS(results.matrix, file=relativePath("/data/clean/raw_combo_account_values.RDS"))
  forecast.returns <- replaceLeadingZeros(Return.calculate(results.matrix)[2:nrow(results.matrix),])
  saveRDS(forecast.returns, file=relativePath("/data/clean/combo_returns.RDS"))
  
  execution.time <- round(difftime(Sys.time(), start.time, units="mins"),2)
  print(paste0("Finished simulating forecast returns in ",execution.time," mins."))
}

rawComboWeights <- function(){
  combo.return.path <- "data/clean/combo_returns.RDS"
  raw.combo.weights <- rawWeights(return.path=combo.return.path)
  saveRDS(raw.combo.weights, relativePath("/data/clean/raw_combo_weights.RDS"))
  
  # plotWeights(weights.var=raw.combo.weights, weights.name="raw_combo_weights")
  return()
}

smoothedComboWeights <- function(){
  raw.combo.weights.path <- "/data/clean/raw_combo_weights.RDS"
  smoothed.combo.weights <- smoothedWeights(raw.weights.path=raw.combo.weights.path)
  
  saveRDS(smoothed.combo.weights, relativePath("/data/clean/smoothed_combo_weights.RDS"))
  
  # plotWeights(weights.var=smoothed.combo.weights, weights.name="smoothed_combo_weights")
  return()
}

parseCombos <- function(){
  smoothed.combo.weights <- readRDS(relativePath(paste0("data/clean/","smoothed_combo_weights",".RDS")))
  symbols <- sapply(system.config$portfolio.pairs, pairToSymbol)
  for (symbol in symbols){
    # symbol <- "BTSBTC"
    symbol.columns <- grep(symbol, names(smoothed.combo.weights))
    symbol.forecast.weights <- smoothed.combo.weights[,symbol.columns]
    
    colnames(symbol.forecast.weights) <- gsub(paste0(symbol,"_"),"",colnames(symbol.forecast.weights))
    symbol.instrument.weight <- rowSumXts(symbol.forecast.weights, name=symbol)
    normalized.symbol.forecast.weights <- symbol.forecast.weights/coredata(symbol.instrument.weight)[,1]
    
    # chart.StackedBar(symbol.forecast.weights[.indexwday(symbol.forecast.weights)==1], colorset= tol12qualitative#rainbow12equal
    #                  , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
    #                  , main=paste0(symbol,"_smoothed_combo_weights"))
    saveRDS(normalized.symbol.forecast.weights, relativePath(paste0("/data/clean/",symbol,"_smoothed_forecast_weights.RDS")))
  }
  
  instrument.weights <- foreach(symbol=symbols, .combine=merge) %do% {
    symbol.columns <- grep(symbol, names(smoothed.combo.weights))
    symbol.forecast.weights <- smoothed.combo.weights[,symbol.columns]
    
    colnames(symbol.forecast.weights) <- gsub(paste0(symbol,"_"),"",colnames(symbol.forecast.weights))
    symbol.instrument.weight <- rowSumXts(symbol.forecast.weights, name=symbol)
    return(symbol.instrument.weight)
  }
  
  saveRDS(instrument.weights, relativePath(paste0("/data/clean/smoothed_instrument_weights.RDS")))
  
  # chart.StackedBar(instrument.weights[.indexwday(instrument.weights)==1], colorset= tol12qualitative#rainbow12equal
  #                  , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
  #                  , main="instrument_weights")
  
  
  raw.combo.returns <- readRDS(relativePath(paste0("data/clean/","combo_returns",".RDS")))
  instrument.returns <- foreach(symbol=symbols, .combine=merge) %do% {
    symbol.columns <- grep(symbol, names(raw.combo.returns))
    symbol.combo.returns <- raw.combo.returns[,symbol.columns]
    
    colnames(symbol.combo.returns) <- gsub(paste0(symbol,"_"),"",colnames(symbol.combo.returns))
    saveRDS(symbol.combo.returns, relativePath(paste0("data/clean/",symbol,"_forecast_returns.RDS")))
    symbol.return <- rowSumXts(symbol.combo.returns, name=symbol)
    return(symbol.return)
  }
  
  saveRDS(instrument.returns, relativePath("data/clean/instrument_returns.RDS"))
  
  forecast.names <- system.config$portfolio.forecasts
  # raw.combo.returns <- readRDS(relativePath(paste0("data/clean/","combo_returns",".RDS")))
  forecast.returns <- foreach(forecast.name=forecast.names, .combine=merge) %do% {
    forecast.columns <- grep(forecast.name, names(raw.combo.returns))
    forecast.combo.returns <- raw.combo.returns[,forecast.columns]
    
    colnames(forecast.combo.returns) <- gsub(paste0("_",forecast.name),"",colnames(forecast.combo.returns))
    saveRDS(forecast.combo.returns, relativePath(paste0("data/clean/",forecast.name,"_instrument_returns.RDS")))
    forecast.return <- rowSumXts(forecast.combo.returns, name=forecast.name)
    return(forecast.return)
  }
  
  saveRDS(forecast.returns, relativePath("data/clean/forecast_returns.RDS"))
  return()
}

rebuildComboReturns <- function(){
  portfolio.forecasts <- system.config$portfolio.forecasts
  portfolio.pairs <- system.config$portfolio.pairs
  
  results.matrix <- 
    foreach(forecast.name=portfolio.forecasts, .combine='merge') %:%
    foreach(pair=portfolio.pairs, .combine = 'merge') %dopar% {
      # combo.returns <- simulateBacktest(pairs=pair, forecast.name=forecast.name)
      combo.name <- paste(pairToSymbol(pair),forecast.name,sep="_")
      file.name <- paste0("/data/clean/",combo.name,"_forecast_returns.RDS")
      # colnames(combo.returns) <- combo.name
      combo.returns <- readRDS(file=relativePath(file.name))
      return(combo.returns)
    }
  
  results.matrix <- na.trim(results.matrix, sides = "left", is.na = "all")
  saveRDS(results.matrix, file=relativePath("/data/clean/raw_combo_account_values.RDS"))
  forecast.returns <- na.trim(replaceLeadingZeros(Return.calculate(results.matrix)), sides="left",
                              is.na="all")
  saveRDS(forecast.returns, file=relativePath("/data/clean/combo_returns.RDS"))
  
  return(forecast.returns)
}
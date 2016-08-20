tol11qualitative=c("#332288", "#6699CC", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#661100", "#CC6677", "#882255", "#AA4499")

forecast.returns <- readRDS(relativePath("/data/clean/forecast_returns.RDS"))
chart.CumReturns(forecast.returns, legend.loc = "topleft", colorset = tol11qualitative,
                 main="Cumulative Pooled Forecast Returns (equally weighted)")

for(forecast.name in system.config$portfolio.forecasts){
  unpooled.forecast.returns <- readRDS(paste0("data/clean/",forecast.name,"_forecast_returns.RDS"))
  chart.TimeSeries(unpooled.forecast.returns, legend.loc = "topleft", colorset=tol11qualitative,
                   main=paste0("Unpooled ",forecast.name," Returns by Asset"))
}


all.colors = sample(grDevices::colors()[grep('gr(a|e)y', grDevices::colors(), invert = T)],
                    length(system.config$portfolio.pairs) * length(system.config$portfolio.forecasts))

combo.returns <- readRDS(relativePath(paste0("data/clean/","combo_returns",".RDS")))
chart.CumReturns(combo.returns, legend.loc = "topleft", colorset=all.colors,
                 main=paste0("Unpooled ",forecast.name," Returns by Asset"))


raw.combo.weights <- readRDS(relativePath(paste0("data/clean/","raw_combo_weights",".RDS")))
chart.StackedBar(last(raw.combo.weights,24*30), colorset=all.colors  #rainbow12equal
                 , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                 , cex.legend = .2
                 , main="raw_combo_weights")

smoothed.combo.weights <- readRDS(relativePath(paste0("data/clean/","smoothed_combo_weights",".RDS")))
chart.StackedBar(smoothed.combo.weights[.indexwday(smoothed.combo.weights)==1], colorset=all.colors #rainbow12equal
                 , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                 , main="smoothed_combo_weights")

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

chart.StackedBar(instrument.weights[.indexwday(instrument.weights)==1], colorset= tol12qualitative#rainbow12equal
                 , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                 , main="instrument_weights")


raw.combo.returns <- readRDS(relativePath(paste0("data/clean/","combo_returns",".RDS")))
instrument.returns <- foreach(symbol=symbols, .combine=merge) %do% {
  symbol.columns <- grep(symbol, names(raw.combo.returns))
  symbol.combo.returns <- raw.combo.returns[,symbol.columns]
  
  colnames(symbol.combo.returns) <- gsub(paste0(symbol,"_"),"",colnames(symbol.combo.returns))
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
  forecast.return <- rowSumXts(forecast.combo.returns, name=forecast.name)
  return(forecast.return)
}

saveRDS(forecast.returns, relativePath("data/clean/forecast_returns.RDS"))



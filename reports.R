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
                 main=paste0("Combo Returns by Asset"))


raw.combo.weights <- readRDS(relativePath(paste0("data/clean/","raw_combo_weights",".RDS")))
chart.StackedBar(raw.combo.weights[.indexwday(raw.combo.weights)==1], colorset=all.colors  #rainbow12equal
                 , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                 , cex.legend = .2
                 , main="raw_combo_weights")

smoothed.combo.weights <- readRDS(relativePath(paste0("data/clean/","smoothed_combo_weights",".RDS")))
chart.StackedBar(smoothed.combo.weights[.indexwday(smoothed.combo.weights)==1], colorset=all.colors #rainbow12equal
                 , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                 , main="smoothed_combo_weights")



tol11qualitative=c("#332288", "#6699CC", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#661100", "#CC6677", "#882255", "#AA4499")

forecast.returns <- readRDS(relativePath("/data/clean/forecast_returns.RDS"))
chart.CumReturns(forecast.returns, legend.loc = "topleft", colorset = tol11qualitative,
                 main="Cumulative Pooled Forecast Returns (equally weighted)")

for(forecast.name in system.config$portfolio.forecasts){
  unpooled.forecast.returns <- readRDS(paste0("data/clean/",forecast.name,"_forecast_returns.RDS"))
  chart.TimeSeries(unpooled.forecast.returns, legend.loc = "topleft", colorset=tol11qualitative,
                   main=paste0("Unpooled ",forecast.name," Returns by Asset"))
}


investment.universe <- loadInvestmentUniverse()
investment.universe[!investment.universe$is.restricted,]


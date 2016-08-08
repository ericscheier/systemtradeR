volatilityAdjustedForecast <- function(price.xts, raw.forecast){
  volatility.ema <- emaVolatility(price.xts)
  volatility.adjusted.forecast <- (raw.forecast)/(volatility.ema * price.xts)
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
  forecast.max <- 20
  forecast.min <- -1 * forecast.max
  
  capped.forecast <- xts(x=pmax(forecast.min,pmin(forecast.max, scaled.forecast)), order.by = index(scaled.forecast))
  return(capped.forecast)
}

cappedScaledForecast <- function(forecast.name=NULL, price.xts=NULL){
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
  return(raw.forecast.weights)
}

smoothedForecastWeights <- function(){
  raw.forecast.weights.path <- "/data/clean/raw_forecast_weights.RDS"
  smoothed.forecast.weights <- smoothedWeights(raw.weights.path=raw.forecast.weights.path)
  
  saveRDS(smoothed.forecast.weights, relativePath("/data/clean/smoothed_forecast_weights.RDS"))
  
  pdf.name <- paste0("figures/final/smoothed_forecast_weights.pdf")
  pdf(pdf.name)
  chart.StackedBar(smoothed.forecast.weights, colorset=rainbow12equal)
  dev.off()
  return(smoothed.forecast.weights)
}

forecastDiversificationMultipler <- function(){
  forecast.returns.path <- "/data/clean/forecast_returns.RDS"
  forecast.weights.path <- "/data/clean/smoothed_forecast_weights.RDS"
  
  
  forecast.diversification.multiplier <- diversificationMultiplier(returns.path=forecast.returns.path,
                                                                   weights.path=forecast.weights.path)
  
  return(forecast.diversification.multiplier)
}

simulateForecasts <- function(){
  # registerDoParallel()
  start.time <- Sys.time()
  portfolio.forecasts <- system.config$portfolio.forecasts
  
  results.matrix <- xts(x=NA, order.by=floor_date(system.config$last.exchange.rate,unit="hour"))
  
  for(forecast.name in portfolio.forecasts){
    simulation.results <- poolForecasts(forecast.name=forecast.name)
    
    results.matrix <- merge.xts(results.matrix, simulation.results)
  }
  
  results.matrix$results.matrix <- NULL
  colnames(results.matrix) <- portfolio.forecasts
  forecast.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
  saveRDS(forecast.returns, file=paste0(getwd(), "/data/clean/forecast_returns.RDS"))
  
  execution.time <- round(difftime(Sys.time(), start.time, units="hours"),2)
  print(paste0("Finished simulating forecast returns in ",execution.time," hours."))
  return(paste0("Finished simulating forecast returns in ",execution.time," hours."))
}

poolForecasts <- function(forecast.name=NULL){
  start.time <- Sys.time()
  portfolio.pairs <- system.config$portfolio.pairs
  
  results.matrix <- xts(x=NA, order.by=floor_date(system.config$last.exchange.rate,unit="hour"))
  
  for(pair in portfolio.pairs){
    simulation.results <- simulateForecast(pair=pair, forecast.name=forecast.name)
    
    results.matrix <- merge.xts(results.matrix, simulation.results)
  }
  
  results.matrix$results.matrix <- NULL
  results.matrix <- na.omit(results.matrix)
  colnames(results.matrix) <- portfolio.pairs
  saveRDS(results.matrix, file=paste0(getwd(), "/data/clean/",forecast.name,"_forecast_returns.RDS"))
  
  pooled.account.values <- xts(x=rowSums(results.matrix,na.rm=TRUE), order.by=index(results.matrix))
  
  execution.time <- round(difftime(Sys.time(), start.time, units="hours"),2)
  print(paste0("Finished simulating ",forecast.name," returns in ",execution.time," hours."))
  
  return(pooled.account.values)
}

simulateForecast <- function(pair=NULL, forecast.name=NULL){
  # if(!is.null(dev.list())){dev.off(which=dev.list())}
  # .pardefault <- par(no.readonly = T)
  
  
  print(paste0("Simulating forecast returns for ",pair,". Forecast: ",forecast.name))
  split.pair <- unlist(strsplit(pair, "_"))
  base <- split.pair[1]
  asset <- split.pair[2]
  
  e.rate <- paste0('USDT','_',base)
  # pair <- "BTC_ETH"
  
  lookback.hours <- system.config$lookback.hours
  volatility.target <- system.config$volatility.target
  minimum.order.size <- system.config$minimum.order.size
  minimum.position.change <- system.config$minimum.position.change
  # poloniex.ohlc.5m <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE)
  # ETHBTC.5m <- poloniex.ohlc.5m
  # # ETHBTC.5m <- ldply(poloniex.ohlc.5m, data.frame)  # Convert OHLCV to data.frame
  # ETHBTC.5m$date <- as.POSIXct(ETHBTC.5m$date,  tz="UTC")
  # 
  # # Create 'xts' object:
  # ethbtc.30m.xts <- xts(ETHBTC.5m[, 2:8], order.by = ETHBTC.5m$date)  # is.OHLCV(ETHBTC.30m)
  
  
  
  # Rebuild empty environments if RStudio's "Clear All" has been used:
  
  ## Subsetting: components of mktdata must be same length
  trade.target.data <- getPairData(pair=pair, ohlc=TRUE, volume=TRUE)
  fx.rate.data <- getPairData(pair=e.rate, ohlc=FALSE, volume=FALSE)
  # first.hour <- as.POSIXlt(index(head(trade.target.data,1)))
  # first.hour <- ceiling_date(max(c(first.hour, system.config$first.exchange.rate)), unit="hour")
  # trading.start.hour <- first.hour + hours(system.config$volatility.lookback)
  last.hour <- as.POSIXlt(index(tail(trade.target.data,1)))
  last.hour <- floor_date(min(c(last.hour, system.config$last.exchange.rate)), unit="hour")
  first.hour <- last.hour - hours(lookback.hours)
  date.subset <- paste(first.hour,last.hour,sep="::")
  
  assign("trade.target", paste0(asset,base), envir=.GlobalEnv)
  assign("fx.rate",paste0(base,"USD"), envir=.GlobalEnv) #paste0("USD",base)
  
  assign(trade.target, trade.target.data[date.subset], envir=.GlobalEnv) # getHourlyPairData
  assign(fx.rate, fx.rate.data[date.subset], envir=.GlobalEnv) #getHourlyPairData
  
  # combo.prices <- na.omit(merge(BTC_ETH, BTCUSD))
  # BTC_ETH <- BTC_ETH[index(combo.prices)]
  # BTCUSD <- BTCUSD[index(combo.prices)]
  # ETHBTC2 <- to.hourly(ethbtc.30m.xts[,c("open", "high", "low", "close", "volume")], indexAt="endof", OHLC=FALSE) # ["2015-09-01::"]
  
  ## Define instruments
  currency(c(base, asset, 'USD')) # ls_currencies()
  exchange_rate(trade.target, currency = base, counter_currency = asset, tick_size = 0.00001)
  exchange_rate(fx.rate, currency = 'USD', counter_currency = base, tick_size = 0.01)  #exchange_rate(fx.rate, currency = 'USD', counter_currency = base, tick_size = 0.01)
  
  initDate = as.character(as.Date(min(index(get(trade.target, envir=.GlobalEnv)))-days(1))) # '2015-09-01'
  initBTC <- .5
  init.target <- 0
  initUSD <- system.config$poloniex.margin.value * system.config$current.exchange.rate
  initEq <- initUSD
  
  portfolio.name <- "bitcoin_margin"
  account.name <- "poloniex"
  strategy.name <- "asset_allocation"
  symbols <- c(trade.target) #, "BTCUSD")
  
  specificForecast <- function(price.xts){
    return(cappedScaledForecast(forecast.name=forecast.name, price.xts=price.xts))
  }
  
  addForecast <- newTA(FUN=specificForecast, preFUN=closeOfXts)
  chartSeries(x=trade.target.data, subset=date.subset, TA='addForecast()')
  
  ## To rerun
  rm.strat(portfolio.name)
  rm.strat(account.name)
  rm.strat(strategy.name)
  
  ## Initialize Portfolio, Account, and Orderbook initDate = initDate,
  initPortf(name = portfolio.name, symbols = symbols, initPosQty = init.target,  initDate = initDate, currency = "BTC")  # getPortfolio(portfolio.name)
  initAcct(name = account.name, portfolios = portfolio.name, initEq = initEq, initDate = initDate, currency = "USD")  # getAccount(account.name)
  initOrders(portfolio = portfolio.name, initDate = initDate, symbols = symbols)  # getOrderBook(portfolio.name)
  strategy(strategy.name, store = TRUE)  # summary(getStrategy(strategy.name))
  
  ## Indicators
  # # Parameters
  # .nFast = 60 # 90
  # .nSlow = 130
  # .nSig = 45 # 75
  
  # add.indicator(strategy.name, name = "MACD", arguments = list(x=quote(Cl(mktdata))), label='MACD')
  add.indicator(strategy.name, name= "emaVolatility", arguments = list(price.xts=quote(Cl(mktdata))), label='instrument.volatility')
  add.indicator(strategy.name, name="cappedScaledForecast", arguments = list(forecast.name=forecast.name, price.xts=quote(Cl(mktdata))), label='combined.instrument.forecast')
  add.indicator(strategy.name, name="xtsIdentity", arguments = list(price.xts=quote(Cl(mktdata))
                                                                    ,exchange.rate=quote(Cl(get(fx.rate, envir=.instrument)))), label="exchange.rate")
  
  assign("mktdata", applyIndicators(strategy.name, mktdata=get(trade.target, envir=.instrument)), envir=.GlobalEnv)
  # print(str(get("mktdata", envir=.GlobalEnv)))
  
  
  ## Signals
  # See Also: applySignals add.indicator link{add.rule} sigComparison sigCrossover sigFormula sigPeak sigThreshold
  # MACD
  # add.signal(strategy.name, "hourlyRebalance")
  # add.signal(strategy.name, "sigCrossover",
  #            arguments = list(columns = c("macd.MACD", "signal.MACD"), relationship = "gt"),
  #            label = 'longEntry')
  # add.signal(strategy.name, "sigCrossover",
  #            arguments = list(columns = c("signal.MACD", "macd.MACD"), relationship = "gt"),
  #            label = 'signal.gt.macd')
  # add.signal(strategy.name, "sigThreshold",
  #            arguments = list(column = "macd.MACD", threshold = 0, relationship = "gte"),
  #            label = 'macd.gte.threshold')
  # add.signal(strategy.name, "sigAND",
  #            arguments=list(columns=c('signal.gt.macd', 'macd.gte.threshold'), cross=FALSE),
  #            label="longExit")
  
  # # Order sizing
  # osFixedDollar <- function(timestamp, orderqty, portfolio, symbol, ruletype, ...)
  # {
  #   ClosePrice <- as.numeric(Cl(mktdata[timestamp,]))
  #   orderqty <- round(tradeSize/ClosePrice,-2)
  #   return(orderqty)
  # }
  # tradeSize <- initBTC/2
  
  # osRebalance <- function(timestamp, orderqty, portfolio, symbol, ruletype, ...)
  # {
  #   ClosePrice <- as.numeric(Cl(mktdata[timestamp,]))
  #   orderqty <- round(tradeSize/ClosePrice,-2)
  #   return(orderqty)
  # }
  
  # # Custom Rule
  # entry
  # add.rule(strat.st,name='ruleSignal', 
  #          +          arguments = list(sigcol="signal.gt.zero",
  #                                      +                           sigval=TRUE, orderqty=1000000, 
  #                                      +                           ordertype='market', 
  #                                      +                           orderside='long', 
  #                                      +                           threshold=NULL,
  #                                      +                           osFUN='osMaxPos'),
  #          +          type='enter',
  #          +          label='enter')
  
  # # exit
  # > add.rule(strat.st,name='ruleSignal', 
  #            +          arguments = list(sigcol="signal.lt.zero",
  #                                        +                           sigval=TRUE, orderqty='all', 
  #                                        +                           ordertype='market', 
  #                                        +                           orderside='long', 
  #                                        +                           threshold=NULL,
  #                                        +                           orderset='exit2'),
  #            +          type='exit',
  #            +          label='exit')
  
  
  
  
  # new.position <- current.position + transaction.size
  
  
  
  # addPosLimit(portfolio = portfolio, 
  #             symbol = symbol, 
  #             timestamp = timestamp, 
  #             maxpos = new.position, 
  #             longlevels = 1, 
  #             minpos = new.position, 
  #             shortlevels = 1)
  # 
  # pos.limit <- getPosLimit(portfolio=portfolio,
  #             symbol=symbol,
  #             timestamp=timestamp)
  # print(paste(timestamp, pos.limit, sep=": "))
  
  
  ## Rules
  # add.rule(strategy.name, name="ruleSignal", arguments =
  #            list(sigcol="Cl.gt.SMA", sigval=TRUE, orderqty='trigger',
  #                 osFUN='osMaxPos', ordertype='market', orderside='long',
  #                 pricemethod='market',TxnFees=0), type='enter', path.dep=TRUE)
  # add.rule(strategy.name, name='ruleSignal', arguments =
  #            list(sigcol="X1", sigval=TRUE, orderqty=,
  #                 ordertype='market', orderside='long',
  #                 pricemethod='market',TxnFees=0), type='exit', path.dep=TRUE)
  
  add.rule(strategy.name, 'systematicRebalance',
           arguments=list(rebalance_on='hours',
                          ref.price.col="close",
                          exchange.rate.col="X1.exchange.rate",
                          instrument.volatility.col="X1.instrument.volatility",
                          combined.instrument.forecast.col="X1.combined.instrument.forecast",
                          initEq=initEq,
                          volatility.target=volatility.target,
                          minimum.order.size=minimum.order.size,
                          minimum.position.change=minimum.position.change
           ),
           type='rebalance',
           label='rebalance')
  # # Entry
  # add.rule(strategy.name,name='ruleSignal',
  #          arguments = list(sigcol="longEntry",
  #                           sigval=TRUE,
  #                           orderqty=100,
  #                           ordertype='market',
  #                           orderside='long',
  #                           osFUN='osFixedDollar'),
  #          type='enter',
  #          label='EnterLONG',
  #          storefun=FALSE)
  # 
  # # Exit
  # add.rule(strategy.name,name='ruleSignal',
  #          arguments = list(sigcol="longExit",
  #                           sigval=TRUE,
  #                           orderqty='all',
  #                           ordertype='market',
  #                           orderside='long',
  #                           osFUN='osFixedDollar'),
  #          type='exit',
  #          label='ExitLONG',
  #          storefun=FALSE)
  
  ## Run it
  applyStrategy.rebalancing(strategy.name,
                            portfolios=portfolio.name, debug=T,
                            mktdata=get("mktdata", envir=.GlobalEnv),
                            parameters=list(),
                            verbose=TRUE,
                            envir=.instrument)
  
  updatePortf(Portfolio=portfolio.name,Dates=paste('::',as.Date(Sys.time()),sep=''))
  updateAcct(account.name)
  updateEndEq(account.name)
  
  ## Evaluate
  t(tradeStats(portfolio.name))
  getTxns(portfolio.name, Symbol = trade.target)
  perTradeStats(portfolio.name, trade.target)
  pdf.name <- paste0("figures/final/",pair,"_",forecast.name,"_ForecastSimulation.pdf")
  pdf(pdf.name)
  chart.Posn(Portfolio=portfolio.name,Symbol=symbols, type = "line", log.scale = F)
  # par(.pardefault)
  p <- getPortfolio(portfolio.name)
  a <- getAccount(account.name)
  xyplot(a$summary,type="h",col=4)
  # par(.pardefault)
  equity <- a$summary$End.Eq
  plot(equity,main="Forecast Equity Curve")
  # par(.pardefault)
  ret <- na.omit(Return.calculate(equity))
  ret <- ret[is.finite(ret)]
  
  charts.PerformanceSummary(ret, colorset = bluefocus,
                            main=paste0(trade.target,"_",forecast.name," Forecast Performance"))
  dev.off()
  # par(.pardefault)
  # try(slackr_upload(pdf.name, channels = "reports"))
  # plot(add_Vo())
  # plot(add_MACD(fast=.nFast, slow=.nSlow, signal=.nSig,maType="EMA"))  # nFast = 60, nSlow = 180, nSig = 40, maType = 'EMA'
  
  # ## Parameter distribution testing
  # add.distribution(strategy.name,
  #                  paramset.label = 'optEMA',
  #                  component.type = 'indicator',
  #                  component.label = 'MACD',
  #                  variable = list(nFast = 60:80),
  #                  label = 'NFAST')
  # 
  # add.distribution(strategy.name,
  #                  paramset.label = 'optEMA',
  #                  component.type = 'indicator',
  #                  component.label = 'MACD',
  #                  variable = list(nSlow = 180:200),
  #                  label = 'NSLOW')
  # 
  # results <- apply.paramset(strategy.name, paramset.label = "optEMA", portfolio=portfolio.name, account=account.name, nsamples=0)
  return(equity)
}
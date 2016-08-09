getPairData <- function(pair=NULL, ohlc=FALSE, volume=FALSE){
  columns <- c("close")
  if(ohlc){columns <- c("high", "low", "open", columns)}
  if(volume){columns <- c(columns, "volume")}
  ohlc.prices <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE) # five minute frequency
  five.price.xts <- xts(x=ohlc.prices[,columns]
                        , order.by = as.POSIXct(ohlc.prices[,"date"], origin = "1970-01-01", format="%Y-%m-%d %H:%M:%S")
                        , tzone = "UTC")
  names(five.price.xts) <- columns
  return(five.price.xts)
}

getHourlyPairData <- function(pair=NULL, ohlc=FALSE, volume=FALSE){
  five.price.xts <- getPairData(pair, ohlc=ohlc, volume=volume)
  # columns <- colnames(five.price.xts)
  hour.price.xts <- to.hourly(five.price.xts, OHLC=FALSE, indexAt="endof")
  # names(hour.price.xts) <- columns
  return(hour.price.xts)
}

getExchangeRate <- function(pair="USDT_BTC"){
  five.price.xts <- getPairData(pair)
  exchange.rate <- as.numeric(tail(five.price.xts,1))
  return(exchange.rate)
}



combinedInstrumentForecast <- function(pair=NULL, five.minute.price.xts=NULL){
  # five.price.xts <- getPairData(pair)
  # returns <- diff(log(ohlc.prices[,"weightedAverage"]))
  combined.instrument.forecast <- 10
  
  # Apply range bounds on forecasts
  forecast.max <- 20
  forecast.min <- (-1)*forecast.max
  combined.instrument.forecast <- max(min(combined.instrument.forecast,forecast.max),forecast.min)
  return(combined.instrument.forecast)
}

# need to add volatility calculations, volatility adjutment, and combining forecasts for staunch systems trader
calculateVolatility <- function(pair=NULL, hour.price.xts=NULL){
  if(is.null(hour.price.xts)){
    hour.price.xts <- getHourlyPairData(pair)
  }
  volatility.lookback <- system.config$volatility.lookback
  
  # we want hourly vol looking back x hours
  percentage.change <- na.omit(tail(CalculateReturns(hour.price.xts), volatility.lookback)^2)
  calculated.volatility <- sqrt(EMA(percentage.change, n=36))
  return(na.omit(calculated.volatility))
}

cashVolatilityTarget <- function(exchange.rate=getExchangeRate()){
  account.value=system.config$poloniex.margin.value
  # returns the cash volatility target in USDT
  volatility.target <- system.config$volatility.target
  cash.volatility.target <- account.value * volatility.target * exchange.rate
  return(cash.volatility.target)
}

instrumentValueVolatility <- function(exchange.rate=getExchangeRate(), pair=NULL, hour.price.xts=NULL){
  if(is.null(hour.price.xts)){
    block.size <- getExchangeRate(pair=pair)     # minimum.order.size <- system.config$minimum.order.size
  }
  else {
    block.size <- as.numeric(tail(hour.price.xts,1))
  }
  volatility.lookback <- system.config$volatility.lookback
  # hour.price.xts <- getHourlyPairData(pair)
  block.value <- block.size * .01 # change in price when block moves 1%, BTC/XRP
  price.volatility <- 100*as.numeric(tail(calculateVolatility(pair, hour.price.xts=hour.price.xts),1)) # ewma of 36 trading periods
  instrument.currency.volatility <- block.value * price.volatility # expected hourly profit/loss in instrument units
  ## ^^ can be simplified to block.size * price.volatility when there is one asset per block (i.e. equities, raw FX)
  ## However, framework adapts to futures, etc.
  ## We are calculating the impact a % price move in the asset has on our bottom line per [hour], then
  ## How many % price moves we should expect per [hour]
  instrument.value.volatility <- instrument.currency.volatility * exchange.rate # instrument.currency.volatility converted to account value currency
  return(instrument.value.volatility)
}

volatilityScalar <- function(pair=NULL, hour.price.xts=NULL){
  cash.volatility.target=cashVolatilityTarget()
  instrument.value.volatility=instrumentValueVolatility(pair=pair, hour.price.xts = hour.price.xts)
  volatility.scalar <- cash.volatility.target/instrument.value.volatility # unitless
  return(volatility.scalar)
}

productionInstrumentVolatility <- function(pair=NULL, five.minute.price.xts=NULL){
  if(is.null(five.minute.price.xts)){
    five.minute.price.xts <- getPairData(pair)
  }
  instrument.volatility <- as.numeric(tail(emaVolatility(five.minute.price.xts),1))
  return(instrument.volatility)
}

productionSubsystemForecast <- function(pair=NULL, five.minute.price.xts=NULL){
  if(is.null(five.minute.price.xts)){
    five.minute.price.xts <- getPairData(pair)
  }
  subsystem.forecast <- as.numeric(tail(combinedForecast(five.minute.price.xts),1))
  return(subsystem.forecast)
}

productionSubsystemPosition <- function(pair=NULL, subsystem.forecast=NULL, 
                                        instrument.volatility=NULL, five.minute.price.xts=NULL){
  if(is.null(five.minute.price.xts)){
    five.minute.price.xts <- getPairData(pair)
  }
  if(is.null(subsystem.forecast)){
    subsystem.forecast <- productionSubsystemForecast(pair=pair,
                                                       five.minute.price.xts=five.minute.price.xts)
  }
  if(is.null(instrument.volatility)){
    instrument.volatility <- productionInstrumentVolatility(pair=pair,
                                                       five.minute.price.xts=five.minute.price.xts)
  }
  # hour.price.xts <- to.hourly(five.minute.price.xts, OHLC=FALSE, indexAt="endof")
  # volatility.scalar=volatilityScalar(pair=pair, hour.price.xts=hour.price.xts)
  # combined.instrument.forecast=combinedInstrumentForecast(pair=pair, five.minute.price.xts=five.minute.price.xts)
  # system.forecast.average = 10 # by design this should be 10
  # subsystem.position <- (volatility.scalar * combined.instrument.forecast)/system.forecast.average
  ref.price <- as.numeric(tail(five.minute.price.xts,1))
  
  
  
  subsystem.position <- subsystemPosition(ref.price=ref.price
                                          , total.equity=system.config$poloniex.margin.value
                                          , volatility.target=system.config$volatility.target
                                          , exchange.rate=system.config$current.exchange.rate
                                          , instrument.volatility=instrument.volatility
                                          , instrument.forecast=subsystem.forecast)
  return(subsystem.position)
}

subsystemPosition <- function(ref.price, total.equity
                              , volatility.target
                              , exchange.rate
                              , instrument.volatility
                              , instrument.forecast){
  
  block.value <- ref.price * .01
  cash.volatility.target <- total.equity * volatility.target # * (1/exchange.rate)
  instrument.currency.volatility <- block.value * instrument.volatility * 100
  instrument.value.volatility <- instrument.currency.volatility * exchange.rate
  volatility.scalar <- cash.volatility.target/instrument.value.volatility
  system.forecast.average <- 10 # by design, but can make dynamic
  subsystem.position <- (volatility.scalar * instrument.forecast)/system.forecast.average
  subsystem.position <- ifelse(is.na(subsystem.position), 0, subsystem.position)
  subsystem.position <- ifelse(subsystem.position * ref.price * exchange.rate > total.equity, total.equity/(ref.price * exchange.rate), subsystem.position)
  return(subsystem.position)
}

emaVolatility <- function(price.xts){
  # expects 5-min close of price data
  ema.volatility <- EMA(sqrt(CalculateReturns(price.xts)^2), n=36*(60/5)) * sqrt(60/5)
  colnames(ema.volatility) <- NULL
  return(ema.volatility)
}

weightedForecasts <- function(price.xts){
  forecast.weights <- xts(order.by=index(price.xts))
  ###~~~!!!~~~###
  ## Not sure whether weights need to be lagged by a day. Need to evaluate in depth!
  fw <- readRDS(relativePath("/data/clean/smoothed_forecast_weights.RDS"))
  ###~~~!!!~~~###
  forecast.weights <- na.locf(merge(forecast.weights, fw), na.rm = FALSE)
  forecast.diversification.multiplier <- forecastDiversificationMultipler()
  capped.scaled.forecasts <- xts(x=rbind(sapply(names(fw), cappedScaledForecast, price.xts=price.xts))
                                 , order.by = index(price.xts))
  
  weighted.forecasts <- forecast.weights * capped.scaled.forecasts[,colnames(forecast.weights)] * forecast.diversification.multiplier
  return(weighted.forecasts)
}

combinedForecast <- function(price.xts){
  weighted.forecasts <- weightedForecasts(price.xts)
  combined.forecast <- xts(x=rowSums(weighted.forecasts, na.rm=FALSE), order.by=index(price.xts))
  
  combined.forecast <- cappedForecast(combined.forecast)
  colnames(combined.forecast) <- NULL
  return(combined.forecast)
}

xtsIdentity <- function(price.xts, exchange.rate){
  xts.identity <- exchange.rate[index(price.xts),]
  colnames(xts.identity) <- NULL
  return(xts.identity)
}

percentFee <- function(TxnQty, TxnPrice, Symbol, ...){
  return(-1*abs(0.0025 * TxnQty * TxnPrice)) # system.config$transaction.fee, need to add without throwing error
}

smoothedWeights <- function(raw.weights.path=NULL){
  ema.n <- system.config$volatility.lookback #make a global parameter?
  
  raw.weights <- readRDS(relativePath(raw.weights.path))
  smoothed.weights <- na.omit(xts(x=apply(raw.weights, 2, EMA, n=ema.n)
                                             , order.by=index(raw.weights)))
  
  # chart.StackedBar(smoothed.weights, colorset=rainbow12equal)
  return(smoothed.weights)
}

rawWeights <- function(return.path=NULL){
  returns <- na.omit(readRDS(relativePath(return.path)))
  returns <- removeLeadingZeros(returns.xts=returns)
  instruments <- colnames(returns)
  
  # r.df <- data.frame(replicate(length(instruments),rnorm(nrow(returns), mean=0, sd=.01)))
  # names(r.df) <- instruments
  # 
  # rand.returns <- xts(x=r.df, order.by=index(returns))
  
  init.portf <- portfolio.spec(assets=instruments)
  init.portf <- add.constraint(portfolio=init.portf, type="full_investment")
  init.portf <- add.constraint(portfolio=init.portf, type="long_only")
  init.portf <- add.objective(portfolio=init.portf, type="return", name="mean")
  init.portf <- add.objective(portfolio=init.portf, type="risk", name="StdDev")
  
  daily.returns <- aggregate(x=returns, by=date, FUN=sum)
  
  # maxSR.lo.ROI <- optimize.portfolio(R=returns, portfolio=init.portf,
  #                                  optimize_method="ROI",
  #                                  maxSR=TRUE, trace=TRUE)
  
  opt.dn <- optimize.portfolio.rebalancing(R=daily.returns, portfolio=init.portf,
                                           # training_period=3,
                                           optimize_method="ROI",
                                           maxSR=TRUE, trace=TRUE,
                                           rebalance_on="days")
  
  # df.con = portfolio.spec(assets = instruments)
  # df.con = add.constraint(portfolio = df.con, type = "long_only")
  # df.con = add.constraint(portfolio = df.con, type="weight_sum",min_sum=0.99, max_sum=1.01)
  # df.con = add.objective(portfolio = df.con, type="return", name="mean")
  # df.con <- add.objective(portfolio=df.con, type="risk", name="StdDev")
  # , target=log(volatility.target+1))
  # window.end <- length(subsystem.returns)
  # window.start <- window.end - volatility.lookback
  # rp <- random_portfolios(df.con, 1000, "sample")
  
  
  
  # registerDoParallel()
  # opt.dn <- optimize.portfolio.rebalancing(R = daily.returns, portfolio = df.con
  #                                          , optimize_method = "ROI", maxSR=TRUE, trace=FALSE #, rp=rp
  #                                          , rebalance_on="days")
  
  print(paste0("Weight Optimization time: ",opt.dn$elapsed_time))
  
  raw.weights <- na.omit(extractWeights(opt.dn))
  return(raw.weights)
}

diversificationMultiplier <- function(returns.path=NULL, weights.path=NULL){
  
  returns <- readRDS(relativePath(returns.path))
  weights <- readRDS(relativePath(weights.path))
  
  # check that instrument weights sum to 1
  returns <- na.omit(returns)
  weights <- tail(weights, 1)
  weights <- array(weights/sum(weights))
  # print(sum(instrument.weights==1))
  correlation.matrix <- cor(returns)
  # floor negative correlations to 0
  diversification.multiplier <- 1/sqrt(tcrossprod(crossprod(weights, correlation.matrix), weights))
  
  diversification.multiplier.max <- 2.5
  diversification.multiplier <- min(as.numeric(diversification.multiplier)
                                               ,diversification.multiplier.max)
  
  return(diversification.multiplier)
}

# generalize to diversificationMultipler function to help building forecastDiversificationMultiplier later
instrumentDiversificationMultiplier <- function(){
  subsystem.returns.path <- "/data/clean/subsystem_returns.RDS"
  instrument.weights.path <- "/data/clean/smoothed_instrument_weights.RDS"
  
  
  instrument.diversification.multiplier <- diversificationMultiplier(returns.path=subsystem.returns.path,
                                                                     weights.path=instrument.weights.path)
  
  return(instrument.diversification.multiplier)
}
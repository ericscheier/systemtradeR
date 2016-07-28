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

productionSubsystemPosition <- function(pair=NULL, five.minute.price.xts=NULL){
  if(is.null(five.minute.price.xts)){
    five.minute.price.xts <- getPairData(pair)
  }
  hour.price.xts <- to.hourly(five.minute.price.xts, OHLC=FALSE, indexAt="endof")
  volatility.scalar=volatilityScalar(pair=pair, hour.price.xts=hour.price.xts)
  combined.instrument.forecast=combinedInstrumentForecast(pair=pair, five.minute.price.xts=five.minute.price.xts)
  system.forecast.average = 10 # by design this should be 10
  subsystem.position <- (volatility.scalar * combined.instrument.forecast)/system.forecast.average
  
  # subsystem.position <- subsystemPosition(ref.price=
  #                                         , total.equity=
  #                                         , volatility.target=
  #                                         , exchange.rate=
  #                                         , instrument.volatility=
  #                                         , combined.instrument.forecast=combined.instrument.forecast)
  return(subsystem.position)
}

subsystemPosition <- function(ref.price, total.equity
                              , volatility.target
                              , exchange.rate
                              , instrument.volatility
                              , combined.instrument.forecast){
  
  block.value <- ref.price * .01
  cash.volatility.target <- total.equity * volatility.target # * (1/exchange.rate)
  instrument.currency.volatility <- block.value * instrument.volatility * 100
  instrument.value.volatility <- instrument.currency.volatility * exchange.rate
  volatility.scalar <- cash.volatility.target/instrument.value.volatility
  system.forecast.average <- 10 # by design, but can make dynamic
  subsystem.position <- (volatility.scalar * combined.instrument.forecast)/system.forecast.average
  subsystem.position <- ifelse(is.na(subsystem.position), 0, subsystem.position)
  subsystem.position <- ifelse(subsystem.position * ref.price * exchange.rate > total.equity, total.equity/(ref.price * exchange.rate), subsystem.position)
  return(subsystem.position)
}

emaVolatility <- function(price.xts){
  ema.volatility <- EMA(sqrt(CalculateReturns(price.xts)^2), n=36*(60/5)) * sqrt(60/5)
  colnames(ema.volatility) <- NULL
  return(ema.volatility)
}

scaledForecast <- function(price.xts){
  scaled.forecast <- xts(x=rep(10, times=length(index(price.xts))), order.by = index(price.xts))
  colnames(scaled.forecast) <- NULL
  return(scaled.forecast)
}

xtsIdentity <- function(price.xts, exchange.rate){
  xts.identity <- exchange.rate[index(price.xts),]
  colnames(xts.identity) <- NULL
  return(xts.identity)
}

percentFee <- function(TxnQty, TxnPrice, Symbol, ...){
  return(-1*abs(0.0025 * TxnQty * TxnPrice)) # system.config$transaction.fee, need to add without throwing error
}

maxPosition <- function(pair=NULL, account.value){
  original.account.value <- system.config$poloniex.margin.value
  system.config$poloniex.margin.value <- account.value
  volatility.scalar <- volatilityScalar(pair=pair)
  instrument.weight <- as.numeric(tail(readRDS(paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS")),1)[,pair])
  instrument.diversification.multiplier <- instrumentDiversificationMultiplier()
  max.position <- 1 * volatility.scalar * instrument.weight * instrument.diversification.multiplier
  system.config$poloniex.margin.value <- original.account.value
  price <- getExchangeRate(pair=pair)
  btc.max.position <- max.position * price
  return(btc.max.position)
}

minAccountValue <- function(){
  optFunc <- function(pair, X){
    max.position <- maxPosition(pair=pair, account.value=X)
    return(abs(max.position - 4*system.config$minimum.order.size))
  }
  optimFunc <- function(pair){
    return(optimize(optFunc, pair=pair, interval=c(0,6), tol=0.1)$minimum)
  }
  min.account.values <- sapply(system.config$portfolio.pairs, optimFunc)
  min.account.value <- max(min.account.values)
  return(min.account.value)
}

rawInstrumentWeights <- function(subsystem.returns=na.omit(readRDS(paste0(getwd(),"/data/clean/subsystem_returns.RDS")))
                                                        , all_time=TRUE){
  volatility.target = system.config$volatility.target
  instruments = colnames(subsystem.returns)
  df.con = portfolio.spec(assets = instruments)
  df.con = add.constraint(portfolio = df.con, type = "long_only")
  df.con = add.constraint(portfolio = df.con, type="weight_sum",min_sum=0.99, max_sum=1.01)
  df.con = add.objective(portfolio = df.con, type="return", name="mean")
                         # , target=log(volatility.target+1))
  df.con <- add.objective(portfolio=df.con, type="risk", name="StdDev")
                          # , target=log(volatility.target+1))
  # window.end <- length(subsystem.returns)
  # window.start <- window.end - volatility.lookback
  # rp <- random_portfolios(df.con, 1000, "sample")
  
  daily.returns <- aggregate(x=subsystem.returns, by=date, FUN=sum)
  
  if(all_time){
    # registerDoParallel()
    opt.dn <- optimize.portfolio.rebalancing(R = daily.returns, portfolio = df.con
                                             , optimize_method = "random", trace=FALSE #, rp=rp
                                             , rebalance_on="days")
  }
  else {
    opt.dn <- optimize.portfolio(R = daily.returns, portfolio = df.con
                                             , optimize_method = "random", trace=FALSE #, rp=rp
                                             )
  }
  
  # raw.instrument.weights <- data.frame(t(sapply(c(1:nrow(subsystem.returns)), optimizeFunction, returns=subsystem.returns, df.con=df.con)))
  # as.xts(x=raw.instrument.weights, order.by=index(subsystem.returns))
  
  print(paste0("Instrument Weight Optimization time: ",opt.dn$elapsed_time))
  
  raw.instrument.weights <- extractWeights(opt.dn)
  saveRDS(raw.instrument.weights, paste0(getwd(),"/data/clean/raw_instrument_weights.RDS"))
  # return(raw.instrument.weights)
}

updateSmoothedWeights <- function(smoothed.instrument.weights, new.raw.weights, ema.n=36){
  # append to EMA of weights with new weights
  saveRDS(smoothed.instrument.weights, paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS"))
}

smoothedInstrumentWeights <- function(ema.n=36){
  raw.instrument.weights <- readRDS(paste0(getwd(),"/data/clean/raw_instrument_weights.RDS"))
  smoothed.instrument.weights <- na.omit(xts(x=apply(raw.instrument.weights, 2, EMA, n=ema.n)
                                     , order.by=index(raw.instrument.weights)))
  
  # chart.StackedBar(smoothed.instrument.weights, colorset=rainbow12equal)
  
  saveRDS(smoothed.instrument.weights, paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS"))
  return(smoothed.instrument.weights)
}

# generalize to diversificationMultipler function to help building forecastDiversificationMultiplier later
instrumentDiversificationMultiplier <- function(subsystem.returns=readRDS(paste0(getwd(),"/data/clean/subsystem_returns.RDS"))
                                                , instrument.weights=readRDS(paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS"))){
  # check that instrument weights sum to 1
  subsystem.returns <- na.omit(subsystem.returns)
  instrument.weights <- tail(instrument.weights, 1)
  instrument.weights <- array(instrument.weights/sum(instrument.weights))
  # print(sum(instrument.weights==1))
  correlation.matrix <- cor(subsystem.returns)
  # floor negative correlations to 0
  instrument.diversification.multiplier <- 1/sqrt(tcrossprod(crossprod(instrument.weights, correlation.matrix), instrument.weights))
  
  instrument.diversification.multiplier.max <- 2.5
  instrument.diversification.multiplier <- min(as.numeric(instrument.diversification.multiplier)
                                               ,instrument.diversification.multiplier.max)
  
  return(instrument.diversification.multiplier)
}
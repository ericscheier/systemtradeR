getPairData <- function(pair=NULL, ohlc=FALSE, volume=FALSE, live=FALSE){
  columns <- c("close")
  if(ohlc){columns <- c("open", "high", "low", columns)}
  if(volume){columns <- c(columns, "volume")}
  ohlc.prices <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE) # five minute frequency
  five.price.xts <- xts(x=ohlc.prices[,columns]
                        , order.by = as.POSIXct(ohlc.prices[,"date"], origin = "1970-01-01", format="%Y-%m-%d %H:%M:%S")
                        , tzone = "UTC")
  names(five.price.xts) <- columns
  if(live){
    current.close <- getExchangeRate(pair=pair)
    five.price.xts[nrow(five.price.xts),"close"] <- current.close
  }
  return(five.price.xts)
}

getHourlyPairData <- function(pair=NULL, ohlc=FALSE, volume=FALSE, live=FALSE){
  five.price.xts <- getPairData(pair, ohlc=ohlc, volume=volume)
  # columns <- colnames(five.price.xts)
  hour.price.xts <- to.hourly(five.price.xts, OHLC=FALSE, indexAt="endof")
  # names(hour.price.xts) <- columns
  return(hour.price.xts)
}

getPairSpecs <- function(pair=NULL){
  specs <- read.csv(relativePath("/data/raw/pair_specs.csv"))
}

getExchangeRate <- function(pair="USDT_BTC"){
  
  data.dir <- "data/clean/market/"
  market.files <- list.files(data.dir)
  file.to.load <- market.files[grep("orderbook_",market.files)]
  all.order.books <- readRDS(paste0(data.dir,file.to.load))
  
  high.bid <- as.numeric(all.order.books[[pair]][["bids"]][[1]][[1]])
  low.ask <- as.numeric(all.order.books[[pair]][["asks"]][[1]][[1]])
  
  middle <- mean(high.bid, low.ask)
  return(middle)
}

positionBuffer <- function(current.position, optimal.position=NULL, trade.to.edge=TRUE){
  upper.buffer <- current.position + abs(current.position * system.config$minimum.position.change/2)
  lower.buffer <- current.position - abs(current.position * system.config$minimum.position.change/2)
  
  buffered.position <- applyBuffer(current.position, optimal.position, upper.buffer, lower.buffer, trade.to.edge=TRUE)
  return(buffered.position)
}

forecastBuffer <- function(){
  # tbd, relies on forecast scalar func which doesn't exist right now
}

applyBuffer <- function(current.position, optimal.position=NULL, upper.buffer=NULL, lower.buffer=NULL, trade.to.edge=TRUE){
  if(any(sapply(list(optimal.position, upper.buffer, lower.buffer), FUN=is.null))){
    return(current.position)
  }
  
  if(lower.buffer > upper.buffer){
    temp.upper.buffer <- upper.buffer
    upper.buffer <- lower.buffer
    lower.buffer <- temp.upper.buffer
  }
  
  if(current.position > upper.buffer){
    if(trade_to_edge){
      buffered.position <- upper.buffer
    } else {
      buffered.position <- optimal.position
    }
  } else if (current.position < lower.buffer){
      if(trade_to_edge){
        buffered.position <- lower.buffer
      } else {
        buffered.positon <- optimal.position
      }
  } else {
    buffered.position <- current.position
  }
  
  return(buffered.position)
}



# 
# combinedInstrumentForecast <- function(pair=NULL, five.minute.price.xts=NULL){
#   # five.price.xts <- getPairData(pair)
#   # returns <- diff(log(ohlc.prices[,"weightedAverage"]))
#   combined.instrument.forecast <- 10
#   
#   # Apply range bounds on forecasts
#   forecast.max <- 20
#   forecast.min <- (-1)*forecast.max
#   combined.instrument.forecast <- max(min(combined.instrument.forecast,forecast.max),forecast.min)
#   return(combined.instrument.forecast)
# }

# need to add volatility calculations, volatility adjutment, and combining forecasts for staunch systems trader
# # calculateVolatility <- function(pair=NULL, hour.price.xts=NULL){
# #   if(is.null(hour.price.xts)){
# #     hour.price.xts <- getHourlyPairData(pair)
# #   }
# #   volatility.lookback <- system.config$volatility.lookback
# #   
# #   # we want hourly vol looking back x hours
# #   percentage.change <- na.omit(tail(CalculateReturns(hour.price.xts), volatility.lookback)^2)
# #   calculated.volatility <- sqrt(EMA(percentage.change, n=36))
# #   return(na.omit(calculated.volatility))
# # }
# 
# cashVolatilityTarget <- function(exchange.rate=getExchangeRate()){
#   account.value=system.config$poloniex.margin.value
#   # returns the cash volatility target in USDT
#   volatility.target <- system.config$volatility.target
#   cash.volatility.target <- account.value * volatility.target * exchange.rate
#   return(cash.volatility.target)
# }
# 
# instrumentValueVolatility <- function(exchange.rate=getExchangeRate(), pair=NULL, hour.price.xts=NULL){
#   if(is.null(hour.price.xts)){
#     block.size <- getExchangeRate(pair=pair)     # minimum.order.size <- system.config$minimum.order.size
#   }
#   else {
#     block.size <- as.numeric(tail(hour.price.xts,1))
#   }
#   volatility.lookback <- system.config$volatility.lookback
#   # hour.price.xts <- getHourlyPairData(pair)
#   block.value <- block.size * .01 # change in price when block moves 1%, BTC/XRP
#   price.volatility <- 100*as.numeric(tail(calculateVolatility(pair, hour.price.xts=hour.price.xts),1)) # ewma of 36 trading periods
#   instrument.currency.volatility <- block.value * price.volatility # expected hourly profit/loss in instrument units
#   ## ^^ can be simplified to block.size * price.volatility when there is one asset per block (i.e. equities, raw FX)
#   ## However, framework adapts to futures, etc.
#   ## We are calculating the impact a % price move in the asset has on our bottom line per [hour], then
#   ## How many % price moves we should expect per [hour]
#   instrument.value.volatility <- instrument.currency.volatility * exchange.rate # instrument.currency.volatility converted to account value currency
#   return(instrument.value.volatility)
# }
# volatilityScalar <- function(pair=NULL, hour.price.xts=NULL){
#   cash.volatility.target=cashVolatilityTarget()
#   instrument.value.volatility=instrumentValueVolatility(pair=pair, hour.price.xts = hour.price.xts)
#   volatility.scalar <- cash.volatility.target/instrument.value.volatility # unitless
#   return(volatility.scalar)
# }

productionInstrumentVolatility <- function(pair=NULL, hourly.price.xts=NULL){
  if(is.null(hourly.price.xts)){
    hourly.price.xts <- getHourlyPairData(pair, ohlc = TRUE, live=TRUE)
    hourly.price.xts <- xts(x=rowMeans(hourly.price.xts[,c("high","low","open","close")]),order.by = index(hourly.price.xts))
  }
  instrument.volatility <- as.numeric(tail(emaVolatility(hourly.price.xts),1))
  return(instrument.volatility)
}

productionSubsystemForecast <- function(pair=NULL, hourly.price.xts=NULL){
  if(is.null(hourly.price.xts)){
    hourly.price.xts <- getHourlyPairData(pair, live=TRUE)
  }
  subsystem.forecast <- as.numeric(tail(productionCombinedForecast(pair=pair, hourly.price.xts=hourly.price.xts),1))
  return(subsystem.forecast)
}

productionSubsystemPosition <- function(pair=NULL, instrument.forecast=NULL, 
                                        instrument.volatility=NULL, ref.price=NULL,
                                        hourly.price.xts=NULL){
  if(any(is.null(c(subsystem.forecast, instrument.volatility, ref.price)))){
    hourly.price.xts <- getHourlyPairData(pair, live=TRUE)
  }
  if(is.null(instrument.forecast)){
    instrument.forecast <- productionSubsystemForecast(pair=pair,
                                                       hourly.price.xts=hourly.price.xts)
  }
  if(is.null(instrument.volatility)){
    instrument.volatility <- productionInstrumentVolatility(pair=pair,
                                                       hourly.price.xts=hourly.price.xts)
  }
  # hour.price.xts <- to.hourly(hourly.price.xts, OHLC=FALSE, indexAt="endof")
  # volatility.scalar=volatilityScalar(pair=pair, hour.price.xts=hour.price.xts)
  # combined.instrument.forecast=combinedInstrumentForecast(pair=pair, hourly.price.xts=hourly.price.xts)
  # system.forecast.average = 10 # by design this should be 10
  # subsystem.position <- (volatility.scalar * combined.instrument.forecast)/system.forecast.average
  if(is.null(ref.price)){
    ref.price <- as.numeric(tail(hourly.price.xts,1))
  }
  
  
  subsystem.position <- subsystemPosition(ref.price=ref.price
                                          , total.equity=system.config$poloniex.margin.value * system.config$current.exchange.rate
                                          , volatility.target=system.config$volatility.target
                                          , exchange.rate=system.config$current.exchange.rate
                                          , instrument.volatility=instrument.volatility
                                          , instrument.forecast=instrument.forecast)
  return(subsystem.position)
}

subsystemPosition <- function(ref.price=NULL
                              , total.equity=(system.config$poloniex.margin.value)
                              , volatility.target=system.config$volatility.target
                              , exchange.rate=1
                              , instrument.volatility=NULL
                              , instrument.forecast=NULL
                              , instrument.symbol=NULL){
  
  if(is.null(exchange.rate)){
    getInstrument(instrument.symbol)$currency
  }
  
  ref.price <- max(0,as.numeric(ref.price))
  instrument.volatility <- as.numeric(instrument.volatility)
  instrument.forecast <- as.numeric(instrument.forecast)
  exchange.rate <- as.numeric(exchange.rate)
  volatility.target <- as.numeric(volatility.target)
  
  block.value <- ref.price * .01
  cash.volatility.target <- total.equity * volatility.target # * (1/exchange.rate)
  instrument.currency.volatility <- block.value * instrument.volatility * 100
  instrument.value.volatility <- instrument.currency.volatility / exchange.rate
  volatility.scalar <- cash.volatility.target/instrument.value.volatility
  system.forecast.average <- 10 # by design, but can make dynamic
  subsystem.position <- (volatility.scalar * instrument.forecast)/system.forecast.average
  subsystem.position <- ifelse(is.na(subsystem.position), 0, subsystem.position)
  # subsystem.position <- ifelse(subsystem.position * ref.price * exchange.rate > total.equity, total.equity/(ref.price * exchange.rate), subsystem.position)
  subsystem.position <- ifelse(is.na(subsystem.position), 0, subsystem.position)
  return(subsystem.position)
}
emaVolatility <- function(price.xts){
  # expects 5-min close of price data
  ema.volatility <- EMA(sqrt(CalculateReturns(price.xts)^2), n=36)
  colnames(ema.volatility) <- NULL
  return(ema.volatility)
}

weightedForecasts <- function(price.xts, instrument.name){
  price.index <- xts(order.by=index(price.xts))
  ###~~~!!!~~~###
  ## Not sure whether weights need to be lagged by a day. Need to evaluate in depth!
  fw <- readRDS(relativePath(paste0("/data/clean/",instrument.name,"_smoothed_forecast_weights.RDS")))
  ###~~~!!!~~~###
  forecast.weights <- na.locf(merge(price.index, fw), na.rm = FALSE)
  fdm <- forecastDiversificationMultipler(instrument.name)
  forecast.diversification.multiplier <- na.locf(merge(price.index, fdm), na.rm = FALSE)
  capped.scaled.forecasts <- xts(x=rbind(sapply(names(fw), cappedScaledForecast, price.xts=price.xts)), order.by = index(price.xts))
  
  weighted.forecasts <- forecast.weights * capped.scaled.forecasts[,colnames(forecast.weights)] * c(coredata(forecast.diversification.multiplier))
  return(weighted.forecasts)
}

productionWeightedForecasts <- function(pair, hourly.price.xts){
  # price.xts <- getHourlyPairData(pair)
  forecast.weights <- tail(readRDS(relativePath(paste0("/data/clean/",pairToSymbol(pair),"_smoothed_forecast_weights.RDS"))),1)
  ###~~~!!!~~~###
  # forecast.weights <- na.locf(merge(price.index, fw), na.rm = FALSE)
  forecast.diversification.multiplier <- productionForecastDiversificationMultipler(pairToSymbol(pair))
  capped.scaled.forecasts <- tail(sapply(names(forecast.weights), cappedScaledForecast, price.xts=hourly.price.xts),1)
  
  weighted.forecasts <- as.xts(forecast.weights * capped.scaled.forecasts[,colnames(forecast.weights)] * forecast.diversification.multiplier)
  return(weighted.forecasts)
}

productionCombinedForecast <- function(pair, hourly.price.xts){
  combined.forecast <- rowSumXts(productionWeightedForecasts(pair, hourly.price.xts))
  
  combined.forecast <- cappedForecast(combined.forecast)
  colnames(combined.forecast) <- NULL
  return(combined.forecast)
}

combinedForecast <- function(price.xts, instrument.name){
  combined.forecast <- rowSumXts(weightedForecasts(price.xts, instrument.name))
  # combined.forecast <- xts(x=rowSums(weighted.forecasts, na.rm=FALSE), order.by=index(price.xts))
  
  combined.forecast <- cappedForecast(combined.forecast)
  colnames(combined.forecast) <- NULL
  return(combined.forecast)
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
  start_t <- Sys.time()
  rebalance_on = "hours" #"days"
  training_period = 1#36
  
  returns <- readRDS(relativePath(return.path))
  returns <- na.trim(replaceLeadingZeros(returns.xts=na.fill(returns, 0)), sides="left", is.na="all")
  # returns.nice <- na.trim(returns, sides="left", is.na="all")
  # returns <- replaceLeadingZeros(returns.xts=returns)
  # returns <- na.trim(returns, sides="left", is.na="all")
  # returns <- returns[1:100,]
  all.instruments <- colnames(returns)
  
  ep.i <- endpoints(returns, on = rebalance_on)[which(endpoints(returns, 
                                                          on = rebalance_on) >= training_period)]
  # ep.i.index <- index(returns)
  
  # ep <- ep.i[training_period+1]
  raw.weights <- foreach::foreach(ep = iterators::iter(ep.i), .combine="rbind", .packages = "PortfolioAnalytics") %dopar% 
                               {
                                 time.step <- index(returns)[ep]
                                 R <- returns[1:ep,apply(!is.na(returns[(ep-training_period):ep,]),2,any)]
                                 R <- na.omit(R)
                                 
                                 instruments <- colnames(R)
                                 ignored.instruments <- all.instruments[!(all.instruments %in% instruments)]
                                 
                                 init.portf <- portfolio.spec(assets=instruments)
                                 # init.portf <- add.constraint(portfolio=init.portf, type="full_investment")
                                 init.portf <- add.constraint(portfolio=init.portf, type="weight_sum",
                                                              min_sum=0.99, max_sum=1.01)
                                 init.portf <- add.constraint(portfolio=init.portf, type="long_only")
                                 sharpe.portf <- add.objective(portfolio=init.portf, type="return", name="mean")
                                 sharpe.portf <- add.objective(portfolio=init.portf, type="risk", name="StdDev")
                                 starr.portf <- add.objective(portfolio=init.portf, type="risk", name="ES")
                                 starr.portf <- add.objective(portfolio=starr.portf, type="return", name="mean")
                                 # init.portf <- add.objective(portfolio=init.portf, type="quadratic_utility", name="mean")
                                 # init.portf <- add.objective(portfolio=init.portf, type="quadratic_utility", name="StdDev")
                                 
                                 opt.dn <- optimize.portfolio(R=R, portfolio=starr.portf, optimize_method="ROI", maxSTARR=TRUE)
                                 
                                 # opt.dn <- optimize.portfolio(R, portfolio=init.portf,
                                 #                              # optimize_method="DEoptim",
                                 #                              # search_size=2000,
                                 #                              optimize_method="ROI",
                                 #                              maxSR=TRUE,
                                 #                              # search_size = search_size, 
                                 #                              trace = TRUE#,
                                 #                              # rp = rp
                                 # )
                                 weights.list <- c(opt.dn$weights,
                                                   setNames(rep(0, length(ignored.instruments)), ignored.instruments))
                                 
                                 weights <- as.xts(data.frame(t(weights.list), row.names = time.step))
                                 gc()
                                 return(weights)
                               }
  
  
  
  # r.df <- data.frame(replicate(length(instruments),rnorm(nrow(returns), mean=0, sd=.01)))
  # names(r.df) <- instruments
  # 
  # rand.returns <- xts(x=r.df, order.by=index(returns))
  
  
  
  # daily.returns <- aggregate(x=returns, by=date, FUN=sum)
  
  # maxSR.lo.ROI <- optimize.portfolio(R=returns, portfolio=init.portf,
  #                                  optimize_method="ROI",
  #                                  maxSR=TRUE, trace=TRUE)
  
  # opt.dn <- optimize.portfolio.rebalancing(R=daily.returns, portfolio=init.portf,
  #                                          # training_period=3,
  #                                          optimize_method="ROI",
  #                                          maxSR=TRUE,
  #                                          # trace=TRUE,
  #                                          rebalance_on="days")
  
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
  end_t <- Sys.time()
  print(paste0("Weight Optimization time: ",end_t - start_t))
  
  # raw.weights <- na.omit(extractWeights(opt.dn))
  return(na.omit(raw.weights))
}

instrumentWeight <- function(instrument.name, price.xts){
  instrument.weights <- readRDS(relativePath("/data/clean/smoothed_instrument_weights.RDS"))
  
  instrument.weight <- instrument.weights[,instrument.name]
  return(xtsIdentity(price.xts = price.xts, to.merge = instrument.weight))
}

productionDiversificationMultiplier <- function(returns=NULL, weights=NULL, end.date=NULL){
  if(is.null(end.date)){
    end.date <- min(c(max(index(weights)),max(index(returns))))
  }

  date.subset <- paste0("::",end.date)
  returns <- returns[date.subset,]
  weights <- weights[date.subset,]
  
  # check that instrument weights sum to 1
  # returns <- na.omit(returns)
  weights <- tail(weights[,colnames(returns)], 1)
  weights <- array(weights/sum(weights))
  # print(sum(instrument.weights==1))
  correlation.matrix <- na.fill(cor(returns, use="pairwise.complete.obs"),1)
  correlation.matrix[correlation.matrix < 0] <- 0
  # floor negative correlations to 0
  
  diversification.multiplier <- 1/sqrt(tcrossprod(crossprod(weights, correlation.matrix), weights))
  
  diversification.multiplier.max <- 2.5
  diversification.multiplier <- min(as.numeric(diversification.multiplier)
                                    ,diversification.multiplier.max)
  
  return(diversification.multiplier)
}

xtsDiversificationMultiplier <- function(returns=NULL, weights=NULL){
  start.date <-  max(c(min(index(weights)),min(index(returns))))
  end.date <- min(c(max(index(weights)),max(index(returns))))
  # end.date <- start.date + days(20)
  date.subset <- paste0(start.date,"::",end.date)
  date.index <- index(weights[date.subset,])
  
  returns.na <- replaceLeadingZeros(returns)
  
  dm.s <- sapply(date.index, productionDiversificationMultiplier,returns=returns.na, weights=weights)
  
  xts.diversification.multiplier <- xts(x=dm.s, order.by=date.index)
  return(xts.diversification.multiplier)
}

instrumentDiversificationMultiplier <- function(price.xts){
  subsystem.returns <- readRDS(relativePath("/data/clean/instrument_returns.RDS"))
  instrument.weights <- readRDS(relativePath("/data/clean/smoothed_instrument_weights.RDS"))
  
  
  instrument.diversification.multiplier <- xtsDiversificationMultiplier(returns=subsystem.returns,
                                                                               weights=instrument.weights)
  
  return(xtsIdentity(price.xts = price.xts, to.merge = instrument.diversification.multiplier))
}

forecastDiversificationMultipler <- function(instrument.name){
  forecast.returns <- readRDS(relativePath(paste0("/data/clean/",instrument.name,"_forecast_returns.RDS")))
  forecast.weights <- readRDS(relativePath(paste0("/data/clean/",instrument.name,"_smoothed_forecast_weights.RDS")))
  
  
  forecast.diversification.multiplier <- xtsDiversificationMultiplier(returns=forecast.returns,
                                                                   weights=forecast.weights)
  
  return(forecast.diversification.multiplier)
}

productionForecastDiversificationMultipler <- function(instrument.name){
  forecast.returns <- readRDS(relativePath(paste0("/data/clean/",instrument.name,"_forecast_returns.RDS")))
  forecast.weights <- readRDS(relativePath(paste0("/data/clean/",instrument.name,"_smoothed_forecast_weights.RDS")))
  
  
  forecast.diversification.multiplier <- productionDiversificationMultiplier(returns=forecast.returns,
                                                                      weights=forecast.weights)
  
  return(forecast.diversification.multiplier)
}

# generalize to diversificationMultipler function to help building forecastDiversificationMultiplier later
productionInstrumentDiversificationMultiplier <- function(){
  subsystem.returns <- readRDS(relativePath("/data/clean/instrument_returns.RDS"))
  instrument.weights <- readRDS(relativePath("/data/clean/smoothed_instrument_weights.RDS"))
  
  
  instrument.diversification.multiplier <- productionDiversificationMultiplier(returns=subsystem.returns,
                                                                     weights=instrument.weights)
  
  return(instrument.diversification.multiplier)
}
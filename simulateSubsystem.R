simulateSubsystems <- function(lookback.hours=100*24){
  # registerDoParallel()
  start.time <- Sys.time()
  portfolio.pairs <- system.config$portfolio.pairs
  
  
  results.matrix <- xts(x=NA, order.by=floor_date(system.config$last.exchange.rate,unit="hour"))
  
  for(pair in portfolio.pairs){
    simulation.results <- simulateSubsystem(pair=pair, lookback.hours=lookback.hours)
    
    results.matrix <- merge.xts(results.matrix, simulation.results)
  }
  
  results.matrix$results.matrix <- NULL
  colnames(results.matrix) <- portfolio.pairs
  subsystem.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
  
  
  saveRDS(subsystem.returns, file=paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
  execution.time <- round(difftime(Sys.time(), start.time, units="hours"),2)
  print(paste0("Finished simulating subsystem returns in ",execution.time," hours."))
}

systematicRebalance <- function (...,
                                 ref.price.col=NULL,
                                 exchange.rate.col=NULL,
                                 instrument.volatility.col=NULL,
                                 combined.instrument.forecast.col=NULL,
                                 initEq=NULL,
                                 volatility.target=NULL,
                                 minimum.order.size=NULL,
                                 minimum.position.change=NULL,
                                 portfolio,
                                 symbol,
                                 timestamp)
{
  mktdata.row <- mktdata[timestamp,]
  ref.price <- mktdata.row[,ref.price.col]
  exchange.rate <- mktdata.row[,exchange.rate.col]
  instrument.volatility <- mktdata.row[,instrument.volatility.col]
  combined.instrument.forecast <- mktdata.row[,combined.instrument.forecast.col]
  # print(timestamp)
  dummy.port <- updatePortf(Portfolio=portfolio,
                            Dates=paste('::',timestamp,sep=''))
  trading.pl <- sum(.getPortfolio(portfolio)$summary$Net.Trading.PL)
  # updateAcct(account.name)
  # print(trading.pl)
  total.equity <- initEq + trading.pl * exchange.rate
  # print(paste(timestamp, total.equity, sep=": "))
  # print(paste(timestamp, trading.pl * exchange.rate, sep=": "))
  # tradeSize <- total.equity * trade.percent
  # if(length(refprice)>1) refprice <- refprice[,1]
  # if(!is.null(refprice)) tradeSize <- tradeSize/refprice
  # if(!is.null(digits)) tradeSize<-round(tradeSize,digits)
  
  subsystem.position <- subsystemPosition(ref.price, total.equity, volatility.target, exchange.rate, instrument.volatility, combined.instrument.forecast)
  
  # position.calcs <- data.frame(block.value=as.numeric(block.value),
  #                              instrument.volatility=as.numeric(instrument.volatility),
  #                              exchange.rate=as.numeric(exchange.rate),
  #                              cash.volatility.target=as.numeric(cash.volatility.target),
  #                              instrument.currency.volatility=as.numeric(instrument.currency.volatility),
  #                              instrument.value.volatility=as.numeric(instrument.value.volatility),
  #                              volatility.scalar=as.numeric(volatility.scalar),
  #                              combined.instrument.forecast=as.numeric(combined.instrument.forecast),
  #                              system.forecast.average=as.numeric(system.forecast.average),
  #                              subsystem.position=as.numeric(subsystem.position))
  # print(position.calcs)
  # print(paste(timestamp, subsystem.position * ref.price, sep=": "))
  
  current.position <- getPosQty(portfolio, symbol, timestamp)
  # print(paste(timestamp, current.position, sep=": "))
  
  transaction.size <- subsystem.position - current.position
  transaction.size <- transaction.size * (abs(ref.price * transaction.size) > minimum.order.size)
  transaction.size <- transaction.size * (abs(transaction.size/current.position) > minimum.position.change)
  transaction.size <- ifelse(is.na(transaction.size), 0, transaction.size)
  # print(paste0(timestamp,": wants ", round(subsystem.position,3),
  #              ", has ", round(current.position,3),
  #              ", transacting ", round(transaction.size,3)))
  
  if(transaction.size!=0){
    transaction.side <- ifelse(transaction.size>0,"long", "short")
    prefer.side <- ifelse(transaction.side=="long","high","low")
    
    addOrder(portfolio=portfolio, symbol=symbol, timestamp=timestamp,
             qty=transaction.size, price=ref.price, ordertype="market", side=transaction.side,
             threshold = NULL, orderset = "", status = "open",
             statustimestamp = "", prefer = prefer.side, delay = 60*5, tmult = FALSE,
             replace = TRUE, return = FALSE, ..., TxnFees = "percentFee",
             time.in.force = "GTC")
  }
}

simulateSubsystem <- function(pair=NULL, lookback.hours=100*24){
  if(!is.null(dev.list())){dev.off(which=dev.list())}
  .pardefault <- par(no.readonly = T)
  
  
  print(paste0("Simulating subsystem returns for ",pair))
  split.pair <- unlist(strsplit(pair, "_"))
  base <- split.pair[1]
  asset <- split.pair[2]
  
  e.rate <- paste0('USDT','_',base)
  # pair <- "BTC_ETH"
  
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
  add.indicator(strategy.name, name="scaledForecast", arguments = list(price.xts=quote(Cl(mktdata))), label='combined.instrument.forecast')
  add.indicator(strategy.name, name="xtsIdentity", arguments = list(price.xts=quote(Cl(mktdata))
                                                                    ,exchange.rate=quote(Cl(get(fx.rate, envir=.GlobalEnv)))), label="exchange.rate")
  
  assign("mktdata", applyIndicators(strategy.name, mktdata=get(trade.target, envir=.GlobalEnv)), envir=.GlobalEnv)
  # print(str(mktdata))
  
  
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
  
  chart.Posn(Portfolio=portfolio.name,Symbol=symbols, type = "line", log.scale = F)
  par(.pardefault)
  p <- getPortfolio(portfolio.name)
  a <- getAccount(account.name)
  xyplot(a$summary,type="h",col=4)
  par(.pardefault)
  equity <- a$summary$End.Eq
  plot(equity,main="Subsystem Equity Curve")
  par(.pardefault)
  ret <- na.omit(Return.calculate(equity))
  ret <- ret[is.finite(ret)]
  
  charts.PerformanceSummary(ret, colorset = bluefocus,
                            main=paste0(trade.target," Subsystem Performance"))
  par(.pardefault)
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




old_simulateSubsystem <- function(pair=NULL){
  print(paste0("Simulating subsystem returns for ",pair))
  account.cash <- system.config$poloniex.margin.value #btc
  position.size <- 0 #pair in BTC base
  base <- unlist(strsplit(pair, "_"))[1]
  
  
  ohlc.prices <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE) # five minute frequency
  
  five.price.xts <- xts(x=ohlc.prices[,"close"]
                        , order.by = strptime(ohlc.prices[,"date"], format="%Y-%m-%d %H:%M:%S")
                        , tzone = "UTC")
  hour.price.xts <- to.hourly(five.price.xts, OHLC=FALSE, indexAt="endof")
  
  first.hour <- index(head(hour.price.xts,1))
  first.hour <- ceiling_date(max(first.hour, system.config$first.exchange.rate), unit="hour")
  trading.start.hour <- first.hour + hours(system.config$volatility.lookback)
  last.hour <- index(tail(hour.price.xts,1))
  last.hour <- floor_date(min(last.hour, system.config$last.exchange.rate), unit="hour")
  
  simulation.range <- seq.POSIXt(from=trading.start.hour, to=last.hour, by="hour")
  simulation.results <- xts(data.frame(account.value=rep(NA, length(simulation.range))), order.by=simulation.range)
  
  for(simulation.hour in as.list(simulation.range)){
    exchange.rate <- as.numeric(system.config$five.exchange.rate[simulation.hour])
    truncated.hour.price.xts <- hour.price.xts[which(index(hour.price.xts) <= simulation.hour)]
    truncated.five.minute.price.xts <- five.price.xts[which(index(five.price.xts) <= simulation.hour)]
    current.price <- as.numeric(tail(truncated.hour.price.xts,1))
    account.value <- exchange.rate * (position.size * current.price + account.cash)
    simulation.results[simulation.hour] <- account.value
    # print(account.value)
    subsystem.position <- subsystemPosition(pair=pair, five.minute.price.xts=truncated.five.minute.price.xts)
    # combined.instrument.forecast <- combinedInstrumentForecast(ohlc.prices) # filter for simulation.hour
    # cash.volatility.target <- cashVolatilityTarget(account.value, system.config$volatility.target)
    # instrument.value.volatility <- instrumentValueVolatility(exchange.rate, truncated.hour.price.xts)
    # volatility.scalar <- volatilityScalar(cash.volatility.target, instrument.value.volatility)
    # subsystem.position <- subsystemPosition(volatility.scalar, combined.instrument.forecast)
    # subsystem.position <- max(min(account.value, subsystem.position),0)
    # print(paste0("Postion of ",subsystem.position," in ",pair))
    portfolio.difference <- subsystem.position - position.size
    transaction.size <- portfolio.difference * (abs(portfolio.difference/position.size) > system.config$minimum.position.change)
    # subsystem.position.blocks <- (subsystem.position/exchange.rate)
    # blocks.to.transact <- ifelse(abs((subsystem.position.blocks - position.size)/position.size)<(minimum.position.change),
    #                              0, subsystem.position.blocks - position.size)
    # blocks.to.transact <- ifelse(abs(blocks.to.transact) < minimum.order.size, 0, blocks.to.transact)
    
    execution.price <- as.numeric(five.price.xts[(simulation.hour + minutes(10))])
    if(abs(execution.price * transaction.size) < system.config$minimum.order.size){transaction.size <- 0}
    execution.exchange.rate <- as.numeric(system.config$five.exchange.rate[(simulation.hour + minutes(10))])
    blocks.transacted <- min(account.cash/execution.price, transaction.size)
    
    # if(blocks.transacted!=0){print(paste0("Transacted ",blocks.transacted," BTC worth of ",pair))}
    
    position.size <- position.size + transaction.size * execution.price
    total.transaction.fee <- transaction.size * execution.price * system.config$transaction.fee
    account.cash <- account.cash - transaction.size * execution.price - total.transaction.fee
    post.execution.account.value <- execution.exchange.rate * (position.size * execution.price + account.cash)
    
    # print(paste0("Account value for ",pair,": $",account.value," [$",post.execution.account.value," after trading]"))
  }
  
  return(simulation.results)
}


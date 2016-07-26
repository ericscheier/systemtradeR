source("libraries.R")
# library(doMC) # install.packages("doMC", repos="http://R-Forge.R-project.org")
# registerDoMC(cores=detectCores())
rm(list = ls())
if(!is.null(dev.list())){dev.off(which=dev.list())}
.pardefault <- par(no.readonly = T)
source("SystematicTrading.R")
Sys.setenv(TZ = "UTC")
config <- new.env(parent = emptyenv())
config$volatility.lookback <- 101 #hours
config$volatility.target <- .0005 # hourly target volatility in % terms 
# started at 0.0005
# bumped up 10x to reflect vol of market & underinvestment
config$minimum.order.size <- 0.0001 #BTC, true minimum is 0.0001 for order size
config$minimum.position.change <- .1 # % position should change before transacting
config$transaction.fee <- 0.0025 #% of each transaction
# registerDoParallel()

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
  return(-1*abs(0.0025 * TxnQty * TxnPrice)) # config$transaction.fee, need to add without throwing error
}

# poloniex.ohlc.30m <- content(GET("https://poloniex.com/public?command=returnChartData&currencyPair=BTC_ETH&start=1439010600&end=9999999999&period=1800"))  # https://poloniex.com/support/api/
base <- 'BTC'
asset <- 'ETH'
pair <- paste0(base,'_',asset)

e.rate <- paste0('USDT','_',base)
# pair <- "BTC_ETH"

volatility.target <- config$volatility.target
minimum.order.size <- config$minimum.order.size
minimum.position.change <- config$minimum.position.change
# poloniex.ohlc.5m <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE)
# ETHBTC.5m <- poloniex.ohlc.5m
# # ETHBTC.5m <- ldply(poloniex.ohlc.5m, data.frame)  # Convert OHLCV to data.frame
# ETHBTC.5m$date <- as.POSIXct(ETHBTC.5m$date,  tz="UTC")
# 
# # Create 'xts' object:
# ethbtc.30m.xts <- xts(ETHBTC.5m[, 2:8], order.by = ETHBTC.5m$date)  # is.OHLCV(ETHBTC.30m)



# Rebuild empty environments if RStudio's "Clear All" has been used:
if (!exists('.instrument')) .instrument <- new.env()
if (!exists('.blotter')) .blotter <- new.env()
if (!exists('.strategy')) .strategy <- new.env()

## Optional: Subset timeframe
trade.target <- paste0(asset,base)
fx.rate <- paste0("USD",base)
assign(trade.target, getPairData(pair=pair, ohlc=TRUE, volume=TRUE)["2016-06-04::"]) # getHourlyPairData
assign(fx.rate, getPairData(pair=e.rate, ohlc=FALSE, volume=FALSE)["2016-06-04::"]) #getHourlyPairData
# combo.prices <- na.omit(merge(BTC_ETH, BTCUSD))
# BTC_ETH <- BTC_ETH[index(combo.prices)]
# BTCUSD <- BTCUSD[index(combo.prices)]
# ETHBTC2 <- to.hourly(ethbtc.30m.xts[,c("open", "high", "low", "close", "volume")], indexAt="endof", OHLC=FALSE) # ["2015-09-01::"]

## Define instruments
currency(c(base, asset, 'USD')) # ls_currencies()
exchange_rate(trade.target, currency = base, counter_currency = asset, tick_size = 0.00001)
exchange_rate(fx.rate, currency = 'USD', counter_currency = base, tick_size = 0.01)

initDate = as.character(as.Date(min(index(get(trade.target)))-days(1))) # '2015-09-01'
initBTC <- .5
init.target <- 0
initUSD <- 300
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
                                                                  ,exchange.rate=quote(Cl(get(fx.rate)))), label="exchange.rate")

# applyIndicators(strategy.name, mktdata=ETHBTC)


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

subsystemPosition <- function (...,
                           ref.price.col=NULL,
                           exchange.rate.col=NULL,
                           instrument.volatility.col=NULL,
                           combined.instrument.forecast.col=NULL,
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
  # tradeSize <- total.equity * trade.percent
  # if(length(refprice)>1) refprice <- refprice[,1]
  # if(!is.null(refprice)) tradeSize <- tradeSize/refprice
  # if(!is.null(digits)) tradeSize<-round(tradeSize,digits)
  
  block.value <- ref.price # * .01
  cash.volatility.target <- total.equity * volatility.target # * (1/exchange.rate)
  instrument.currency.volatility <- block.value * instrument.volatility * 100
  instrument.value.volatility <- instrument.currency.volatility * exchange.rate
  volatility.scalar <- cash.volatility.target/instrument.value.volatility
  system.forecast.average <- 10 # by design, but can make dynamic
  subsystem.position <- (volatility.scalar * combined.instrument.forecast)/system.forecast.average
  subsystem.position <- ifelse(is.na(subsystem.position), 0, subsystem.position)
  subsystem.position <- ifelse(subsystem.position * ref.price * exchange.rate > total.equity, total.equity/(ref.price * exchange.rate), subsystem.position)

  position.calcs <- data.frame(block.value=as.numeric(block.value),
                               instrument.volatility=as.numeric(instrument.volatility),
                               exchange.rate=as.numeric(exchange.rate),
                               cash.volatility.target=as.numeric(cash.volatility.target),
                               instrument.currency.volatility=as.numeric(instrument.currency.volatility),
                               instrument.value.volatility=as.numeric(instrument.value.volatility),
                               volatility.scalar=as.numeric(volatility.scalar),
                               combined.instrument.forecast=as.numeric(combined.instrument.forecast),
                               system.forecast.average=as.numeric(system.forecast.average),
                               subsystem.position=as.numeric(subsystem.position))
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
}


## Rules
# add.rule(strategy.name, name="ruleSignal", arguments =
#            list(sigcol="Cl.gt.SMA", sigval=TRUE, orderqty='trigger',
#                 osFUN='osMaxPos', ordertype='market', orderside='long',
#                 pricemethod='market',TxnFees=0), type='enter', path.dep=TRUE)
# add.rule(strategy.name, name='ruleSignal', arguments =
#            list(sigcol="X1", sigval=TRUE, orderqty=,
#                 ordertype='market', orderside='long',
#                 pricemethod='market',TxnFees=0), type='exit', path.dep=TRUE)

add.rule(strategy.name, 'subsystemPosition',
                  arguments=list(rebalance_on='hours',
                                 ref.price.col="close",
                                 exchange.rate.col="X1.exchange.rate",
                                 instrument.volatility.col="X1.instrument.volatility",
                                 combined.instrument.forecast.col="X1.combined.instrument.forecast"
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
              parameters=list(),
              verbose=TRUE)

updatePortf(Portfolio=portfolio.name,Dates=paste('::',as.Date(Sys.time()),sep=''))
updateAcct(account.name)
updateEndEq(account.name)

## Evaluate
t(tradeStats(portfolio.name))
getTxns(portfolio.name, Symbol = trade.target)
perTradeStats(portfolio.name, trade.target)

chart.Posn(Portfolio=portfolio.name,Symbol=symbols, type = "line", log.scale = F)
par(.pardefault)
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

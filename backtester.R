library(httr)
library(plyr)
library(quantstrat) # install.packages("quantstrat", repos="http://R-Forge.R-project.org")
library(PerformanceAnalytics)
library(IKTrading)  # install_github("IlyaKipnis/IKTrading") needs devtools
library(lattice)
library(doParallel)
# library(doMC) # install.packages("doMC", repos="http://R-Forge.R-project.org")
# registerDoMC(cores=detectCores())
rm(list = ls())
source("SystematicTrading.R")
registerDoParallel()

emaVolatility <- function(price.xts){
  ema.volatility <- sqrt(EMA(CalculateReturns(price.xts)^2, n=36))
  colnames(ema.volatility) <- NULL
  return(ema.volatility)
}

scaledForecast <- function(price.xts){
  scaled.forecast <- xts(x=rep(10, times=length(index(price.xts))), order.by = index(price.xts))
  colnames(scaled.forecast) <- NULL
  return(scaled.forecast)
}

cashVolatilityTarget <- function(exchange.rate=getExchangeRate()){
  account.value=config$poloniex.margin.value
  # returns the cash volatility target in USDT
  volatility.target <- config$volatility.target
  cash.volatility.target <- account.value * volatility.target * exchange.rate
  return(cash.volatility.target)
}

instrumentValueVolatility <- function(exchange.rate=getExchangeRate(), pair=NULL, hour.price.xts=NULL){
  if(is.null(hour.price.xts)){
    block.size <- getExchangeRate(pair=pair)     # minimum.order.size <- config$minimum.order.size
  }
  else {
    block.size <- as.numeric(tail(hour.price.xts,1))
  }
  volatility.lookback <- config$volatility.lookback
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

subsystemPosition <- function(pair=NULL, five.minute.price.xts=NULL){
  if(is.null(five.minute.price.xts)){
    five.minute.price.xts <- getPairData(pair)
  }
  hour.price.xts <- to.hourly(five.minute.price.xts, OHLC=FALSE, indexAt="endof")
  volatility.scalar=volatilityScalar(pair=pair, hour.price.xts=hour.price.xts)
  combined.instrument.forecast=combinedInstrumentForecast(pair=pair, five.minute.price.xts=five.minute.price.xts)
  system.forecast.average = 10 # by design this should be 10
  subsystem.position <- (volatility.scalar * combined.instrument.forecast)/system.forecast.average
  return(subsystem.position)
}

# poloniex.ohlc.30m <- content(GET("https://poloniex.com/public?command=returnChartData&currencyPair=BTC_ETH&start=1439010600&end=9999999999&period=1800"))  # https://poloniex.com/support/api/
pair <- "BTC_ETH"
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
ETHBTC <- getHourlyPairData(pair=pair, ohlc=TRUE, volume=TRUE) # getHourlyPairData
BTCUSD <- getHourlyPairData(pair="USDT_BTC", ohlc=FALSE, volume=FALSE)
# combo.prices <- na.omit(merge(BTC_ETH, BTCUSD))
# BTC_ETH <- BTC_ETH[index(combo.prices)]
# BTCUSD <- BTCUSD[index(combo.prices)]
# ETHBTC2 <- to.hourly(ethbtc.30m.xts[,c("open", "high", "low", "close", "volume")], indexAt="endof", OHLC=FALSE) # ["2015-09-01::"]

## Define instruments
currency(c('BTC', 'ETH', 'USD')) # ls_currencies()
exchange_rate('ETHBTC', currency = 'BTC', counter_currency = 'ETH', tick_size = 0.00001)
exchange_rate('BTCUSD', currency = 'USD', counter_currency = 'BTC', tick_size = 0.01)

initDate = as.character(as.Date(min(index(ETHBTC))-days(1))) # '2015-09-01'
initBTC <- .5
initETH <- 0
initUSD <- 100
initEq <- initUSD

portfolio.name <- "bitcoin_margin"
account.name <- "poloniex"
strategy.name <- "asset_allocation"
symbols <- c("ETHBTC") #, "BTCUSD")

## To rerun
rm.strat(portfolio.name)
rm.strat(account.name)
rm.strat(strategy.name)

## Initialize Portfolio, Account, and Orderbook
initPortf(name = portfolio.name, symbols = symbols, initPosQty = 0, initDate = initDate, currency = "BTC")  # getPortfolio(portfolio.name)
initAcct(name = account.name, portfolios = portfolio.name, initDate = initDate, initEq = initEq, currency = "USD")  # getAccount(account.name)
initOrders(portfolio = portfolio.name, symbols = symbols, initDate = initDate)  # getOrderBook(portfolio.name)
strategy(strategy.name, store = TRUE)  # summary(getStrategy(strategy.name))

## Indicators
# # Parameters
# .nFast = 60 # 90
# .nSlow = 130
# .nSig = 45 # 75

# add.indicator(strategy.name, name = "MACD", arguments = list(x=quote(Cl(mktdata))), label='MACD')
add.indicator(strategy.name, name= "emaVolatility", arguments = list(price.xts=quote(Cl(mktdata))), label='volatility')
add.indicator(strategy.name, name="scaledForecast", arguments = list(price.xts=quote(Cl(mktdata))), label='forecast')

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

# Custom Rule
subsystemPosition <- function (trade.percent=.02,
                           ...,
                           longlevels=1, 
                           shortlevels=1, 
                           digits=NULL,
                           refprice=NULL,
                           portfolio,
                           symbol,
                           timestamp)
{
  print(timestamp)
  dummy <- updatePortf(Portfolio=portfolio,
                       Dates=paste('::',timestamp,sep=''))
  trading.pl <- sum(.getPortfolio(portfolio)$summary$Net.Trading.PL)
  total.equity <- initEq+trading.pl
  tradeSize <- total.equity * trade.percent
  if(length(refprice)>1) refprice <- refprice[,1]
  if(!is.null(refprice)) tradeSize <- tradeSize/refprice
  if(!is.null(digits)) tradeSize<-round(tradeSize,digits)
  addPosLimit(portfolio = portfolio, 
              symbol = symbol, 
              timestamp = timestamp, 
              maxpos = tradeSize, 
              longlevels = longlevels, 
              minpos = -tradeSize, 
              shortlevels = shortlevels)
}


## Rules
add.rule(strategy.name, 'subsystemPosition',
                  arguments=list(rebalance_on='hours',
                                 trade.percent=.02,
                                 refprice=quote(last(getPrice(mktdata)[paste('::',curIndex,sep='')])[,1]),
                                 digits=0
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
getTxns(portfolio.name, Symbol = 'BTC_ETH')
perTradeStats(portfolio.name, "BTC_ETH")

chart.Posn(Portfolio=portfolio.name,Symbol=symbols, type = "line", log.scale = F)

a <- getAccount(account.name)
xyplot(a$summary,type="h",col=4)

equity <- a$summary$End.Eq
plot(equity,main="Subsystem Equity Curve")
ret <- na.omit(Return.calculate(equity))
ret <- ret[is.finite(ret)]
charts.PerformanceSummary(ret, colorset = bluefocus,
                          main="Subsystem Performance")
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

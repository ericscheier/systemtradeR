library(httr)
library(plyr)
library(quantstrat) # install.packages("quantstrat", repos="http://R-Forge.R-project.org")
library(PerformanceAnalytics)
library(IKTrading)  # install_github("IlyaKipnis/IKTrading") needs devtools
library(doMC) # install.packages("doMC", repos="http://R-Forge.R-project.org")
registerDoMC(cores=detectCores())

# poloniex.ohlc.30m <- content(GET("https://poloniex.com/public?command=returnChartData&currencyPair=BTC_ETH&start=1439010600&end=9999999999&period=1800"))  # https://poloniex.com/support/api/
pair <- "BTC_ETH"
poloniex.ohlc.5m <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE)
ETHBTC.5m <- poloniex.ohlc.5m
# ETHBTC.5m <- ldply(poloniex.ohlc.5m, data.frame)  # Convert OHLCV to data.frame
ETHBTC.5m$date <- as.POSIXct(ETHBTC.5m$date, origin = "1970-01-01")

# Create 'xts' object:
ethbtc.30m.xts <- xts(ETHBTC.5m[, 2:8], order.by = ETHBTC.5m$date)  # is.OHLCV(ETHBTC.30m)

# Rebuild empty environments if RStudio's "Clear All" has been used:
if (!exists('.instrument')) .instrument <- new.env()
if (!exists('.blotter')) .blotter <- new.env()
if (!exists('.strategy')) .strategy <- new.env()

## Optional: Subset timeframe
ETHBTC <- to.hourly(ethbtc.30m.xts[,c("open", "high", "low", "close", "volume")]["2015-09-01::"], OHLC=FALSE)

## Define instruments
currency(c('BTC', 'ETH')) # , 'USDT' # ls_currencies()
# exchange_rate('BTCUSDT', currency = 'USDT', counter_currency = 'USDT', tick_size = 0.01)
exchange_rate('ETHBTC', currency = 'BTC', counter_currency = 'ETH', tick_size = 0.00001)

initDate = '2015-09-01'
initBTC <- .5
initETH <- 0

portfolio.name <- "crypto"
account.name <- "poloniex"
strategy.name <- "accumulator"
symbols <- "ETHBTC"

## To rerun
rm.strat(portfolio.name)
rm.strat(account.name)
rm.strat(strategy.name)

## Initialize Portfolio, Account, and Orderbook
initPortf(name = portfolio.name, symbols = symbols, initPosQty = 0, initDate = initDate, currency = "BTC")  # getPortfolio(portfolio.name)
initAcct(name = account.name, portfolios = portfolio.name, initDate = initDate, initEq = 0, currency = "BTC")  # getAccount(account.name)
initOrders(portfolio = portfolio.name, symbols = symbols, initDate = initDate)  # getOrderBook(portfolio.name)
strategy(strategy.name, store = TRUE)  # summary(getStrategy(strategy.name))

## Indicators
# Parameters
.nFast = 60 # 90
.nSlow = 130
.nSig = 45 # 75

add.indicator(strategy.name, name = "MACD", arguments = list(x=quote(Cl(mktdata))), label='MACD')

## Signals
# See Also: applySignals add.indicator link{add.rule} sigComparison sigCrossover sigFormula sigPeak sigThreshold
# MACD
add.signal(strategy.name, "sigCrossover",
           arguments = list(columns = c("macd.MACD", "signal.MACD"), relationship = "gt"),
           label = 'longEntry')
add.signal(strategy.name, "sigCrossover",
           arguments = list(columns = c("signal.MACD", "macd.MACD"), relationship = "gt"),
           label = 'signal.gt.macd')
add.signal(strategy.name, "sigThreshold",
           arguments = list(column = "macd.MACD", threshold = 0, relationship = "gte"),
           label = 'macd.gte.threshold')
add.signal(strategy.name, "sigAND",
           arguments=list(columns=c('signal.gt.macd', 'macd.gte.threshold'), cross=FALSE),
           label="longExit")

# Order sizing
osFixedDollar <- function(timestamp, orderqty, portfolio, symbol, ruletype, ...)
{
  ClosePrice <- as.numeric(Cl(mktdata[timestamp,]))
  orderqty <- round(tradeSize/ClosePrice,-2)
  return(orderqty)
}
tradeSize <- initBTC/2

## Rules
# Entry
add.rule(strategy.name,name='ruleSignal',
         arguments = list(sigcol="longEntry",
                          sigval=TRUE,
                          orderqty=100,
                          ordertype='market',
                          orderside='long',
                          osFUN='osFixedDollar'),
         type='enter',
         label='EnterLONG',
         storefun=FALSE)

# Exit
add.rule(strategy.name,name='ruleSignal',
         arguments = list(sigcol="longExit",
                          sigval=TRUE,
                          orderqty='all',
                          ordertype='market',
                          orderside='long',
                          osFUN='osFixedDollar'),
         type='exit',
         label='ExitLONG',
         storefun=FALSE)

## Run it
applyStrategy(strategy.name,
              portfolios=portfolio.name, debug=T,
              parameters=list(nFast = .nFast, nSlow = .nSlow, nSig = .nSig, maType = 'EMA'),
              verbose=TRUE)

updatePortf(Portfolio=portfolio.name,Dates=paste('::',as.Date(Sys.time()),sep=''))
updateAcct(account.name)
updateEndEq(account.name)

## Evaluate
t(tradeStats(portfolio.name))
getTxns(portfolio.name, Symbol = 'ETHBTC')
perTradeStats(portfolio.name, "ETHBTC")

chart.Posn(Portfolio=portfolio.name,Symbol=symbols, type = "line", log.scale = T)
plot(add_Vo())
plot(add_MACD(fast=.nFast, slow=.nSlow, signal=.nSig,maType="EMA"))  # nFast = 60, nSlow = 180, nSig = 40, maType = 'EMA'

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

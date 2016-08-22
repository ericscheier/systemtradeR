
## ----echo=FALSE----------------------------------------------------------
#########################################################################
# Copyright (C) 2011-2014 Guy Yollin                                    #
# License: http://www.gnu.org/licenses/gpl.html GPL version 2 or higher #
#########################################################################

## ----include=FALSE-------------------------------------------------------
library(knitr)
opts_chunk$set(tidy=FALSE,cache=FALSE,size='scriptsize',
  fig.path='figures/',fig.show='hide',fig.keep='last',
  fig.align='center',	fig.width=7,	fig.height=5,
  message=FALSE,warning=FALSE)

## ----echo=FALSE,cache=FALSE----------------------------------------------
options(width=81,continue=" ",digits=8)


## ------------------------------------------------------------------------
library(quantstrat)
search()


## ----echo=F,results='hide'-----------------------------------------------
suppressWarnings(try(rm(list=ls(FinancialInstrument:::.instrument),pos=FinancialInstrument:::.instrument),silent=TRUE))


## ------------------------------------------------------------------------
currency("USD")
stock("SPY",currency="USD",multiplier=1)
ls(envir=FinancialInstrument:::.instrument)
ls(all=T)


## ------------------------------------------------------------------------
# system settings
initDate <- '1997-12-31'
startDate <- '1998-01-01'
endDate <-  '2014-06-30'
initEq <- 1e6

## ------------------------------------------------------------------------
Sys.setenv(TZ="UTC")

## ----echo=FALSE,results='hide'-------------------------------------------
if(file.exists("SPY.RData"))
{
  load("SPY.RData")
} else {
  getSymbols('SPY', from=startDate, to=endDate, index.class="POSIXct", adjust=T)
  save(list="SPY",file="SPY.RData")
}

## ----eval=FALSE----------------------------------------------------------
## getSymbols('SPY', from=startDate, to=endDate, index.class="POSIXct", adjust=T)

## ------------------------------------------------------------------------
SPY=to.monthly(SPY, indexAt='endof', drop.time=FALSE)
SPY$SMA10m <- SMA(Cl(SPY), 10)


## ------------------------------------------------------------------------
# inz portfolio, account
qs.strategy <- "qsFaber"

## ------------------------------------------------------------------------
rm.strat(qs.strategy) # remove strategy etc. if this is a re-run

## ----results='hide'------------------------------------------------------
initPortf(qs.strategy,'SPY', initDate=initDate)

## ----results='hide'------------------------------------------------------
initAcct(qs.strategy,portfolios=qs.strategy, initDate=initDate, initEq=initEq)


## ------------------------------------------------------------------------
# initialize orders container
args(initOrders)
initOrders(portfolio=qs.strategy,initDate=initDate)

# instantiate a new strategy object
args(strategy)
strategy(qs.strategy,store=TRUE)


## ------------------------------------------------------------------------
ls(all=T)
ls(.blotter)
ls(.strategy)


## ------------------------------------------------------------------------
args(getStrategy)
strat <-getStrategy(qs.strategy)
class(strat)
summary(strat)


## ------------------------------------------------------------------------
args(add.indicator)


## ----results='hide'------------------------------------------------------
add.indicator(strategy = qs.strategy, name = "SMA",
  arguments = list(x = quote(Cl(mktdata)), n=10), label="SMA10")

## ------------------------------------------------------------------------
summary(getStrategy(qs.strategy))


## ------------------------------------------------------------------------
args(add.signal)


## ----results='hide'------------------------------------------------------
add.signal(qs.strategy,name="sigCrossover",
  arguments = list(columns=c("Close","SMA10"),relationship="gt"),
  label="Cl.gt.SMA")


## ----results='hide'------------------------------------------------------
add.signal(qs.strategy,name="sigCrossover",
  arguments = list(columns=c("Close","SMA10"),relationship="lt"),
  label="Cl.lt.SMA")


## ------------------------------------------------------------------------
summary(getStrategy(qs.strategy))


## ------------------------------------------------------------------------
args(add.rule)


## ------------------------------------------------------------------------
args(ruleSignal)


## ----results='hide'------------------------------------------------------
#   go long when close > MA
add.rule(qs.strategy, name='ruleSignal',
  arguments = list(sigcol="Cl.gt.SMA", sigval=TRUE, orderqty=900,
  ordertype='market', orderside='long'),
  type='enter')

## ----results='hide'------------------------------------------------------
#   exit when close < MA
add.rule(qs.strategy, name='ruleSignal',
  arguments = list(sigcol="Cl.lt.SMA", sigval=TRUE, orderqty='all',
  ordertype='market', orderside='long'),
  type='exit')


## ------------------------------------------------------------------------
summary(getStrategy(qs.strategy))


## ------------------------------------------------------------------------
args(applyStrategy)


## ----results='hide'------------------------------------------------------
applyStrategy(strategy=qs.strategy , portfolios=qs.strategy)

## ----echo=F--------------------------------------------------------------
options(width=120)

## ----size='tiny'---------------------------------------------------------
getTxns(Portfolio=qs.strategy, Symbol="SPY")

## ----echo=F--------------------------------------------------------------
options(width=81)


## ----echo=FALSE----------------------------------------------------------
options(width=120,digits=6)

## ----size='Tiny'---------------------------------------------------------
mktdata["2002"]

## ----echo=FALSE----------------------------------------------------------
options(width=81,digits=8)


## ----results='hide'------------------------------------------------------
updatePortf(qs.strategy)

## ----results='hide'------------------------------------------------------
updateAcct(qs.strategy)

## ----results='hide'------------------------------------------------------
updateEndEq(qs.strategy)


## ----size='Tiny'---------------------------------------------------------
checkBlotterUpdate <- function(port.st,account.st,verbose=TRUE)
{
  ok <- TRUE
  p <- getPortfolio(port.st)
  a <- getAccount(account.st)
  syms <- names(p$symbols)
  port.tot <- sum(sapply(syms,FUN = function(x) eval(parse(
    text=paste("sum(p$symbols",x,"posPL.USD$Net.Trading.PL)",sep="$")))))
  port.sum.tot <- sum(p$summary$Net.Trading.PL)
  if( !isTRUE(all.equal(port.tot,port.sum.tot)) ) {
    ok <- FALSE
    if( verbose )
      print("portfolio P&L doesn't match sum of symbols P&L")
  }
  initEq <- as.numeric(first(a$summary$End.Eq))
  endEq <- as.numeric(last(a$summary$End.Eq))
  if( !isTRUE(all.equal(port.tot,endEq-initEq)) ) {
    ok <- FALSE
    if( verbose )
      print("portfolio P&L doesn't match account P&L")
  }
  if( sum(duplicated(index(p$summary))) ) {
    ok <- FALSE
    if( verbose )
      print("duplicate timestamps in portfolio summary")
  }
  if( sum(duplicated(index(a$summary))) ) {
    ok <- FALSE
    if( verbose )
      print("duplicate timestamps in account summary")
  }
  return(ok)
}
checkBlotterUpdate(qs.strategy,qs.strategy)


## ------------------------------------------------------------------------
# create custom theme
myTheme<-chart_theme()
myTheme$col$dn.col<-'lightblue'
myTheme$col$dn.border <- 'lightgray'
myTheme$col$up.border <- 'lightgray'

## ----PERFQS,cache=FALSE--------------------------------------------------
# plot performance
chart.Posn(qs.strategy, Symbol = 'SPY', Dates = '1998::',theme=myTheme,
  TA='add_SMA(n=10,col=4, on=1, lwd=2)')


## ------------------------------------------------------------------------
tstats <- t(tradeStats(qs.strategy))

## ----TSTATS1,echo=FALSE,cache=FALSE--------------------------------------
textplot(tstats[1:15,,drop=FALSE],show.colnames=FALSE,halign='left')

## ----TSTATS2,echo=FALSE,cache=FALSE--------------------------------------
textplot(tstats[16:30,,drop=FALSE],show.colnames=FALSE,halign='left')


## ------------------------------------------------------------------------
ob <- getOrderBook(qs.strategy)
class(ob)
names(ob)
names(ob$qsFaber)
names(ob$qsFaber$SPY)


## ----echo=FALSE----------------------------------------------------------
options(width=110)

## ----size='tiny'---------------------------------------------------------
ob$qsFaber$SPY[,1:5]

## ----echo=FALSE----------------------------------------------------------
options(width=81)


## ----echo=FALSE----------------------------------------------------------
options(width=110)

## ----size='tiny'---------------------------------------------------------
ob$qsFaber$SPY[,6:11]

## ----echo=FALSE----------------------------------------------------------
options(width=81)


## ----echo=FALSE----------------------------------------------------------
options(width=100)

## ----size='tiny'---------------------------------------------------------
perTradeStats(qs.strategy)

## ----echo=FALSE----------------------------------------------------------
options(width=81)


## ----FABERMAE,cache=FALSE------------------------------------------------
chart.ME(Portfolio=qs.strategy, Symbol='SPY', type='MAE', scale='percent')

## ----FABERMFE,cache=FALSE------------------------------------------------
chart.ME(Portfolio=qs.strategy, Symbol='SPY', type='MFE', scale='percent')


## ----echo=FALSE----------------------------------------------------------
options(width=105)

## ----ACCTSUM,cache=FALSE,size='tiny'-------------------------------------
a <- getAccount(qs.strategy)
last(a$summary,5)
library(lattice)
xyplot(a$summary,type="h",col=4)

## ----echo=FALSE----------------------------------------------------------
options(width=81)


## ------------------------------------------------------------------------
equity <- a$summary$End.Eq

## ----EQCURVE,cache=FALSE-------------------------------------------------
plot(equity,main="Faber Strategy Equity Curve")

## ------------------------------------------------------------------------
ret <- Return.calculate(equity,method="log")

## ----PERFSUM,cache=FALSE-------------------------------------------------
charts.PerformanceSummary(ret, colorset = bluefocus,
  main="Faber Strategy Performance")


## ------------------------------------------------------------------------
symbols = c("XLF", "XLP", "XLE", "XLY", "XLV", "XLI", "XLB", "XLK", "XLU")

## ----echo=FALSE,results='hide'-------------------------------------------
if(file.exists("XLX.RData"))
{
  load("XLX.RData")
} else {
  getSymbols(symbols, src='yahoo', index.class=c("POSIXt","POSIXct"), from=startDate, to=endDate, adjust=T)
  save(list=symbols,file="XLX.RData")
}

## ----eval=FALSE----------------------------------------------------------
## getSymbols(symbols, src='yahoo', index.class=c("POSIXt","POSIXct"),
##   from=startDate, to=endDate, adjust=T)

## ------------------------------------------------------------------------
for(symbol in symbols)
{
    stock(symbol, currency="USD",multiplier=1)
    x<-get(symbol)
    x<-to.monthly(x,indexAt='endof',drop.time=FALSE)
    indexFormat(x)<-'%Y-%m-%d'
    colnames(x)<-gsub("x",symbol,colnames(x))
    assign(symbol,x)
}


## ----results='hide'------------------------------------------------------
multi.asset <- "multiAsset"
rm.strat(multi.asset) # remove strategy etc. if this is a re-run

## ----results='hide'------------------------------------------------------
initPortf(multi.asset,symbols=symbols, initDate=initDate)
initAcct(multi.asset,portfolios=multi.asset, initDate=initDate,
  initEq=initEq)
initOrders(portfolio=multi.asset,initDate=initDate)


## ----results='hide'------------------------------------------------------
applyStrategy(strategy=qs.strategy , portfolios=multi.asset)
updatePortf(multi.asset)
updateAcct(multi.asset)
updateEndEq(multi.asset)

## ------------------------------------------------------------------------
checkBlotterUpdate(multi.asset,multi.asset)


## ------------------------------------------------------------------------
a <- getAccount(multi.asset)
p <- getPortfolio(multi.asset)
names(p$symbols)


## ----XLX3x3,cache=FALSE,dev.args=list(pointsize=10),fig.width=12, fig.height=9----
par(mfrow=c(3,3))
for(symbol in symbols)
{
  chart.Posn(Portfolio=multi.asset,Symbol=symbol,theme=myTheme,
    TA="add_SMA(n=10,col='blue')")
}
par(mfrow=c(1,1))


## ----MULTITRADESTATS,echo=FALSE,cache=FALSE------------------------------
textplot(t(tradeStats(multi.asset)))


## ----echo=FALSE----------------------------------------------------------
options(width=78)

## ----IASSRET,cache=FALSE-------------------------------------------------
rets.multi <- PortfReturns(multi.asset)
colnames(rets.multi) <- symbols
rets.multi <- na.omit(cbind(rets.multi,Return.calculate(a$summary$End.Eq)))
names(rets.multi)[length(names(rets.multi))] <- "TOTAL"
rets.multi <- rets.multi[,c("TOTAL",symbols)]
round(tail(rets.multi,5),6)
chart.CumReturns(rets.multi, colorset= rich10equal, legend.loc = "topleft",
  main="SPDR Cumulative Returns")

## ----echo=FALSE----------------------------------------------------------
options(width=81)


## ----SPDRBOX,cache=FALSE-------------------------------------------------
chart.Boxplot(rets.multi, main = "SPDR Returns", colorset= rich10equal)


## ----MULTIRETRISK,cache=FALSE--------------------------------------------
(ar.tab <- table.AnnualizedReturns(rets.multi))
max.risk <- max(ar.tab["Annualized Std Dev",])
max.return <- max(ar.tab["Annualized Return",])

chart.RiskReturnScatter(rets.multi,
  main = "SPDR Performance", colorset = rich10equal,
  xlim=c(0,max.risk*1.1),ylim=c(0,max.return))


## ------------------------------------------------------------------------
equity <- a$summary$End.Eq

## ----MULTIEQCURVE,cache=FALSE--------------------------------------------
plot(equity,main="Consolidated SPDR Equity Curve")



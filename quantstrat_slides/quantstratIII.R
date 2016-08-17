
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
options(width=79,continue=" ",digits=8)


## ----results='hide'------------------------------------------------------
library(quantstrat)
startDate <- '2010-01-01'  # start of data
endDate <-  '2013-07-31'   # end of data
symbols = c("ITOT", "AGG", "GLD", "VNQ")
Sys.setenv(TZ="UTC")       # set time zone

## ----results='hide'------------------------------------------------------
getSymbols(symbols, src='yahoo', index.class=c("POSIXt","POSIXct"),
  from=startDate, to=endDate,adjust=TRUE)

## ----results='hide'------------------------------------------------------
initDate <- '2009-12-31'
initEq <- 1e6
currency("USD")
stock(symbols, currency="USD",multiplier=1)


## ------------------------------------------------------------------------
myTheme<-chart_theme()
myTheme$col$dn.col<-'lightblue'
myTheme$col$dn.border <- 'lightgray'
myTheme$col$up.border <- 'lightgray'

## ----XLX3x3,cache=FALSE--------------------------------------------------
par(mfrow=c(2,2))
for(symbol in symbols)
{
  plot(chart_Series(get(symbol),name=symbol))
}
par(mfrow=c(1,1))


## ------------------------------------------------------------------------
osFixedDollar <- function(timestamp,orderqty, portfolio, symbol, ruletype, ...)
{
  ClosePrice <- as.numeric(Cl(mktdata[timestamp,]))
  orderqty <- round(tradeSize/ClosePrice,-2)
  return(orderqty)
}


## ----results='hide'------------------------------------------------------
strategy("macd", store=TRUE)

## ----results='hide'------------------------------------------------------
add.indicator("macd", name = "MACD",
  arguments = list(x=quote(Cl(mktdata))),label='osc')

## ----results='hide'------------------------------------------------------
add.signal("macd",name="sigThreshold",
  arguments=list(column="signal.osc",relationship="gt",threshold=0,cross=TRUE),
  label="signal.gt.zero")

## ----results='hide'------------------------------------------------------
add.signal("macd",name="sigThreshold",
  arguments=list(column="signal.osc",relationship="lt",threshold=0,cross=TRUE),
  label="signal.lt.zero")


## ----results='hide'------------------------------------------------------
add.rule("macd",name='ruleSignal',
  arguments = list(sigcol="signal.gt.zero", sigval=TRUE,
    replace=FALSE,
    orderside='long',
    ordertype='market',
    orderqty=100,
    osFUN='osFixedDollar',
    orderset='ocolong'
  ),
  type='enter',
  label='LE'
)


## ----results='hide'------------------------------------------------------
add.rule("macd",name='ruleSignal',
  arguments = list(sigcol="signal.lt.zero", sigval=TRUE,
    replace=TRUE,
    orderside='long',
    ordertype='market',
    orderqty='all',
    orderset='ocolong'
  ),
  type='exit',
  label='LX'
)


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


## ----results='hide'------------------------------------------------------
rm.strat("multi.macd.nostop") # remove portfolio, account, orderbook if re-run
initPortf(name="multi.macd.nostop", symbols, initDate=initDate)
initAcct(name="multi.macd.nostop", portfolios="multi.macd.nostop",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.macd.nostop", initDate=initDate)

fastMA = 12
slowMA = 26
signalMA = 9
maType="EMA"
tradeSize <- initEq/10

out<-applyStrategy("macd" , portfolios="multi.macd.nostop",
  parameters=list(nFast=fastMA, nSlow=slowMA, nSig=signalMA,maType=maType),
  verbose=TRUE)

updatePortf("multi.macd.nostop")
updateAcct("multi.macd.nostop")
updateEndEq("multi.macd.nostop")


## ------------------------------------------------------------------------
checkBlotterUpdate("multi.macd.nostop","multi.macd.nostop")


## ----PERFNOSTOP,cache=FALSE----------------------------------------------
equity.curve <- getAccount("multi.macd.nostop")$summary$End.Eq
returns.ns <- Return.calculate(equity.curve,"log")
table.AnnualizedReturns(returns.ns)
charts.PerformanceSummary(returns.ns,wealth.index=TRUE,colorset="blue",
  xlab="",main="MACD Performance (no stoploss)",minor.ticks=FALSE)

## ----TRADESTATSNOSTOP,results='hide',fig.width=9,fig.height=9------------
PerformanceAnalytics:::textplot(t(tradeStats("multi.macd.nostop")))

## ----MAEVNQNOSTOP,results='hide',fig.width=7,fig.height=7----------------
chart.ME("multi.macd.nostop",'VNQ',type='MAE',scale='percent')

## ----ORDERBOOKVNQNOSTOP,results='hide',fig.width=9,fig.height=7----------
ob <- getOrderBook("multi.macd.nostop")$multi.macd.nostop$VNQ
ob.df <- data.frame(Date=time(ob),coredata(ob),stringsAsFactors=FALSE)
ob.df$Order.Price <- round(as.numeric(ob.df$Order.Price),3)
PerformanceAnalytics:::textplot(ob.df,show.rownames=F)


## ------------------------------------------------------------------------
args(add.rule)


## ------------------------------------------------------------------------
args(ruleSignal)


## ------------------------------------------------------------------------
stopLossPercent <- 0.05

## ----results='hide'------------------------------------------------------
add.rule("macd",name='ruleSignal',
  arguments = list(sigcol="signal.gt.zero", sigval=TRUE,
    replace=FALSE,
    orderside='long',
    ordertype='stoplimit',
    tmult=TRUE,
    threshold=quote( stopLossPercent ),
    orderqty='all',
    orderset='ocolong'
  ),
  type='chain', parent="LE",
  label='StopLossLong',
  enabled=FALSE
)


## ----results='hide'------------------------------------------------------
rm.strat("multi.macd.stop") # remove portfolio, account, orderbook if re-run

## ----results='hide'------------------------------------------------------
initPortf(name="multi.macd.stop", symbols, initDate=initDate)
initAcct(name="multi.macd.stop", portfolios="multi.macd.stop",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.macd.stop", initDate=initDate)

## ----results='hide'------------------------------------------------------
enable.rule("macd",type="chain",labe="StopLoss")

## ----results='hide'------------------------------------------------------
out<-applyStrategy("macd" , portfolios="multi.macd.stop",
  parameters=list(nFast=fastMA, nSlow=slowMA, nSig=signalMA,maType=maType),
  verbose=TRUE)

## ----results='hide'------------------------------------------------------
updatePortf("multi.macd.stop")
updateAcct("multi.macd.stop")
updateEndEq("multi.macd.stop")

## ------------------------------------------------------------------------
checkBlotterUpdate("multi.macd.stop","multi.macd.stop")


## ----PERFSTOP------------------------------------------------------------
equity.curve <- getAccount("multi.macd.stop")$summary$End.Eq
returns.sl <- Return.calculate(equity.curve,"log")
table.AnnualizedReturns(returns.sl)
charts.PerformanceSummary(returns.sl,wealth.index=TRUE,colorset="blue",
  xlab="",main="MACD Performance (with stoploss)",minor.ticks=FALSE)

## ----TRADESTATSSTOP,results='hide',fig.width=9,fig.height=9--------------
PerformanceAnalytics:::textplot(t(tradeStats("multi.macd.stop")))

## ----MAEVNQSTOP,results='hide',fig.width=7,fig.height=7------------------
chart.ME("multi.macd.stop",'VNQ',type='MAE',scale='percent')

## ----ORDERBOOKVNQSTOP,results='hide',fig.width=9,fig.height=7------------
ob <- getOrderBook("multi.macd.stop")$multi.macd.stop$VNQ
ob.df <- data.frame(Date=time(ob),coredata(ob),stringsAsFactors=FALSE)
ob.df$Order.Price <- round(as.numeric(ob.df$Order.Price),3)
PerformanceAnalytics:::textplot(ob.df,show.rownames=F)


## ------------------------------------------------------------------------
trailingStopPercent <- 0.07

## ----results='hide'------------------------------------------------------
add.rule("macd", name = 'ruleSignal',
  arguments=list(sigcol="signal.gt.zero" , sigval=TRUE,
    replace=FALSE,
    orderside='long',
    ordertype='stoptrailing',
    tmult=TRUE,
    threshold=quote(trailingStopPercent),
    orderqty='all',
    orderset='ocolong'
  ),
  type='chain', parent="LE",
  label='StopTrailingLong',
  enabled=FALSE
)


## ----results='hide'------------------------------------------------------
rm.strat("multi.macd.trail") # remove portfolio, account, orderbook if re-run

## ----results='hide'------------------------------------------------------
initPortf(name="multi.macd.trail", symbols, initDate=initDate)
initAcct(name="multi.macd.trail", portfolios="multi.macd.trail",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.macd.trail", initDate=initDate)

## ----results='hide'------------------------------------------------------
enable.rule("macd",type="chain",labe="StopTrailingLong")

## ----results='hide'------------------------------------------------------
out<-applyStrategy("macd" , portfolios="multi.macd.trail",
  parameters=list(nFast=fastMA, nSlow=slowMA, nSig=signalMA,maType=maType),
  verbose=TRUE)

## ----results='hide'------------------------------------------------------
updatePortf("multi.macd.trail")
updateAcct("multi.macd.trail")
updateEndEq("multi.macd.trail")

## ------------------------------------------------------------------------
checkBlotterUpdate("multi.macd.trail","multi.macd.trail")


## ----PERFTRAIL-----------------------------------------------------------
equity.curve <- getAccount("multi.macd.trail")$summary$End.Eq
returns.tr <- Return.calculate(equity.curve,"log")
table.AnnualizedReturns(returns.tr)
charts.PerformanceSummary(returns.tr,wealth.index=TRUE,colorset="blue",
  xlab="",main="MACD Performance (with stoploss)",minor.ticks=FALSE)

## ----TRADESTATSTRAIL,results='hide',fig.width=9,fig.height=9-------------
PerformanceAnalytics:::textplot(t(tradeStats("multi.macd.trail")))

## ----MAEVNQTRAIL,results='hide',fig.width=7,fig.height=7-----------------
chart.ME("multi.macd.trail",'VNQ',type='MAE',scale='percent')

## ----ORDERBOOKVNQTRAIL,results='hide',fig.width=9,fig.height=7-----------
ob <- getOrderBook("multi.macd.trail")$multi.macd.trail$VNQ
ob <- ob[ob$Order.Status=="closed",]
ob.df <- data.frame(Date=time(ob),coredata(ob),stringsAsFactors=FALSE)
ob.df$Order.Price <- round(as.numeric(ob.df$Order.Price),3)
PerformanceAnalytics:::textplot(ob.df,show.rownames=F)


## ------------------------------------------------------------------------
stopLossPercentRange <- seq(0.03,0.05,by=0.01)

## ----results='hide'------------------------------------------------------
add.distribution("macd",
  paramset.label = "STOPOPT",
  component.type = "chain",
  component.label = "StopLossLong",
  variable = list( threshold = stopLossPercentRange ),
  label = "StopLossLONG"
)


## ------------------------------------------------------------------------
trailingPercentRange <- seq(0.03,0.05,by=0.01)

## ----results='hide'------------------------------------------------------
add.distribution("macd",
  paramset.label = "STOPOPT",
  component.type = "chain",
  component.label = "StopTrailingLong",
  variable = list( threshold = trailingPercentRange ),
  label = "TrailingLONG"
)


## ------------------------------------------------------------------------
args(apply.paramset)


## ----results='hide'------------------------------------------------------
rm.strat("multi.macd.opt") # remove portfolio, account, orderbook if re-run

## ----results='hide'------------------------------------------------------
initPortf(name="multi.macd.opt", symbols, initDate=initDate)
initAcct(name="multi.macd.opt", portfolios="multi.macd.opt",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.macd.opt", initDate=initDate)

## ------------------------------------------------------------------------
library(parallel)
detectCores()

## ----results='hide'------------------------------------------------------
if( Sys.info()['sysname'] == "Windows" )
{
  library(doParallel)
#  registerDoParallel(cores=detectCores())
} else {
  library(doMC)
  registerDoMC(cores=detectCores())
}


## ----results='hide'------------------------------------------------------
if( file.exists("resultsStopOpt.RData") )
{
  load("resultsStopOpt.RData")
} else {
  results <- apply.paramset("macd", paramset.label = "STOPOPT",
    portfolio="multi.macd.opt", account="multi.macd.opt", nsamples=0)
  save(list="results",file="resultsStopOpt.RData")
}

## ------------------------------------------------------------------------
head(names(results),20)


## ----PROFITMDDHEAT,fig.width=7,fig.height=7,dev='png',dpi=300------------
z <- tapply(X=results$tradeStats$Profit.To.Max.Draw,
  INDEX=list(results$tradeStats$TrailingLONG,results$tradeStats$StopLossLONG),
  FUN=median)
x <- as.numeric(rownames(z))
y <- as.numeric(colnames(z))
filled.contour(x=x,y=y,z=z,color = heat.colors,
  xlab="Trailing Stop",ylab="Stop Loss")
title("Return to MaxDrawdown")


## ----results='hide'------------------------------------------------------
strategy("macd.opt", store=TRUE)

## ----results='hide'------------------------------------------------------
add.indicator("macd.opt", name = "MACD",
  arguments = list(x=quote(Cl(mktdata))),label='osc')

## ----results='hide'------------------------------------------------------
add.signal("macd.opt",name="sigThreshold",
  arguments=list(column="signal.osc",relationship="gt",threshold=0,cross=TRUE),
  label="signal.gt.zero")

## ----results='hide'------------------------------------------------------
add.signal("macd.opt",name="sigThreshold",
  arguments=list(column="signal.osc",relationship="lt",threshold=0,cross=TRUE),
  label="signal.lt.zero")


## ----results='hide'------------------------------------------------------
add.rule("macd.opt",name='ruleSignal',
  arguments = list(sigcol="signal.gt.zero", sigval=TRUE,
    replace=FALSE,
    orderside='long',
    ordertype='market',
    orderqty=100,
    osFUN='osFixedDollar',
    orderset='ocolong'
  ),
  type='enter',
  label='LE'
)

add.rule("macd.opt",name='ruleSignal',
  arguments = list(sigcol="signal.lt.zero", sigval=TRUE,
    replace=TRUE,
    orderside='long',
    ordertype='market',
    orderqty='all',
    orderset='ocolong'
  ),
  type='exit',
  label='LX'
)


## ------------------------------------------------------------------------
stopLossPercent <- 0.03

## ----results='hide'------------------------------------------------------
add.rule("macd.opt",name='ruleSignal',
  arguments = list(sigcol="signal.gt.zero", sigval=TRUE,
    replace=FALSE,
    orderside='long',
    ordertype='stoplimit',
    tmult=TRUE,
    threshold=quote( stopLossPercent ),
    orderqty='all',
    orderset='ocolong'
  ),
  type='chain', parent="LE",
  label='StopLossLong',
  enabled=TRUE
)


## ------------------------------------------------------------------------
trailingStopPercent <- 0.03

## ----results='hide'------------------------------------------------------
add.rule("macd.opt", name = 'ruleSignal',
  arguments=list(sigcol="signal.gt.zero" , sigval=TRUE,
    replace=FALSE,
    orderside='long',
    ordertype='stoptrailing',
    tmult=TRUE,
    threshold=quote(trailingStopPercent),
    orderqty='all',
    orderset='ocolong'
  ),
  type='chain', parent="LE",
  label='StopTrailingLong',
  enabled=TRUE
)


## ----results='hide'------------------------------------------------------
rm.strat("multi.macd.opt") # remove portfolio, account, orderbook if re-run

## ----results='hide'------------------------------------------------------
initPortf(name="multi.macd.opt", symbols, initDate=initDate)
initAcct(name="multi.macd.opt", portfolios="multi.macd.opt",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.macd.opt", initDate=initDate)

## ----results='hide'------------------------------------------------------
out<-applyStrategy("macd.opt" , portfolios="multi.macd.opt",
  parameters=list(nFast=fastMA, nSlow=slowMA, nSig=signalMA,maType=maType),
  verbose=TRUE)

## ----results='hide'------------------------------------------------------
updatePortf("multi.macd.opt")
updateAcct("multi.macd.opt")
updateEndEq("multi.macd.opt")

## ------------------------------------------------------------------------
checkBlotterUpdate("multi.macd.opt","multi.macd.opt")


## ----PERFOPT-------------------------------------------------------------
equity.curve <- getAccount("multi.macd.opt")$summary$End.Eq
returns.opt <- Return.calculate(equity.curve,"log")
table.AnnualizedReturns(returns.opt)
charts.PerformanceSummary(returns.opt,wealth.index=TRUE,colorset="blue",
  xlab="",main="MACD Performance (with stoploss)",minor.ticks=FALSE)

## ----TRADESTATSOPT,results='hide',fig.width=9,fig.height=9---------------
PerformanceAnalytics:::textplot(t(tradeStats("multi.macd.opt")))

## ----MAEVNQOPT,results='hide',fig.width=7,fig.height=7-------------------
chart.ME("multi.macd.opt",'VNQ',type='MAE',scale='percent')

## ----ORDERBOOKVNQOPT,results='hide',fig.width=9,fig.height=7-------------
ob <- getOrderBook("multi.macd.opt")$multi.macd.opt$VNQ
ob <- ob[ob$Order.Status=="closed",]
ob.df <- data.frame(Date=time(ob),coredata(ob),stringsAsFactors=FALSE)
ob.df$Order.Price <- round(as.numeric(ob.df$Order.Price),3)
PerformanceAnalytics:::textplot(ob.df,show.rownames=F)


## ----PERFOPTALL----------------------------------------------------------
rets <- cbind(returns.ns,returns.sl,returns.tr,returns.opt)
colnames(rets) <- c("NoStops","StopLoss","StopAndTrail","Optimal")
charts.PerformanceSummary(rets,main="Stop Comparision")

## ----RISKREWARDOPT,results='hide',fig.width=7,fig.height=7---------------
chart.RiskReturnScatter(rets,
main = "Risk Management Evolution", colorset = rich10equal)



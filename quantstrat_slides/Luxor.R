
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
Sys.setenv(TZ="UTC")
library(quantstrat)

## ------------------------------------------------------------------------
initDate = '2002-10-21'
.from=initDate
.to='2002-10-31'

## ----results='hide'------------------------------------------------------
currency(c('GBP', 'USD'))
exchange_rate('GBPUSD', tick_size=0.0001)

## ----results='hide'------------------------------------------------------
getSymbols.FI(Symbols='GBPUSD',
	      dir=system.file('extdata',package='quantstrat'),
	      from=.from, to=.to)

GBPUSD = to.minutes30(GBPUSD)
GBPUSD = align.time(GBPUSD, 1800)


## ----echo=FALSE----------------------------------------------------------
options(width=105)

## ----size='tiny'---------------------------------------------------------
dim(GBPUSD)
last(GBPUSD,5)

## ----echo=FALSE----------------------------------------------------------
options(width=81)

## ----GBPUSD--------------------------------------------------------------
myTheme<-chart_theme()
myTheme$col$dn.col<-'lightblue'
myTheme$col$dn.border <- 'lightgray'
myTheme$col$up.border <- 'lightgray'
chart_Series(GBPUSD,theme=myTheme)


## ------------------------------------------------------------------------
# moving average lengths
.fast = 10
.slow = 30

# optimization range
.FastSMA = (1:30)
.SlowSMA = (20:80)

# trade parameters
.threshold = 0.0005
.orderqty = 100000
.txnfees = -6  # round-trip fee

# stop loss amount
.stoploss <- 0.30/100
.StopLoss = seq(0.05, 0.6, length.out=48)/100

# trading window
.timespan = 'T00:00/T23:59'

# number of optimization samples
.nsamples=80


## ------------------------------------------------------------------------
portfolio.st = 'forex'
account.st = 'IB1'
strategy.st = 'luxor'

## ------------------------------------------------------------------------
rm.strat(portfolio.st)
rm.strat(account.st)

## ----results='hide'------------------------------------------------------
initPortf(portfolio.st, symbols='GBPUSD', initDate=initDate, currency='USD')
initAcct(account.st, portfolios=portfolio.st,initDate=initDate,currency='USD')
initOrders(portfolio.st, initDate=initDate)
strategy(strategy.st, store=TRUE)


## ----results='hide'------------------------------------------------------
add.indicator(strategy.st, name = "SMA",
	arguments = list(
		x = quote(Cl(mktdata)[,1]),
		n = .fast
	),
	label="nFast"
)

## ----results='hide'------------------------------------------------------
add.indicator(strategy.st, name="SMA",
	arguments = list(
		x = quote(Cl(mktdata)[,1]),
		n = .slow
	),
	label="nSlow"
)


## ----results='hide'------------------------------------------------------
add.signal(strategy.st, name='sigCrossover',
	arguments = list(
		columns=c("nFast","nSlow"),
		relationship="gte"
	),
	label='long'
)

## ----results='hide'------------------------------------------------------
add.signal(strategy.st, name='sigCrossover',
	arguments = list(
		columns=c("nFast","nSlow"),
		relationship="lt"
	),
	label='short'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name='ruleSignal',
    arguments=list(sigcol='long' , sigval=TRUE,
        orderside='long' ,
        ordertype='stoplimit',
        prefer='High',
        threshold=.threshold,
        orderqty=+.orderqty,
        replace=FALSE
        ),
    type='enter',
    label='EnterLONG'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name='ruleSignal',
    arguments=list(sigcol='short', sigval=TRUE,
        orderside='short',
        ordertype='stoplimit',
        prefer='Low',
        threshold=-.threshold,
        orderqty=-.orderqty,
        replace=FALSE
        ),
    type='enter',
    label='EnterSHORT'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name='ruleSignal',
	arguments=list(sigcol='short', sigval=TRUE,
		orderside='long' ,
		ordertype='market',
		orderqty='all',
		TxnFees=.txnfees,
		replace=TRUE
	),
	type='exit',
	label='Exit2SHORT'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name='ruleSignal',
	arguments=list(sigcol='long' , sigval=TRUE,
		orderside='short',
		ordertype='market',
		orderqty='all',
		TxnFees=.txnfees,
		replace=TRUE
	),
	type='exit',
	label='Exit2LONG'
)


## ----results='hide'------------------------------------------------------
out <- applyStrategy(strategy.st, portfolio.st)
updatePortf(portfolio.st, Symbols='GBPUSD',
  Dates=paste('::',as.Date(Sys.time()),sep=''))

## ----CHARTLUXOR1---------------------------------------------------------
chart.Posn(portfolio.st, "GBPUSD",
  TA="add_SMA(n=10,col=2);add_SMA(n=30,col=4)",theme=myTheme)

## ----LUXORSTATS1---------------------------------------------------------
PerformanceAnalytics:::textplot(t(tradeStats(portfolio.st, 'GBPUSD')))

## ----MKTDATA-------------------------------------------------------------
mk <- mktdata['2002-10-23 15:00::2002-10-24 03:00']
mk.df <- data.frame(Date=time(mk),coredata(mk))
PerformanceAnalytics:::textplot(mk.df,show.rownames=F)

## ----ORDERBOOK,fig.width=9,	fig.height=6---------------------------------
ob <- getOrderBook(portfolio.st)$forex$GBPUSD
ob.df <- data.frame(Date=time(ob),coredata(ob))
PerformanceAnalytics:::textplot(ob.df,show.rownames=F)

## ----PERTRADESTATS-------------------------------------------------------
PerformanceAnalytics:::textplot(perTradeStats(portfolio.st,"GBPUSD"),
  show.rownames=F)

## ----MAE,fig.width=7,	fig.height=7---------------------------------------
chart.ME(portfolio.st,'GBPUSD',type='MAE',scale='percent')


## ------------------------------------------------------------------------
args(add.distribution)

## ----results='hide'------------------------------------------------------
add.distribution(strategy.st,
	paramset.label = 'SMA',
	component.type = 'indicator',
	component.label = 'nFast',
	variable = list(n = .FastSMA),
	label = 'nFAST'
)


## ----results='hide'------------------------------------------------------
add.distribution(strategy.st,
	paramset.label = 'SMA',
	component.type = 'indicator',
	component.label = 'nSlow',
	variable = list(n = .SlowSMA),
	label = 'nSLOW'
)


## ------------------------------------------------------------------------
args(add.distribution.constraint)

## ----results='hide'------------------------------------------------------
add.distribution.constraint(strategy.st,
	paramset.label = 'SMA',
	distribution.label.1 = 'nFAST',
	distribution.label.2 = 'nSLOW',
	operator = '<',
	label = 'SMA'
)


## ------------------------------------------------------------------------
rm.strat(portfolio.st)
rm.strat(account.st)

## ----results='hide'------------------------------------------------------
initPortf(portfolio.st, symbols='GBPUSD', initDate=initDate, currency='USD')
initAcct(account.st, portfolios=portfolio.st,
  initDate=initDate, currency='USD')
initOrders(portfolio.st, initDate=initDate)


## ------------------------------------------------------------------------
library(parallel)
detectCores()

## ----results='hide'------------------------------------------------------
if( Sys.info()['sysname'] == "Windows" )
{
  library(doParallel)
  registerDoParallel(cores=detectCores())
} else {
  library(doMC)
  registerDoMC(cores=detectCores())
}

## ------------------------------------------------------------------------
foreach(i=1:8, .combine=c) %dopar% sqrt(i)

## ----echo=FALSE,results='hide'-------------------------------------------
if( Sys.info()['sysname'] == "Windows" )
{
  registerDoSEQ()
}

## ----results='hide'------------------------------------------------------


## ------------------------------------------------------------------------
args(apply.paramset)


## ----echo=FALSE,results='hide'-------------------------------------------
if( Sys.info()['sysname'] == "Windows" )
{
  if(file.exists("resultsMAOpt.RData"))
  {
    load("resultsMAOpt.RData")
  } else {
    results <- apply.paramset(strategy.st, paramset.label='SMA',
      portfolio.st=portfolio.st, account.st=account.st, nsamples=0)
      save(list="results",file="resultsMAOpt.RData")
  }
} else {
  if(file.exists("resultsMAOpt.RData"))
  {
    load("resultsMAOpt.RData")
  } else {
    results <- apply.paramset(strategy.st, paramset.label='SMA',
      portfolio.st=portfolio.st, account.st=account.st, nsamples=0)
    save(list="results",file="resultsMAOpt.RData")
  }
}

## ----eval=FALSE----------------------------------------------------------
## results <- apply.paramset(strategy.st, paramset.label='SMA',
##   portfolio.st=portfolio.st, account.st=account.st, nsamples=0)

## ------------------------------------------------------------------------
head(names(results),20)

## ----PARAMSETTRADESTATS--------------------------------------------------
tS <- results$tradeStats
idx <- order(tS[,1],tS[,2])
tS <- tS[idx,]
PerformanceAnalytics:::textplot(t(tS)[,1:10])


## ----NETPROFITHEAT,fig.width=7,fig.height=7,dev='png',dpi=300------------
# net profit
z <- tapply(X=tS[,"End.Equity"],INDEX=list(Fast=tS[,1],Slow=tS[,2]),FUN=sum)
z[1:5,1:10]
x <- as.numeric(rownames(z))
y <- as.numeric(colnames(z))
filled.contour(x=x,y=y,z=z,color = heat.colors,xlab="Fast MA",ylab="Slow MA")
title("Net Profit")


## ----MAXDDHEAT,fig.width=7,fig.height=7,dev='png',dpi=300----------------
# maxdd
z <- tapply(X=tS[,"Max.Drawdown"],INDEX=list(Fast=tS[,1],Slow=tS[,2]),FUN=sum)
x <- as.numeric(rownames(z))
y <- as.numeric(colnames(z))
filled.contour(x=x,y=y,z=z,color = heat.colors,xlab="Fast MA",ylab="Slow MA")
title("Max Drawdown")


## ----PFACTORHEAT,fig.width=7,fig.height=7,dev='png',dpi=300--------------
# profit factor
z <- tapply(X=tS[,"Profit.Factor"],INDEX=list(Fast=tS[,1],Slow=tS[,2]),FUN=sum)
x <- as.numeric(rownames(z))
y <- as.numeric(colnames(z))
filled.contour(x=x,y=y,z=z,color = heat.colors,xlab="Fast MA",ylab="Slow MA")
title("Profit Factor")

## ----AVGTRADEHEAT,fig.width=7,fig.height=7,dev='png',dpi=300-------------
# avg trade P&L
z <- tapply(X=tS[,"Avg.Trade.PL"],INDEX=list(Fast=tS[,1],Slow=tS[,2]),FUN=sum)
x <- as.numeric(rownames(z))
y <- as.numeric(colnames(z))
filled.contour(x=x,y=y,z=z,color = heat.colors,xlab="Fast MA",ylab="Slow MA")
title("Average Trade")


## ----RET2MDDHEAT,fig.width=7,fig.height=7,dev='png',dpi=300--------------
# return to maxdd
z <- tapply(X=tS[,"Profit.To.Max.Draw"],
  INDEX=list(Fast=tS[,1],Slow=tS[,2]),FUN=sum)
x <- as.numeric(rownames(z))
y <- as.numeric(colnames(z))
filled.contour(x=x,y=y,z=z,color = heat.colors,xlab="Fast MA",ylab="Slow MA")
title("Return to Max Drawdown")

## ----RET2MDDBAR----------------------------------------------------------
rmdd <- tS$Profit.To.Max.Draw
idx <- order(rmdd,decreasing=T)[1:30]
labs <- paste(tS$nFAST[idx],tS$nSLOW[idx],sep="/")
barplot(rmdd[idx],names.arg=labs,col=4,las=2,main="Return to MaxDrawdown")


## ------------------------------------------------------------------------
args(tradeGraphs)

## ----eval=FALSE----------------------------------------------------------
## 
## tradeGraphs (stats = tS, free.params = c("nFAST", "nSLOW"),
##   statistics = c("Profit.To.Max.Draw","Net.Trading.PL", "Max.Drawdown",
##   "Avg.Trade.PL", "Num.Trades", "Profit.Factor"), title = '')


## ------------------------------------------------------------------------
rm.strat(strategy.st)
strategy(strategy.st, store=TRUE)

## ----results='hide'------------------------------------------------------
add.indicator(strategy.st, name = "SMA",
	arguments = list(
		x = quote(Cl(mktdata)[,1]),
		n = .fast
	),
	label="nFast"
)

## ----results='hide'------------------------------------------------------
add.indicator(strategy.st, name="SMA",
	arguments = list(
		x = quote(Cl(mktdata)[,1]),
		n = .slow
	),
	label="nSlow"
)


## ----results='hide'------------------------------------------------------
add.signal(strategy.st, name='sigCrossover',
	arguments = list(
		columns=c("nFast","nSlow"),
		relationship="gte"
	),
	label='long'
)

## ----results='hide'------------------------------------------------------
add.signal(strategy.st, name='sigCrossover',
	arguments = list(
		columns=c("nFast","nSlow"),
		relationship="lt"
	),
	label='short'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name = 'ruleSignal',
	arguments=list(sigcol='long' , sigval=TRUE,
		replace=FALSE,
		orderside='long' ,
		ordertype='stoplimit',
		prefer='High',
		threshold=.threshold,
		TxnFees=0,
		orderqty=+.orderqty,
		osFUN=osMaxPos,
		orderset='ocolong'
	),
	type='enter',
	timespan = .timespan,
	label='EnterLONG'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name = 'ruleSignal',
	arguments=list(sigcol='short', sigval=TRUE,
		replace=FALSE,
		orderside='short',
		ordertype='stoplimit',
		prefer='Low',
		threshold=.threshold,
		TxnFees=0,
		orderqty=-.orderqty,
		osFUN=osMaxPos,
		orderset='ocoshort'
	),
	type='enter',
	timespan = .timespan,
	label='EnterSHORT'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name = 'ruleSignal',
	arguments=list(sigcol='short', sigval=TRUE,
		replace=TRUE,
		orderside='long' ,
		ordertype='market',
		TxnFees=.txnfees,
		orderqty='all',
		orderset='ocolong'
	),
	type='exit',
	timespan = .timespan,
	label='Exit2SHORT'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name = 'ruleSignal',
	arguments=list(sigcol='long' , sigval=TRUE,
		replace=TRUE,
		orderside='short',
		ordertype='market',
		TxnFees=.txnfees,
		orderqty='all',
		orderset='ocoshort'
	),
	type='exit',
	timespan = .timespan,
	label='Exit2LONG'
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name = 'ruleSignal',
    arguments=list(sigcol='long' , sigval=TRUE,
        replace=FALSE,
        orderside='long',
        ordertype='stoplimit',
        tmult=TRUE,
        threshold=quote(.stoploss),
        TxnFees=.txnfees,
        orderqty='all',
        orderset='ocolong'
    ),
    type='chain', parent='EnterLONG',
    label='StopLossLONG',
    enabled=FALSE
)


## ----results='hide'------------------------------------------------------
add.rule(strategy.st, name = 'ruleSignal',
    arguments=list(sigcol='short' , sigval=TRUE,
        replace=FALSE,
        orderside='short',
        ordertype='stoplimit',
        tmult=TRUE,
        threshold=quote(.stoploss),
        TxnFees=.txnfees,
        orderqty='all',
        orderset='ocoshort'
    ),
    type='chain', parent='EnterSHORT',
    label='StopLossSHORT',
    enabled=FALSE
)


## ------------------------------------------------------------------------
rm.strat(portfolio.st)
rm.strat(account.st)

## ----results='hide'------------------------------------------------------
initPortf(portfolio.st, symbols='GBPUSD', initDate=initDate, currency='USD')
addPosLimit(
            portfolio=portfolio.st,
            symbol='GBPUSD',
            timestamp=initDate,
            maxpos=.orderqty)

initAcct(account.st, portfolios=portfolio.st,initDate=initDate,currency='USD')
initOrders(portfolio.st, initDate=initDate)

## ----results='hide'------------------------------------------------------
enable.rule('luxor', 'chain', 'StopLoss')


## ----results='hide'------------------------------------------------------
out <- applyStrategy(strategy.st, portfolio.st)
updatePortf(portfolio.st, Symbols='GBPUSD',
  Dates=paste('::',as.Date(Sys.time()),sep=''))

## ----CHARTLUXOR1SL-------------------------------------------------------
chart.Posn(portfolio.st,"GBPUSD",TA="add_SMA(n=10,col=2);add_SMA(n=30,col=4)",
  theme=myTheme)

## ----LUXORSTATS1SL-------------------------------------------------------
PerformanceAnalytics:::textplot(t(tradeStats(portfolio.st, 'GBPUSD')))

## ----ORDERBOOKSL---------------------------------------------------------
ob <- getOrderBook(portfolio.st)$forex$GBPUSD
ob.df <- data.frame(Date=time(ob),coredata(ob))
PerformanceAnalytics:::textplot(ob.df,show.rownames=F)

## ----PERTRADESTATSSL-----------------------------------------------------
PerformanceAnalytics:::textplot(perTradeStats(portfolio.st,"GBPUSD"),
  show.rownames=F)

## ----MAESL,fig.width=7,	fig.height=7-------------------------------------
chart.ME(portfolio.st,'GBPUSD',type='MAE',scale='percent')


## ----results='hide'------------------------------------------------------
add.distribution(strategy.st,
	paramset.label = 'StopLoss',
	component.type = 'chain',
	component.label = 'StopLossLONG',
	variable = list(threshold = .StopLoss),
	label = 'StopLossLONG'
)


## ----results='hide'------------------------------------------------------
add.distribution(strategy.st,
	paramset.label = 'StopLoss',
	component.type = 'chain',
	component.label = 'StopLossSHORT',
	variable = list(threshold = .StopLoss),
	label = 'StopLossSHORT'
)


## ----results='hide'------------------------------------------------------
add.distribution.constraint(strategy.st,
	paramset.label = 'StopLoss',
	distribution.label.1 = 'StopLossLONG',
	distribution.label.2 = 'StopLossSHORT',
	operator = '==',
	label = 'StopLoss'
)


## ------------------------------------------------------------------------
rm.strat(portfolio.st)
rm.strat(account.st)

## ----results='hide'------------------------------------------------------
initPortf(portfolio.st, symbols='GBPUSD', initDate=initDate, currency='USD')

## ----results='hide'------------------------------------------------------
addPosLimit(
            portfolio=portfolio.st,
            symbol='GBPUSD',
            timestamp=initDate,
            maxpos=.orderqty)

## ----results='hide'------------------------------------------------------
initAcct(account.st, portfolios=portfolio.st,initDate=initDate,currency='USD')
initOrders(portfolio.st, initDate=initDate)

## ----results='hide'------------------------------------------------------
enable.rule('luxor', 'chain', 'StopLoss')


## ----echo=FALSE,results='hide'-------------------------------------------
if( Sys.info()['sysname'] == "Windows" )
{
  if(file.exists("resultsSLOpt.RData"))
  {
    load("resultsSLOpt.RData")
  } else {
    results <- apply.paramset(strategy.st, paramset.label='StopLoss',
      portfolio.st=portfolio.st, account.st=account.st, nsamples=0, verbose=TRUE)
    save(list="results",file="resultsSLOpt.RData")
  }
} else {
  if(file.exists("resultsSLOpt.RData"))
  {
    load("resultsSLOpt.RData")
  } else {
    results <- apply.paramset(strategy.st, paramset.label='StopLoss',
      portfolio.st=portfolio.st, account.st=account.st, nsamples=0, verbose=TRUE)
    save(list="results",file="resultsSLOpt.RData")
  }
}

## ----eval=FALSE----------------------------------------------------------
## results <- apply.paramset(strategy.st, paramset.label='StopLoss',
##   portfolio.st=portfolio.st, account.st=account.st, nsamples=0, verbose=TRUE)

## ----PARAMSETTRADESTATSSL------------------------------------------------
tS <- results$tradeStats
idx <- order(tS[,1])
tS <- tS[idx,]
PerformanceAnalytics:::textplot(t(tS)[,1:5])

## ----STOPLOSSANAL,fig.width=9,fig.height=3.5-----------------------------
par(mfrow=c(1,3))
plot(100*tS$StopLossLONG, tS$Net.Trading.PL, type='b', xlab='Stoploss %',
  ylab='Net.Trading.PL', main='Net Profit vs Stop Loss',col=4)
plot(100*tS$StopLossLONG, tS$Max.Drawdown, type='b', xlab='Stoploss %',
  ylab='Max.Drawdown', main='MaxDrawdown vs Stop Loss',col=4)
plot(100*tS$StopLossLONG, tS$Profit.To.Max.Draw, type='b', xlab='Stoploss %',
  ylab='Profit.To.Max.Draw', main='Return/MaxDD vs Stop Loss',col=4)
par(mfrow=c(1,1))



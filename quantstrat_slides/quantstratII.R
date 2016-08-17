
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


## ----results='hide'------------------------------------------------------
library(quantstrat)
startDate <- '2010-01-01'  # start of data
endDate <-  '2013-07-31'   # end of data
symbols = c("XLF", "XLP", "XLE", "XLY", "XLV", "XLI", "XLB", "XLK", "XLU")
Sys.setenv(TZ="UTC")       # set time zone

## ----echo=FALSE,results='hide'-------------------------------------------
if(file.exists("XLX.RData"))
{
  load("XLX.RData")
} else {
  getSymbols(symbols, src='yahoo', index.class=c("POSIXt","POSIXct"),
    from=startDate, to=endDate, adjust=TRUE)
  save(list=symbols,file="XLX.RData")
}

## ----eval=FALSE----------------------------------------------------------
## getSymbols(symbols, src='yahoo', index.class=c("POSIXt","POSIXct"),
##   from=startDate, to=endDate, adjust=TRUE)


## ------------------------------------------------------------------------
myTheme<-chart_theme()
myTheme$col$dn.col<-'lightblue'
myTheme$col$dn.border <- 'lightgray'
myTheme$col$up.border <- 'lightgray'

## ----XLX3x3,cache=FALSE,fig.height=6,fig.width=9-------------------------
par(mfrow=c(3,3))
for(symbol in symbols)
{
  plot(chart_Series(get(symbol),name=symbol,theme=myTheme))
}
par(mfrow=c(1,1))


## ----results='hide'------------------------------------------------------
initDate <- '2009-12-31'
initEq <- 1e6
currency("USD")
stock(symbols, currency="USD",multiplier=1)


## ----XLFBB,cache=FALSE---------------------------------------------------
args(BBands)
b <- BBands(HLC=HLC(XLF["2013"]), n=20, sd=2)
tail(b)
chart_Series(XLF["2013"],TA='add_BBands(lwd=2)',theme=myTheme,name="XLF")


## ----results='hide'------------------------------------------------------
rm.strat("multiAsset.bb1") # remove portfolio, account, orderbook if re-run
initPortf(name="multiAsset.bb1", symbols, initDate=initDate)
initAcct(name="multiAsset.bb1", portfolios="multiAsset.bb1",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multiAsset.bb1", initDate=initDate)


## ----results='hide'------------------------------------------------------
strategy("bbands", store=TRUE)

## ------------------------------------------------------------------------
args(BBands)

## ----results='hide'------------------------------------------------------
add.indicator("bbands", name = "BBands",
  arguments = list(HLC = quote(HLC(mktdata)), maType='SMA'), label='BBands')


## ----results='hide'------------------------------------------------------
add.signal("bbands", name="sigCrossover",
  arguments=list(columns=c("Close","up"),relationship="gt"),
  label="Cl.gt.UpperBand")

## ----results='hide'------------------------------------------------------
add.signal("bbands", name="sigCrossover",
  arguments=list(columns=c("Close","dn"),relationship="lt"),
  label="Cl.lt.LowerBand")

## ----results='hide'------------------------------------------------------
add.signal("bbands", name="sigCrossover",
  arguments=list(columns=c("High","Low","mavg"),relationship="op"),
  label="Cross.Mid")


## ----results='hide'------------------------------------------------------
add.rule("bbands", name='ruleSignal',
  arguments=list(sigcol="Cl.gt.UpperBand",sigval=TRUE, orderqty=-100,
  ordertype='market', orderside=NULL),type='enter')

## ----results='hide'------------------------------------------------------
add.rule("bbands", name='ruleSignal',
  arguments=list(sigcol="Cl.lt.LowerBand",sigval=TRUE, orderqty= 100,
  ordertype='market', orderside=NULL),type='enter')

## ----results='hide'------------------------------------------------------
add.rule("bbands", name='ruleSignal',
  arguments=list(sigcol="Cross.Mid",sigval=TRUE, orderqty= 'all',
  ordertype='market', orderside=NULL),type='exit')


## ----results='hide'------------------------------------------------------
SD = 2
N = 20

## ----results='hide'------------------------------------------------------
out <- applyStrategy("bbands",
  portfolios="multiAsset.bb1",parameters=list(sd=SD,n=N))


## ----results='hide'------------------------------------------------------
updatePortf("multiAsset.bb1")
updateAcct("multiAsset.bb1")
updateEndEq("multiAsset.bb1")


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
checkBlotterUpdate("multiAsset.bb1","multiAsset.bb1")


## ----XLBCP,cache=FALSE---------------------------------------------------
chart.Posn("multiAsset.bb1","XLB",TA="add_BBands(n=20,sd=2)",theme=myTheme)

## ----XLBCP2,cache=FALSE--------------------------------------------------
chart.Posn("multiAsset.bb1","XLB",TA="add_BBands(n=20,sd=2)",
  Dates="2010",theme=myTheme)


## ----results='hide'------------------------------------------------------
rm.strat("multiAsset.bb2") # remove portfolio, account, orderbook if re-run
initPortf(name="multiAsset.bb2", symbols, initDate=initDate)
initAcct(name="multiAsset.bb2", portfolios="multiAsset.bb2",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multiAsset.bb2", initDate=initDate)

## ----results='hide'------------------------------------------------------
SD=3
out <- applyStrategy("bbands",
  portfolios="multiAsset.bb2",parameters=list(sd=SD,n=N))

## ----results='hide'------------------------------------------------------
updatePortf("multiAsset.bb2")
updateAcct("multiAsset.bb2")
updateEndEq("multiAsset.bb2")

## ------------------------------------------------------------------------
checkBlotterUpdate("multiAsset.bb2","multiAsset.bb2")


## ----BBCUMRET,cache=FALSE------------------------------------------------
eq1 <- getAccount("multiAsset.bb1")$summary$End.Eq
rt1 <- Return.calculate(eq1,"log")
eq2 <- getAccount("multiAsset.bb2")$summary$End.Eq
rt2 <- Return.calculate(eq2,"log")
returns <- cbind(rt1,rt2)
colnames(returns) <- c("SD=2","SD=3")
chart.CumReturns(returns,colorset=c(2,4),legend.loc="topleft",
  main="BBand SD Parameter Comparison",ylab="cum return",xlab="",
  minor.ticks=FALSE)


## ------------------------------------------------------------------------
args(ruleSignal)


## ------------------------------------------------------------------------
args(osNoOp)


## ------------------------------------------------------------------------
osFixedDollar <- function(timestamp,orderqty, portfolio, symbol, ruletype, ...)
{
  ClosePrice <- as.numeric(Cl(mktdata[timestamp,]))
  orderqty <- round(tradeSize/ClosePrice,-2)
  return(orderqty)
}


## ----XLVMACD,cache=FALSE-------------------------------------------------
args(MACD)
macd  <- MACD( Cl(XLV), 12, 26, 9, maType="EMA" )
tail(macd,3)
chart_Series(XLV,
  TA="add_MACD();add_EMA(12,col='darkgreen');add_EMA(26,col='blue')",
  subset="20100717::20101208",theme=myTheme)


## ----results='hide'------------------------------------------------------
rm.strat("multi.macd") # remove portfolio, account, orderbook if re-run
initPortf(name="multi.macd", symbols, initDate=initDate)
initAcct(name="multi.macd", portfolios="multi.macd",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.macd", initDate=initDate)


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
  arguments = list(sigcol="signal.gt.zero",sigval=TRUE,orderqty=100,
  ordertype='market',orderside='long',osFUN='osFixedDollar'),
  type='enter',label='enter',storefun=FALSE)

## ----results='hide'------------------------------------------------------
add.rule("macd",name='ruleSignal',
  arguments = list(sigcol="signal.lt.zero",sigval=TRUE,orderqty='all',
  ordertype='market',orderside='long'),
  type='exit',label='exit')


## ----results='hide'------------------------------------------------------
fastMA = 12
slowMA = 26
signalMA = 9
maType="EMA"
tradeSize <- initEq/10

## ----results='hide'------------------------------------------------------
out<-applyStrategy("macd" , portfolios="multi.macd",
  parameters=list(nFast=fastMA, nSlow=slowMA, nSig=signalMA,maType=maType),
  verbose=TRUE)


## ----results='hide'------------------------------------------------------
updatePortf("multi.macd")
updateAcct("multi.macd")
updateEndEq("multi.macd")

## ------------------------------------------------------------------------
checkBlotterUpdate("multi.macd","multi.macd")


## ----MACDCPOSN1,cache=FALSE----------------------------------------------
chart.Posn(Portfolio="multi.macd",Symbol="XLV",theme=myTheme)

## ----MACDCPOSN2,cache=FALSE----------------------------------------------
chart.Posn(Portfolio="multi.macd",Symbol="XLV",
  Dates="201006::20101213",theme=myTheme)
add_MACD()
add_EMA(12,col='red')
add_EMA(26,col='blue')


## ----echo=FALSE----------------------------------------------------------
options(width=105)

## ----size='tiny'---------------------------------------------------------
perTradeStats("multi.macd","XLF")

## ----echo=FALSE----------------------------------------------------------
options(width=82)


## ----results='hide'------------------------------------------------------
strategy("bb.lim", store=TRUE)

## ----results='hide'------------------------------------------------------
add.indicator("bb.lim", name = "BBands",
  arguments = list(HLC = quote(HLC(mktdata)), maType='SMA'), label='BBands')

## ----results='hide'------------------------------------------------------
add.signal("bb.lim", name="sigCrossover",
  arguments=list(columns=c("Close","up"),relationship="gt"),
  label="Cl.gt.UpperBand")

## ----results='hide'------------------------------------------------------
add.signal("bb.lim", name="sigCrossover",
  arguments=list(columns=c("Close","dn"),relationship="lt"),
  label="Cl.lt.LowerBand")

## ----results='hide'------------------------------------------------------
add.signal("bb.lim", name="sigCrossover",
  arguments=list(columns=c("High","Low","mavg"),relationship="op"),
  label="Cross.Mid")


## ----results='hide'------------------------------------------------------
add.rule("bb.lim", name='ruleSignal',
  arguments=list(sigcol="Cl.gt.UpperBand",sigval=TRUE, orderqty=-1000,
  ordertype='market', orderside=NULL, osFUN='osMaxPos'),
  type='enter')

## ----results='hide'------------------------------------------------------
add.rule("bb.lim", name='ruleSignal',
  arguments=list(sigcol="Cl.lt.LowerBand",sigval=TRUE, orderqty= 1000,
  ordertype='market', orderside=NULL, osFUN='osMaxPos'),
  type='enter')

## ----results='hide'------------------------------------------------------
add.rule("bb.lim", name='ruleSignal',
  arguments=list(sigcol="Cross.Mid",sigval=TRUE, orderqty= 'all',
  ordertype='market', orderside=NULL),type='exit')


## ------------------------------------------------------------------------
args(addPosLimit)


## ----results='hide'------------------------------------------------------
rm.strat("multi.bb.limit") # remove portfolio, account, orderbook if re-run
initPortf(name="multi.bb.limit", symbols, initDate=initDate)
initAcct(name="multi.bb.limit", portfolios="multi.bb.limit",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.bb.limit", initDate=initDate)

## ------------------------------------------------------------------------
for(symbol in symbols)
{
  addPosLimit("multi.bb.limit", symbol, initDate, 200, 2 )
}


## ----results='hide'------------------------------------------------------
SD = 2
N = 20

## ----results='hide'------------------------------------------------------
out <- applyStrategy("bb.lim",
  portfolios="multi.bb.limit",parameters=list(sd=SD,n=N))

## ----results='hide'------------------------------------------------------
updatePortf("multi.bb.limit")
updateAcct("multi.bb.limit")
updateEndEq("multi.bb.limit")

## ------------------------------------------------------------------------
checkBlotterUpdate("multi.bb.limit","multi.bb.limit")

## ----XLBCPLIM,cache=FALSE------------------------------------------------
chart.Posn("multi.bb.limit","XLB",TA="add_BBands(n=20,sd=2)",theme=myTheme)

## ----XLBCPLIM2,cache=FALSE-----------------------------------------------
chart.Posn("multi.bb.limit","XLB",TA="add_BBands(n=20,sd=2)",
  Dates="2010",theme=myTheme)


## ----results='hide'------------------------------------------------------
strategy("faber",store=TRUE)

## ----results='hide'------------------------------------------------------
add.indicator(strategy = "faber", name = "SMA",
  arguments = list(x = quote(Cl(mktdata))), label="SMAn")

## ----results='hide'------------------------------------------------------
add.signal("faber",name="sigCrossover",
  arguments = list(columns=c("Close","SMAn"),relationship="gt"),
  label="Cl.gt.SMA")

## ----results='hide'------------------------------------------------------
add.signal("faber",name="sigCrossover",
  arguments = list(columns=c("Close","SMAn"),relationship="lt"),
  label="Cl.lt.SMA")


## ----results='hide'------------------------------------------------------
add.rule("faber", name='ruleSignal',
  arguments = list(sigcol="Cl.gt.SMA", sigval=TRUE, orderqty=100000,
  ordertype='market', orderside='long', osFUN='osMaxPos'),
  type='enter', path.dep=TRUE)

## ----results='hide'------------------------------------------------------
add.rule("faber", name='ruleSignal',
  arguments = list(sigcol="Cl.lt.SMA", sigval=TRUE, orderqty='all',
  ordertype='market', orderside='long', pricemethod='market'),
  type='exit', path.dep=TRUE)


## ------------------------------------------------------------------------
args(rulePctEquity)


## ----results='hide'------------------------------------------------------
# add quaterly rebalancing
add.rule('faber', 'rulePctEquity',
  arguments=list(rebalance_on='months',
    trade.percent=1/length(symbols),
    refprice=quote(
      last(getPrice(mktdata)[paste('::',as.character(curIndex),sep='')][,1])
      ),
    digits=0
  ),
  type='rebalance',
  label='rebalance'
)


## ----results='hide'------------------------------------------------------
rm.strat("multi.faber") # remove portfolio, account, orderbook if re-run

## ----results='hide'------------------------------------------------------
initPortf(name="multi.faber", symbols, initDate=initDate)
initAcct(name="multi.faber", portfolios="multi.faber",
  initDate=initDate, initEq=initEq)
initOrders(portfolio="multi.faber", initDate=initDate)

## ------------------------------------------------------------------------
(posval <- initEq/length(symbols))
for(symbol in symbols){
    pos<-round((posval/first(getPrice(get(symbol)))),-2)
    addPosLimit('multi.faber',symbol,initDate, maxpos=pos,minpos=-pos)
}


## ----results='hide'------------------------------------------------------
out <- applyStrategy.rebalancing(strategy="faber", portfolios="multi.faber",
  parameters=list(n=200))

## ----results='hide'------------------------------------------------------
updatePortf("multi.faber")
updateAcct("multi.faber")
updateEndEq("multi.faber")

## ------------------------------------------------------------------------
checkBlotterUpdate("multi.faber","multi.faber")

## ----XLKCPF,cache=FALSE--------------------------------------------------
chart.Posn("multi.faber","XLF",TA="add_SMA(n=200)",theme=myTheme)


## ----echo=FALSE----------------------------------------------------------
options(width=125)

## ----size='Tiny'---------------------------------------------------------
(pts <- perTradeStats("multi.faber","XLU"))

## ----XLUBAR,cache=FALSE--------------------------------------------------
mnc <- pts$Max.Notional.Cost
pe <- sapply(pts$Start,getEndEq,Account="multi.faber")/9
barplot(rbind(pe,mnc),beside=T,col=c(2,4),names.arg=format(pts$Start,"%m/%d/%y"),
  ylim=c(0,1.5e5),ylab="$",xlab="Trade Date")
legend(x="topleft",legend=c("(Portfolio Equity)/9","Order Size"),
  pch=15,col=c(2,4),bty="n")
title("Percent of Portfolio Equity versus Trade Size for XLU")

## ----echo=FALSE----------------------------------------------------------
options(width=82)



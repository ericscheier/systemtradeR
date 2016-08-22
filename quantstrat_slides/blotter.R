
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


## ----cache=FALSE---------------------------------------------------------
library(blotter)
search()


## ------------------------------------------------------------------------
ls()
ls(all=T)


## ------------------------------------------------------------------------
args(currency)
args(stock)


## ----echo=FALSE,results='hide'-------------------------------------------
suppressWarnings(try(rm(list=c("account.bFaber","portfolio.bFaber"),pos=.blotter),silent=TRUE))
suppressWarnings(try(rm(list=c("b.strategy","myTheme","SPY",".getSymbols")),silent=TRUE))


## ------------------------------------------------------------------------
currency("USD")
stock("SPY",currency="USD",multiplier=1)
ls(all=T)
ls(envir=FinancialInstrument:::.instrument)


## ------------------------------------------------------------------------
get("USD",envir=FinancialInstrument:::.instrument)
get("SPY",envir=FinancialInstrument:::.instrument)


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


## ----echo=FALSE,cache=FALSE----------------------------------------------
options(width=120,digits=6)

## ------------------------------------------------------------------------
SPY=to.monthly(SPY, indexAt='endof', drop.time=FALSE)
SPY$SMA10m <- SMA(Cl(SPY), 10)
tail(SPY)

## ----echo=FALSE,cache=FALSE----------------------------------------------
options(width=81,digits=8)


## ------------------------------------------------------------------------
args(initPortf)


## ------------------------------------------------------------------------
args(initAcct)


## ----echo=FALSE,cache=FALSE----------------------------------------------
options(width=120,digits=6)

## ------------------------------------------------------------------------
b.strategy <- "bFaber"
initPortf(b.strategy, 'SPY', initDate=initDate)
initAcct(b.strategy, portfolios=b.strategy, initDate=initDate, initEq=initEq)
initDate
first(SPY)

## ----echo=FALSE,cache=FALSE----------------------------------------------
options(width=81,digits=8)


## ------------------------------------------------------------------------
ls()
ls(.blotter)
ls(envir=FinancialInstrument:::.instrument)


## ----FABER,cache=FALSE---------------------------------------------------
# create custom theme
myTheme<-chart_theme()
myTheme$col$dn.col<-'lightblue'
myTheme$col$dn.border <- 'lightgray'
myTheme$col$up.border <- 'lightgray'

# plot OHLC series
chart_Series(
  x=SPY,
  theme=myTheme,
  name="SPY",
  TA="add_SMA(n=10,col=4)"
  )


## ----results='hide',size='tiny'------------------------------------------
for( i in 1:nrow(SPY) )
{
  # update values for this date
  CurrentDate <- time(SPY)[i]
  equity = getEndEq(b.strategy, CurrentDate)
  ClosePrice <- as.numeric(Cl(SPY[i,]))
  Posn <- getPosQty(b.strategy, Symbol='SPY', Date=CurrentDate)
  UnitSize = as.numeric(trunc(equity/ClosePrice))
  MA <- as.numeric(SPY[i,'SMA10m'])
  # change market position if necessary
  if( !is.na(MA) ) # if the moving average has begun
  {
    if( Posn == 0 ) { # No position, test to go Long
      if( ClosePrice > MA ) {
        # enter long position
        addTxn(b.strategy, Symbol='SPY', TxnDate=CurrentDate,
          TxnPrice=ClosePrice, TxnQty = UnitSize , TxnFees=0) }
    } else { # Have a position, so check exit
      if( ClosePrice < MA ) {
        # exit position
        addTxn(b.strategy, Symbol='SPY', TxnDate=CurrentDate,
          TxnPrice=ClosePrice, TxnQty = -Posn , TxnFees=0)
      } else {
        if( i==nrow(SPY) ) # exit on last day
          addTxn(b.strategy, Symbol='SPY', TxnDate=CurrentDate,
            TxnPrice=ClosePrice, TxnQty = -Posn , TxnFees=0)
      }
    }
  }
  updatePortf(b.strategy,Dates=CurrentDate)
  updateAcct(b.strategy,Dates=CurrentDate)
  updateEndEq(b.strategy,CurrentDate)
} # End dates loop


## ----echo=F--------------------------------------------------------------
options(width=120)

## ----size='tiny'---------------------------------------------------------
getTxns(Portfolio=b.strategy, Symbol="SPY")

## ----echo=F--------------------------------------------------------------
options(width=81)


## ------------------------------------------------------------------------
args(updatePortf)


## ------------------------------------------------------------------------
args(updateAcct)


## ------------------------------------------------------------------------
args(updateEndEq)


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
checkBlotterUpdate(b.strategy,b.strategy)


## ----PERF,cache=FALSE----------------------------------------------------
args(chart.Posn)
chart.Posn(b.strategy, Symbol = 'SPY',theme=myTheme,
  TA='add_SMA(n=10,col=4, on=1)')


## ------------------------------------------------------------------------
tstats <- tradeStats(Portfolio=b.strategy)

## ----TSTATS1,echo=FALSE,cache=FALSE--------------------------------------
textplot(t(tstats)[1:15,,drop=FALSE],show.colnames=FALSE,halign='left')

## ----TSTATS2,echo=FALSE,cache=FALSE--------------------------------------
textplot(t(tstats)[16:30,,drop=FALSE],show.colnames=FALSE,halign='left')


## ------------------------------------------------------------------------
# trade related
tab.trades <- cbind(
  c("Trades","Win Percent","Loss Percent","W/L Ratio"),
  c(tstats[,"Num.Trades"],tstats[,c("Percent.Positive","Percent.Negative")],
  tstats[,"Percent.Positive"]/tstats[,"Percent.Negative"]))

# profit related
tab.profit <- cbind(
  c("Net Profit","Gross Profits","Gross Losses","Profit Factor"),
  c(tstats[,c("Net.Trading.PL","Gross.Profits","Gross.Losses",
    "Profit.Factor")]))

# averages
tab.wins <- cbind(
  c("Avg Trade","Avg Win","Avg Loss","Avg W/L Ratio"),
  c(tstats[,c("Avg.Trade.PL","Avg.Win.Trade","Avg.Losing.Trade",
    "Avg.WinLoss.Ratio")]))

trade.stats.tab <- data.frame(tab.trades,tab.profit,tab.wins)


## ----label=trade.stats.tab,echo=F,results='asis',cache=FALSE-------------
library(xtable)
print(xtable(trade.stats.tab, digits = c(0,0,2,0,2,0,2)),
  include.rownames = F,include.colnames=F, size="footnotesize")


## ------------------------------------------------------------------------
pts <- perTradeStats(Portfolio=b.strategy)

## ----PTSTATS1,echo=FALSE,cache=FALSE,fig.width=7,	fig.height=3-----------
gplots:::textplot(pts[,1:7],show.rownames=FALSE,halign="right")

## ----PTSTATS2,echo=FALSE,cache=FALSE,fig.width=12,	fig.height=4----------
pts[,8:15] <- round(pts[,8:15],4)
gplots:::textplot(pts[,8:15],,show.rownames=FALSE,halign="right")


## ----PERF2,cache=FALSE---------------------------------------------------
library(PerformanceAnalytics)
rets <- PortfReturns(Account=b.strategy)
rownames(rets) <- NULL
tail(rets)
charts.PerformanceSummary(rets,colorset = bluefocus)


## ------------------------------------------------------------------------
args(table.Arbitrary)


## ------------------------------------------------------------------------
tab.perf <- table.Arbitrary(rets,
  metrics=c(
    "Return.cumulative",
    "Return.annualized",
    "SharpeRatio.annualized",
    "CalmarRatio"),
  metricsNames=c(
    "Cumulative Return",
    "Annualized Return",
    "Annualized Sharpe Ratio",
    "Calmar Ratio"))
tab.perf


## ------------------------------------------------------------------------
tab.risk <- table.Arbitrary(rets,
  metrics=c(
    "StdDev.annualized",
    "maxDrawdown",
    "VaR",
    "ES"),
  metricsNames=c(
    "Annualized StdDev",
    "Max DrawDown",
    "Value-at-Risk",
    "Conditional VaR"))
tab.risk


## ------------------------------------------------------------------------
performance.stats.tab <- data.frame(
  rownames(tab.perf),tab.perf[,1],
  rownames(tab.risk),tab.risk[,1])

## ----label=performance.stats.tab,echo=F,results='asis'-------------------
print(xtable(performance.stats.tab, digits = c(0,0,3,0,3)),
  include.rownames = F,include.colnames=F, size="normalsize")


## ----results='hide'------------------------------------------------------
# remove objects to allow re-runs
suppressWarnings(try(rm(list=c("account.buyHold","portfolio.buyHold"),pos=.blotter),silent=TRUE))
# initialize portfolio and account
initPortf("buyHold", 'SPY', initDate=initDate)
initAcct("buyHold", portfolios="buyHold",
  initDate=initDate, initEq=initEq)
# place an entry order
CurrentDate <- time(getTxns(Portfolio=b.strategy, Symbol="SPY"))[2]
equity = getEndEq("buyHold", CurrentDate)
ClosePrice <- as.numeric(Cl(SPY[CurrentDate,]))
UnitSize = as.numeric(trunc(equity/ClosePrice))
addTxn("buyHold", Symbol='SPY', TxnDate=CurrentDate, TxnPrice=ClosePrice,
  TxnQty = UnitSize , TxnFees=0)
# place an exit order
LastDate <- last(time(SPY))
LastPrice <- as.numeric(Cl(SPY[LastDate,]))
addTxn("buyHold", Symbol='SPY', TxnDate=LastDate, TxnPrice=LastPrice,
  TxnQty = -UnitSize , TxnFees=0)
# update portfolio and account
updatePortf(Portfolio="buyHold")
updateAcct(name="buyHold")
updateEndEq(Account="buyHold")

## ----BUYANDHOLD,cache=FALSE----------------------------------------------
chart.Posn("buyHold", Symbol = 'SPY', Dates = '1998::',theme=myTheme)


## ----FABERBUYHOLDCOMP,cache=FALSE----------------------------------------
rets.bh <- PortfReturns(Account="buyHold")
returns <- cbind(rets,rets.bh)
colnames(returns) <- c("Faber","BuyHold")
returns["2011"]
charts.PerformanceSummary(returns, geometric=FALSE, wealth.index=TRUE)


## ----FBHRISKRETURN,cache=FALSE-------------------------------------------
table.AnnualizedReturns(returns)
chart.RiskReturnScatter(returns, Rf = 0, add.sharpe = c(1, 2), xlim=c(0,0.25),
  main = "Return versus Risk", colorset = c("red","blue"))


## ----FBHRELATIVE,cache=FALSE---------------------------------------------
table.Stats(returns)
chart.RelativePerformance(returns[,1],returns[,2],
  colorset = c("red","blue"), lwd = 2, legend.loc = "topleft")


## ------------------------------------------------------------------------
thePortfolio = getPortfolio(b.strategy)
names(thePortfolio)
names(thePortfolio$symbols)
names(thePortfolio$symbols$SPY)
names(thePortfolio$summary)


## ----echo=F--------------------------------------------------------------
options(width=105)

## ----size='tiny'---------------------------------------------------------
thePortfolio$symbols$SPY$txn[1:12,]

## ----echo=F--------------------------------------------------------------
options(width=81)


## ----BLOTPOSPL,cache=FALSE-----------------------------------------------
library(lattice)
xyplot(thePortfolio$symbols$SPY$posPL.USD,type="h",col=4)

## ----BLOTSUM,cache=FALSE-------------------------------------------------
xyplot(thePortfolio$summary,type="h",col=4)


## ------------------------------------------------------------------------
args(str)


## ----size='Tiny'---------------------------------------------------------
str(thePortfolio)


## ----ACCTSUM,cache=FALSE-------------------------------------------------
theAccount = getAccount(b.strategy)
names(theAccount)
names(theAccount$portfolios)
names(theAccount$portfolios$bFaber)
names(theAccount$summary)
xyplot(theAccount$summary)



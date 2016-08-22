
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
library(xtsExtra)

## ----results='hide'------------------------------------------------------
stock.st = c("USO")

currency("USD")
stock(stock.st, currency="USD",multiplier=1)
Sys.setenv(TZ="UTC")       # set time zone

initDate = '2006-12-31'
startDate = '2007-01-01'
endDate = '2013-12-31'
initEq=1e6
tradeSize = initEq/10

getSymbols(stock.st,from=startDate,to=endDate,index.class="POSIXct",adjust=T)


## ----USOPLOT,cache=FALSE-------------------------------------------------
myTheme<-chart_theme()
myTheme$col$dn.col <-'lightblue'
myTheme$col$dn.border <- 'lightgray'
myTheme$col$up.border <- 'lightgray'

chart_Series(get(stock.st),name=stock.st,theme=myTheme)


## ----results='hide'------------------------------------------------------
osFixedDollar <- function(timestamp, orderqty, portfolio, symbol, ruletype, ...)
{
  pos <- getPosQty(portfolio, symbol, timestamp)
  if( isTRUE(all.equal(pos,0)) )
  {
    ClosePrice <- as.numeric(Cl(mktdata[timestamp,]))
    orderqty <- sign(orderqty)*round(tradeSize/ClosePrice,-2)
  } else {
    orderqty <- 0
  }
  return(orderqty)
}


## ----results='hide'------------------------------------------------------
strat.st <- "bbands"

rm.strat(strat.st)

strategy(strat.st, store=TRUE)

add.indicator(strat.st, name = "BBands",
  arguments = list(HLC = quote(HLC(mktdata)), maType='SMA'), label='BBands')
	
add.signal(strat.st, name="sigCrossover",
  arguments=list(columns=c("Close","up"),relationship="gt"),
  label="Cl.gt.UpperBand")
	
add.signal(strat.st, name="sigCrossover",
  arguments=list(columns=c("Close","dn"),relationship="lt"),
  label="Cl.lt.LowerBand")
	
add.signal(strat.st, name="sigCrossover",
  arguments=list(columns=c("High","Low","mavg"),relationship="op"),
  label="Cross.Mid")


## ----results='hide'------------------------------------------------------
add.rule(strat.st, name='ruleSignal',
  arguments=list(sigcol="Cl.gt.UpperBand",sigval=TRUE, orderqty=-100,
    ordertype='market', orderside=NULL, threshold=NULL, osFUN=osFixedDollar,
    orderset='ocoshort'),
	type='enter',label="SE")
	
add.rule(strat.st, name='ruleSignal',
  arguments=list(sigcol="Cl.lt.LowerBand",sigval=TRUE, orderqty= 100,
    ordertype='market', orderside=NULL, threshold=NULL, osFUN=osFixedDollar,
    orderset='ocolong'),
  type='enter',label="LE")
	
add.rule(strat.st, name='ruleSignal',
  arguments=list(sigcol="Cross.Mid",sigval=TRUE, orderqty= 'all',
    ordertype='market', orderside=NULL, threshold=NULL),
  type='exit')


## ----results='hide'------------------------------------------------------
add.distribution(strat.st,
  paramset.label = 'BBOPT',
  component.type = 'indicator',
  component.label = 'BBands',
  variable = list(n = seq(10,30,by=5)),
  label = 'n'
)

add.distribution(strat.st,
  paramset.label = 'BBOPT',
  component.type = 'indicator',
  component.label = 'BBands',
  variable = list(sd = seq(1,3,by=0.5)),
  label = 'sd'
)


## ----echo=FALSE,results='hide'-------------------------------------------
library(quantstrat)

## ------------------------------------------------------------------------
args(walk.forward)


## ------------------------------------------------------------------------
if( Sys.info()['sysname'] == "Windows" )
{
  library(doParallel)
  # uncomment line below when combine function bug is fixed for Windows
  #registerDoParallel(cores=detectCores())
} else {
  library(doMC)
  registerDoMC(cores=detectCores())
}


## ----results='hide'------------------------------------------------------
rm.strat("opt")

initPortf(name="opt", stock.st, initDate=initDate)
initAcct(name="opt", portfolios="opt",
         initDate=initDate, initEq=initEq)
initOrders(portfolio="opt", initDate=initDate)

## ----echo=FALSE,results='hide'-------------------------------------------
if( !file.exists("saveEnvironment.RData") )
{
  results <- walk.forward(
    strategy.st=strat.st,
	  paramset.label='BBOPT',
	  portfolio.st="opt",
	  account.st="opt",
	  period='years',
	  k.training=4,
	  k.testing=1,
    nsamples=0,
	  audit.prefix='wfa',
	  anchored=FALSE,
	  verbose=TRUE
	)
  save(list=c("results",".strategy",".blotter"),file="saveEnvironment.RData")
} else {
  load("saveEnvironment.RData")
}

## ----eval=FALSE----------------------------------------------------------
## results <- walk.forward(
##   strategy.st=strat.st,
##   paramset.label='BBOPT',
##   portfolio.st="opt",
##   account.st="opt",
##   period='years',
##   k.training=4,
##   k.testing=1,
##   nsamples=0,
##   audit.prefix='wfa',
##   anchored=FALSE,
##   verbose=TRUE
## )


## ----eval=FALSE----------------------------------------------------------
## [1] "=== training BBOPT on 2007-01-03/2010-12-31"
## 
## [1] "=== testing param.combo 11 on 2011-01-03/2011-12-30"
##     n sd
## 11 10  2
## 
## 
## [1] "=== training BBOPT on 2008-01-02/2011-12-30"
## 
## [1] "=== testing param.combo 11 on 2012-01-03/2012-12-31"
##     n sd
## 11 10  2
## 
## 
## [1] "=== training BBOPT on 2009-01-02/2012-12-31"
## 
## [1] "=== testing param.combo 19 on 2013-01-02/2013-12-31"
##     n  sd
## 19 25 2.5


## ----TRADESTATS,results='hide'-------------------------------------------
PerformanceAnalytics:::textplot(t(tradeStats("opt")))


## ----TRANS1,results='hide',fig.width=8,fig.height=2----------------------
txns <- getTxns("opt",stock.st)
txns$Net.Txn.Realized.PL <- round(txns$Net.Txn.Realized.PL)
PerformanceAnalytics:::textplot(head(txns))

## ----TRANS2,results='hide',fig.width=8,fig.height=2----------------------
PerformanceAnalytics:::textplot(tail(txns))


## ----NETPL,cache=FALSE---------------------------------------------------
plot(getPortfolio("opt")$summary$Net.Trading.PL,minor.ticks=FALSE,type="h",col=4)


## ----CHARTPOSN,cache=FALSE-----------------------------------------------
chart.Posn("opt",stock.st)


## ----size='tiny'---------------------------------------------------------
names(results)
names(results[[1]])
results[[1]]$training.timespan
results[[1]]$testing.timespan
names(results[[1]]$apply.paramset)


## ------------------------------------------------------------------------
idx <- which.max(results[[1]]$apply.paramset$tradeStats$Net.Trading.PL)
results[[1]]$apply.paramset$tradeStats[idx,1:7]
idx <- which.max(results[[2]]$apply.paramset$tradeStats$Net.Trading.PL)
results[[2]]$apply.paramset$tradeStats[idx,1:7]
idx <- which.max(results[[3]]$apply.paramset$tradeStats$Net.Trading.PL)
results[[3]]$apply.paramset$tradeStats[idx,1:7]


## ----echo=FALSE----------------------------------------------------------
options(width=60)

## ------------------------------------------------------------------------
list.files(pattern="^wfa.*\\.RData$")

## ----echo=FALSE----------------------------------------------------------
options(width=79)


## ----eval=FALSE,size='tiny'----------------------------------------------
## > load("~/RProjects/UW/CFRM551/WFA/wfa.USO.2007-01-03.2010-12-31.RData")
## 
## > ls(all=TRUE)
## [1] ".audit"       ".blotter"     ".Random.seed" ".strategy"
## 
## > ls(.audit)
##  [1] "constraints"       "distributions"     "obj.func"          "order_book.opt.1"  "order_book.opt.10"
##  [6] "order_book.opt.11" "order_book.opt.12" "order_book.opt.13" "order_book.opt.14" "order_book.opt.15"
## [11] "order_book.opt.16" "order_book.opt.17" "order_book.opt.18" "order_book.opt.19" "order_book.opt.2"
## [16] "order_book.opt.20" "order_book.opt.21" "order_book.opt.22" "order_book.opt.23" "order_book.opt.24"
## [21] "order_book.opt.25" "order_book.opt.3"  "order_book.opt.4"  "order_book.opt.5"  "order_book.opt.6"
## [26] "order_book.opt.7"  "order_book.opt.8"  "order_book.opt.9"  "param.combo"       "param.combo.idx"
## [31] "param.combo.nr"    "param.combos"      "paramset.label"    "portfolio.opt.1"   "portfolio.opt.10"
## [36] "portfolio.opt.11"  "portfolio.opt.12"  "portfolio.opt.13"  "portfolio.opt.14"  "portfolio.opt.15"
## [41] "portfolio.opt.16"  "portfolio.opt.17"  "portfolio.opt.18"  "portfolio.opt.19"  "portfolio.opt.2"
## [46] "portfolio.opt.20"  "portfolio.opt.21"  "portfolio.opt.22"  "portfolio.opt.23"  "portfolio.opt.24"
## [51] "portfolio.opt.25"  "portfolio.opt.3"   "portfolio.opt.4"   "portfolio.opt.5"   "portfolio.opt.6"
## [56] "portfolio.opt.7"   "portfolio.opt.8"   "portfolio.opt.9"   "tradeStats"        "training.timespan"
## [61] "user.func"
## >


## ----eval=FALSE,size='tiny'----------------------------------------------
## > load("~/RProjects/UW/CFRM551/WFA/wfa.results.RData")
## 
## > ls(all=TRUE)
## [1] ".audit"       ".blotter"     ".Random.seed" ".strategy"
## 
## > ls(.audit)
##  [1] "account.opt"       "constraints"       "distributions"     "order_book.opt"    "order_book.opt.1"
##  [6] "order_book.opt.10" "order_book.opt.11" "order_book.opt.12" "order_book.opt.13" "order_book.opt.14"
## [11] "order_book.opt.15" "order_book.opt.16" "order_book.opt.17" "order_book.opt.18" "order_book.opt.19"
## [16] "order_book.opt.2"  "order_book.opt.20" "order_book.opt.21" "order_book.opt.22" "order_book.opt.23"
## [21] "order_book.opt.24" "order_book.opt.25" "order_book.opt.3"  "order_book.opt.4"  "order_book.opt.5"
## [26] "order_book.opt.6"  "order_book.opt.7"  "order_book.opt.8"  "order_book.opt.9"  "param.combos"
## [31] "paramset.label"    "portfolio.opt"     "portfolio.opt.1"   "portfolio.opt.10"  "portfolio.opt.11"
## [36] "portfolio.opt.12"  "portfolio.opt.13"  "portfolio.opt.14"  "portfolio.opt.15"  "portfolio.opt.16"
## [41] "portfolio.opt.17"  "portfolio.opt.18"  "portfolio.opt.19"  "portfolio.opt.2"   "portfolio.opt.20"
## [46] "portfolio.opt.21"  "portfolio.opt.22"  "portfolio.opt.23"  "portfolio.opt.24"  "portfolio.opt.25"
## [51] "portfolio.opt.3"   "portfolio.opt.4"   "portfolio.opt.5"   "portfolio.opt.6"   "portfolio.opt.7"
## [56] "portfolio.opt.8"   "portfolio.opt.9"   "tradeStats"        "user.func"
## >


## ----eval=FALSE----------------------------------------------------------
## chart.forward.training(audit.filename)
## chart.forward(audit.filename)


## ----TRAIN20072010-------------------------------------------------------
chart.forward.training("wfa.USO.2007-01-03.2010-12-31.RData")


## ----TRAIN20082011-------------------------------------------------------
chart.forward.training("wfa.USO.2008-01-02.2011-12-30.RData")


## ----TRAIN20092012-------------------------------------------------------
chart.forward.training("wfa.USO.2009-01-02.2012-12-31.RData")


## ----TESTOPT-------------------------------------------------------------
chart.forward("wfa.results.RData")



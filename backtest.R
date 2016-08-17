systematicRebalance <- function (...,
                                 ref.price.col=NULL,
                                 exchange.rate.col=NULL,
                                 instrument.volatility.col=NULL,
                                 instrument.forecast.col=NULL,
                                 instrument.weight.col=NULL,
                                 instrument.diversification.multiplier.col=NULL,
                                 initEq=NULL,
                                 volatility.target=NULL,
                                 minimum.order.size=NULL,
                                 minimum.position.change=NULL,
                                 portfolio,
                                 symbol,
                                 timestamp)
{
  print(tail(mktdata))
  date.subset <- paste0('::',timestamp)
  mktdata.row <- mktdata[timestamp,]
  ref.price <- as.numeric(mktdata.row[,ref.price.col])
  exchange.rate <- 1
  instrument.volatility <- as.numeric(mktdata.row[,instrument.volatility.col])
  instrument.forecast <- as.numeric(mktdata.row[,instrument.forecast.col])
  instrument.weight <- as.numeric(mktdata.row[,instrument.weight.col])
  instrument.diversification.multiplier <- as.numeric(mktdata.row[,instrument.diversification.multiplier.col])
  print(date.subset)
  Portfolio <- updatePortf(Portfolio=portfolio,
                            Dates=date.subset, env=.instrument)
  trading.pl <- sum(Portfolio$summary$Net.Trading.PL)#  * mktdata[date.subset, exchange.rate.col])
  
  s.ccy.str <- getInstrument(symbol)$currency
  
  if (!is.null(attr(Portfolio, "currency"))) {
    p.ccy.str <- attr(Portfolio, "currency")
  }
  psummary = Portfolio$summary[date.subset]
  if (s.ccy.str != p.ccy.str) {
    CcyMult <- NA
    port_currency <- try(getInstrument(p.ccy.str), silent = TRUE)
    if (inherits(port_currency, "try-error") | !is.instrument(port_currency)) {
      warning("Currency", p.ccy.str, " not found, using currency multiplier of 1")
      CcyMult <- 1
    }
    else {
      FXrate.str <- paste(p.ccy.str, s.ccy.str, sep = "")
      FXrate <- try(get(FXrate.str), silent = TRUE)
      invert = FALSE
      if (inherits(FXrate, "try-error")) {
        FXrate.str <- paste(s.ccy.str, p.ccy.str, 
                            sep = "")
        FXrate <- try(get(FXrate.str), silent = TRUE)
        if (inherits(FXrate, "try-error")) {
          warning("Exchange Rate", FXrate.str, " not found for symbol,',Symbol,' using currency multiplier of 1")
          CcyMult <- 1
        }
        else {
          invert = TRUE
        }
      }
    }
    if (is.na(CcyMult) && !is.na(FXrate)) {
      if (inherits(FXrate, "xts")) {
        CcyMult <- FXrate[date.subset]
        CcyMult <- na.locf(merge(CcyMult, index(psummary)))
        CcyMult <- drop(CcyMult[index(psummary)])
      }
      else {
        CcyMult <- as.numeric(FXrate)
      }
    }
    else {
      CcyMult <- 1
    }
    if (isTRUE(invert)) {
      CcyMult <- 1/CcyMult
    }
    exchange.rate <- as.numeric(CcyMult[timestamp])
  }
  
  print(exchange.rate)
  # updateAcct(account.name)
  # print(trading.pl)
  total.equity <- max(initEq + trading.pl,0)
  
  # print(paste0("calculated equity: ",total.equity))
  
  total.equity.inputs <- data.frame(initEq=initEq,
                                    trading.pl=trading.pl,
                                    exchange.rate=exchange.rate)
  # print(total.equity.inputs)
  # print(paste(timestamp, total.equity, sep=": "))
  # print(paste(timestamp, trading.pl * exchange.rate, sep=": "))
  # tradeSize <- total.equity * trade.percent
  # if(length(refprice)>1) refprice <- refprice[,1]
  # if(!is.null(refprice)) tradeSize <- tradeSize/refprice
  # if(!is.null(digits)) tradeSize<-round(tradeSize,digits)
  # subsystem.inputs <- data.frame(ref.price=ref.price,
  #                                total.equity=total.equity,
  #                                volatility.target=volatility.target,
  #                                exchange.rate=exchange.rate,
  #                                instrument.volatility=instrument.volatility,
  #                                instrument.forecast=instrument.forecast)
  # print(subsystem.inputs)
  
  
  subsystem.position <- subsystemPosition(ref.price=ref.price,
                                          total.equity=total.equity,
                                          volatility.target=volatility.target,
                                          exchange.rate=exchange.rate,
                                          instrument.volatility=instrument.volatility,
                                          instrument.forecast=instrument.forecast)
  
  # print(paste(timestamp, subsystem.position * ref.price, sep=": "))
  
  optimal.position <- subsystem.position * instrument.weight * instrument.diversification.multiplier
  
  current.position <- getPosQty(portfolio, symbol, timestamp)
  # print(paste(timestamp, current.position, sep=": "))
  
  transaction.size <- optimal.position - current.position
  transaction.size <- transaction.size * (abs(ref.price * transaction.size) > minimum.order.size)
  transaction.size <- transaction.size * (abs(transaction.size/current.position) > minimum.position.change)
  transaction.size <- ifelse(is.na(transaction.size), 0, transaction.size)
  
  position.calcs <- data.frame(subsystem.position=as.numeric(subsystem.position),
                               optimal.position=as.numeric(optimal.position),
                               transaction.size=as.numeric(transaction.size))
  # print(position.calcs)
  # print(paste0(timestamp,": wants ", round(subsystem.position,3),
  #              ", has ", round(current.position,3),
  #              ", transacting ", round(transaction.size,3)))
  
  if(transaction.size!=0){
    transaction.side <- ifelse(transaction.size>0,"long", "short")
    prefer.side <- ifelse(transaction.side=="long","high","low")
    
    addOrder(portfolio=portfolio, symbol=symbol, timestamp=timestamp,
             qty=transaction.size, price=ref.price, ordertype="market", side=transaction.side,
             threshold = NULL, orderset = "open.orders", status = "open",
             statustimestamp = "", prefer = prefer.side, delay = 60*5, tmult = FALSE,
             replace = TRUE, return = FALSE, ..., TxnFees = "percentFee",
             time.in.force = "GTC")
  }
}

xtsIdentity <- function(price.xts, to.merge){
  names(price.xts) <- NULL
  names(to.merge) <- NULL
  
  xts.identity <- merge(price.xts, to.merge)
  xts.identity[,"to.merge"] <- na.locf(xts.identity[,"to.merge"],na.rm = FALSE)
  xts.identity <- xts.identity[index(price.xts),"to.merge"]
  colnames(xts.identity) <- NULL
  return(xts.identity)
}

percentFee <- function(TxnQty, TxnPrice, Symbol, ...){
  return(-1*abs(0.0025 * TxnQty * TxnPrice)) # system.config$transaction.fee, need to add without throwing error
}

singleValue <- function(value=1, price.xts=NULL){
  xts.index <- index(price.xts)
  single.value <- xts(x=rep(value, length(xts.index)), order.by=xts.index)
  return(single.value)
}

adjustedForecast <- function(price.xts, forecast.name, ...){
  
  price.xts <- if (is.OHLC(price.xts)) {
    Cl(price.xts)
    }
  else price.xts
  
  if(forecast.name != "combinedForecast" && forecast.name != "fullSystem"){
    return(cappedScaledForecast(price.xts=price.xts, forecast.name=forecast.name))
  } else {
    return(combinedForecast(price.xts=price.xts))
  }
}

adjustedWeight <- function(forecast.name, instrument.name, price.xts, num.pairs=length(system.config$portfolio.pairs)){
  if(forecast.name == "fullSystem"){
    return(instrumentWeight(instrument.name=instrument.name, price.xts=price.xts))
  } else {
    return(singleValue(value=1/num.pairs, price.xts=price.xts))
  }
}

adjustedDiversificationMultiplier <- function(forecast.name, price.xts){
  if(forecast.name == "fullSystem"){
    return(instrumentDiversificationMultiplier(price.xts=price.xts))
  } else {
    return(singleValue(value=1, price.xts=price.xts))
  }
}

simulateBacktest <- function(pairs=NULL, forecast.name="combinedForecast"){
  # if(!is.null(dev.list())){dev.off(which=dev.list())}
  # .pardefault <- par(no.readonly = T)
  
  
  print(paste0("Simulating forecast returns for ",paste0(pairs, collapse = ", "),". Forecast: ",forecast.name))
  
  # if (!exists('.instrument')) 
  .instrument <- new.env(parent=.GlobalEnv)
  .blotter <- new.env(parent=.GlobalEnv)
  .strategy <- new.env(parent=.GlobalEnv)
  
  setSymbolLookup(BTC_BTS=list(src='custom', dir='data/raw'))
  setSymbolLookup(BTC_ETH=list(src='custom', dir='data/raw'))
  setSymbolLookup(USD_BTC=list(src='custom', dir='data/raw'))
  
  symbols <- getSymbols(Symbols = c(pairs, "USD_BTC"), env=.instrument, auto.assign = TRUE
                        ,verbose = TRUE, reload.Symbols = TRUE)
  
  # symbols <- alignSymbols(Symbols = symbols, env=.instrument)
  # currency(symbols)
  
  forecast.adjusted.name <- "adjustedForecast"
  weight.adjusted.name <- "adjustedWeight"
  diversification.multiplier.adjusted.name <- "adjustedDiversificationMultiplier"
  
  lookback.hours <- system.config$lookback.hours
  volatility.target <- system.config$volatility.target
  minimum.order.size <- system.config$minimum.order.size
  minimum.position.change <- system.config$minimum.position.change
  
  account.currency <- "USD"
  
  # symbols <- c()
  
  # for (pair in pairs){
  #   split.pair <- unlist(strsplit(pair, "_"))
  #   base <- split.pair[1]
  #   asset <- split.pair[2]
  #   
  #   e.rate <- paste0('USDT','_',base)
  #   
  #   trade.target.data <- getHourlyPairData(pair=pair, ohlc=TRUE, volume=TRUE)
  #   fx.rate.data <- getHourlyPairData(pair=e.rate, ohlc=FALSE, volume=FALSE)
  #   
  #   last.hour <- as.POSIXlt(index(tail(trade.target.data,1)))
  #   last.hour <- floor_date(min(c(last.hour, system.config$last.exchange.rate)), unit="hour")
  #   first.hour <- last.hour - hours(lookback.hours)#
  #   date.subset <- paste(first.hour,last.hour,sep="::")
  #   
  #   assign("trade.target", paste0(asset,base)
  #          , envir=parent.frame() #.GlobalEnv
  #   )
  #   assign("fx.rate",paste0(base, account.currency)
  #          , envir=parent.frame() #.GlobalEnv
  #   ) #paste0("USD",base)
  #   
  #   assign(trade.target, trade.target.data[date.subset]
  #          , envir=parent.frame() #.GlobalEnv
  #   ) # getHourlyPairData
  #   assign(fx.rate, fx.rate.data[date.subset]
  #          , envir=parent.frame() #.GlobalEnv
  #   ) #getHourlyPairData
  #   
  #   currency(c(base, asset, account.currency)) # ls_currencies()
  #   exchange_rate(trade.target, currency = base, counter_currency = asset, tick_size = 0.00001)
  #   exchange_rate(fx.rate, currency = account.currency, counter_currency = base, tick_size = 0.01)
  #   symbols <- c(symbols, trade.target)
  # }
  # 
  # initDate = as.character(as.Date(min(index(get(trade.target
  #                                               , envir=parent.frame() #.GlobalEnv
  # )))-days(1))) # '2015-09-01'
  initDate = "2014-05-21"
  initBTC <- .5
  init.target <- 0
  initUSD <- system.config$poloniex.margin.value * system.config$current.exchange.rate
  initEq <- initUSD
  
  portfolio.name <- "bitcoin_margin"
  account.name <- "poloniex"
  strategy.name <- "asset_allocation"
  
  ## To rerun
  rm.strat(portfolio.name)
  rm.strat(account.name)
  rm.strat(strategy.name)
  
  ## Initialize Portfolio, Account, and Orderbook initDate = initDate,
  initPortf(name = portfolio.name, symbols = symbols, initPosQty = init.target,  
            initDate = initDate,
            currency = account.currency)  # getPortfolio(portfolio.name)
  initAcct(name = account.name, portfolios = portfolio.name, initEq = initEq, 
           initDate = initDate,
           currency = account.currency)  # getAccount(account.name)
  initOrders(portfolio = portfolio.name, 
             initDate = initDate,
             symbols = symbols)  # getOrderBook(portfolio.name)
  strategy(strategy.name, store = TRUE)  # summary(getStrategy(strategy.name))
  
  
  add.indicator(strategy.name, name= "emaVolatility", arguments = list(price.xts=quote(Cl(mktdata))), label='instrument.volatility')
  add.indicator(strategy.name, name="adjustedForecast", arguments = list(forecast.name=forecast.name, price.xts=quote(Cl(mktdata))), label='instrument.forecast')
  # add.indicator(strategy.name, name="xtsIdentity", arguments = list(price.xts=quote(Cl(mktdata))
  #                                                                   ,to.merge=quote(Cl(get(fx.rate
  #                                                                                               , envir=parent.frame() #.GlobalEnv
  #                                                                   )))), label="exchange.rate")
  add.indicator(strategy.name, name= "adjustedWeight", arguments = list(forecast.name=forecast.name,
                                                                        instrument.name=pair, #trade.target,
                                                                        price.xts=quote(Cl(mktdata)),
                                                                        num.pairs <- length(pairs)),
                label='instrument.weight')
  add.indicator(strategy.name, name= "adjustedDiversificationMultiplier",
                arguments = list(forecast.name=forecast.name,
                                 price.xts=quote(Cl(mktdata))),
                label='instrument.diversification.multiplier')
  
  # assign("mktdata", applyIndicators(strategy.name, mktdata=get(trade.target
  #                                                              , envir=.GlobalEnv
  # ))
  # , envir=.GlobalEnv
  # )
  
  
  
  add.rule(strategy.name, 'systematicRebalance',
           arguments=list(rebalance_on='days',#'hours',
                          ref.price.col="close",
                          exchange.rate.col=NULL,
                          instrument.volatility.col="X1.instrument.volatility",
                          instrument.forecast.col="X1.instrument.forecast",
                          instrument.weight.col="X1.instrument.weight",
                          instrument.diversification.multiplier.col="X1.instrument.diversification.multiplier",
                          initEq=initEq,
                          volatility.target=volatility.target,
                          minimum.order.size=minimum.order.size,
                          minimum.position.change=minimum.position.change
           ),
           type='rebalance',
           label='rebalance')
  
  # add.rule(strategy.name, 'volatilityRebalance',
  #          arguments=list(rebalance_on='hours',
  #                         ref.price.col="close",
  #                         exchange.rate.col="X1.exchange.rate",
  #                         instrument.volatility.col="X1.instrument.volatility",
  #                         instrument.forecast.col="X1.instrument.forecast",
  #                         instrument.weight.col="X1.instrument.weight",
  #                         instrument.diversification.multiplier.col="X1.instrument.diversification.multiplier",
  #                         initEq=initEq,
  #                         volatility.target=volatility.target,
  #                         minimum.order.size=minimum.order.size,
  #                         minimum.position.change=minimum.position.change
  #          ),
  #          type='rebalance',
  #          label='rebalance')
  
  ## Run it
  applyStrategy.rebalancing(strategy=strategy.name,
                            portfolios=portfolio.name,
                            debug=T,
                            # mktdata=get("mktdata"
                            #             , envir=.GlobalEnv
                            # ),
                            parameters=list(),
                            verbose=system.config$debug#,
                            # env=.strategy #.GlobalEnv
  )
  
  updatePortf(Portfolio=portfolio.name,Dates=paste('::',as.Date(Sys.time()),sep=''))
  updateAcct(account.name)
  updateEndEq(account.name)
  
  ## Evaluate
  # t(tradeStats(portfolio.name, inclZeroDays = TRUE))
  txns <- getTxns(portfolio.name, Symbol = trade.target)
  # perTradeStats(portfolio.name, trade.target) # need to adapt for if no transactions are made
  
  specificForecast <- function(price.xts, forecast.name=get(forecast.name)){
    return(adjustedForecast(price.xts=price.xts, forecast.name=forecast.name))
  }
  #adjustedForecast
  #cappedScaledForecast
  
  if(sum(txns$Txn.Qty) != 0){
    pdf.name <- paste0("figures/final/",paste0(pairs, collapse = "_"),"_",forecast.name,"_ForecastSimulation.pdf")
    
    addForecast <- newTA(FUN=adjustedForecast, preFUN=closeOfXts, yrange=c(system.config$forecast.cap, - system.config$forecast.cap))
    
    pdf(pdf.name)
    chart.Posn(Portfolio=portfolio.name, type = "line", log.scale = F)
    # plot(addForecast())  # nFast = 60, nSlow = 180, nSig = 40, maType = 'EMA'
    
    # charts.TimeSeries()
    
    # par(.pardefault)
    p <- getPortfolio(portfolio.name)
    a <- getAccount(account.name)
    xyplot(a$summary,type="h",col=4)
    # par(.pardefault)
    equity <- a$summary$End.Eq
    plot(equity,main="Forecast Equity Curve")
    # par(.pardefault)
    ret <- na.omit(Return.calculate(equity))
    ret <- ret[is.finite(ret)]
    
    
    # chartSeries(x=trade.target.data, subset=date.subset, theme=chartTheme("wsj"),
    #             TA=paste('addForecast(forecast.name=',forecast.name,')', sep="'"))
    
    charts.PerformanceSummary(ret, colorset = bluefocus,
                              main=paste0(trade.target,"_",forecast.name," Forecast Performance"))
    dev.off()
  } else {
    print(paste0("No transactions made under ",pair,"_",forecast.name," simulation"))
  }
  
  # par(.pardefault)
  # try(slackr_upload(pdf.name, channels = "reports"))
  # plot(add_Vo())
  #   
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

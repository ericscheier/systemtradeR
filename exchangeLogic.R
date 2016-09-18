# returnOpenOrders(currency.pair="all")
# 
# # cancelAllOrders(account="exchange")
# 
# market.making.currency <- ""
# market.making.base <- "BTC"
# 
# complete.balances <- returnCompleteBalances(account="exchange")
# 
# buy(currency.pair=NULL, rate=NULL, amount=NULL, fillOrKill=0, immediateOrCancel=0, postOnly=1)
# 
# sell(currency.pair=NULL, rate=NULL, amount=NULL, fillOrKill=0, immediateOrCancel=0, postOnly=1)
# 
# moveOrder(orderNumber=NULL, rate=NULL, amount=NULL)
# 
# returnOrderBook(currencyPair="all", depth=10)
# 
# returnMarketTradeHistory(currencyPair, start.time, end.time)

testMarketMaking <- function(){
  start.time <- Sys.time()
  while(difftime(Sys.time(),start.time, units="min") < 120){
    result <- try(makeMarket())
    print(result)
    Sys.sleep(4*60+45)
  }
}

refreshAllExchange <- function(){
  trading.pairs <- system.config$portfolio.pairs
  adjustBaseExchange()
  determineOptimalAllocation.poloniex()
  determineCurrentAllocation.poloniex()
  lapply(trading.pairs, makeMarket)
}

makeMarket <- function(trading.pair="BTC_XMR", visible.depth=50){
  satoshi <- 10^-8
  default.exposure <- system.config$market.making.exposure.ratio
  asset <- pairToCurrencies(trading.pair)$asset
  base <- pairToCurrencies(trading.pair)$base
  
  optimal.accounts <- loadOptimalAccounts()
  current.accounts <- loadCurrentAccounts()
  current.btc.balances <- loadCurrentBTCAccounts()
  optimal.btc.balances <- loadOptimalBTCAccounts()
  
  optimal.accounts.row <- optimal.accounts[optimal.accounts$currency==asset,]
  current.accounts.row <- current.accounts[current.accounts$currency==asset,]
  relevant.cols <- c("exchange.equity","lending", "margin.collateral")
  
  asset.needed.in.account <- sum(optimal.accounts.row[,relevant.cols]) - sum(current.accounts.row[,relevant.cols])
  asset.needed.in.non.exchamge <- (
    optimal.accounts.row$lending + optimal.accounts.row$margin.collateral) - (
    current.accounts.row$lending + current.accounts.row$margin.collateral
  )
  
  if(asset.needed.in.account > 0){
    if(asset.needed.in.non.exchamge > 0){
      transferBalance(currency=asset, amount=min(current.accounts.row$exchange.equity, asset.needed.in.non.exchamge),
                      fromAccount="exchange", toAccount="lending")
    }
  }
  
  optimal.exchange.position <- optimal.accounts.row$exchange.equity
  
  current.btc.exchange.equity <- sum(current.btc.balances$exchange.equity[current.btc.balances$currency==base])
  optimal.btc.exchange.equity <- sum(optimal.btc.balances$exchange.equity[optimal.btc.balances$currency==base])
  position.scalar <- min(1, current.btc.exchange.equity/optimal.btc.exchange.equity)
  
  
  desired.asset <- optimal.exchange.position * position.scalar
  if(current.btc.exchange.equity==0){desired.asset <- 0}
    
  complete.balances <- ldply(returnCompleteBalances(account="exchange"), data.frame, stringsAsFactors=F, .id="currency")
  complete.balances[,c("available","onOrders","btcValue")] <- lapply(complete.balances[,c("available","onOrders","btcValue")], as.numeric)
  complete.balances <- as.data.table(complete.balances)
  current.asset <- complete.balances[currency==asset,available+onOrders]
  # current.asset <- Ntrunc(current.asset, prec=max(0,Ndec(current.asset)-1))
  position.change <- desired.asset - current.asset
  asset.bid.exposure <- max(0,position.change) #max(0,desired.asset * default.exposure + (position.change)) # intentionally doubling down on positoin changes
  asset.ask.exposure <- max(0,-position.change) #max(0,desired.asset * default.exposure - (position.change))
  
  # if(position.change > 0){asset.ask.exposure <- 0}
  # if(position.change < 0){asset.bid.exposure <- 0}
  
  if(asset.bid.exposure==0 && asset.ask.exposure==0){
    print(paste0("not making a market in ",trading.pair))
    return()
    }
  
  current.base <- complete.balances[currency==base,available+onOrders]
  print(paste0("Currently holding ",current.asset," ",asset,". Want: ",desired.asset))
  
  orders.per.side <- 1 #5
  market.making.config <- as.data.table(readRDS(relativePath("data/clean/market_making_config.RDS")))[pair==trading.pair,]
  
  # market.making.config <- list()
  # market.making.config$bid.min.quantile=.01
  # market.making.config$bid.max.quantile=.05
  # market.making.config$ask.min.quantile=.01
  # market.making.config$ask.max.quantile=.05
  
  order.book <- returnOrderBook(currencyPair=trading.pair, depth=visible.depth)
  
  asks <- ldply(order.book$asks, unlist)
  names(asks) <- c("rate", "amount")
  asks <- as.data.frame(apply(asks, 2, as.numeric))
  bids <- ldply(order.book$bids, unlist)
  names(bids) <- c("rate", "amount")
  bids <- as.data.frame(apply(bids, 2, as.numeric))
  
  middle <- round(mean(c(max(bids$rate), min(asks$rate))), -log10(satoshi))
  iv <- loadInvestmentUniverse()
  portfolio <- data.frame(asset=iv$asset, ref.price=iv$ref.price, stringsAsFactors = F)
  portfolio[portfolio$asset==trading.pair, "ref.price"] <- middle
  updateInvestmentUniverse(portfolio)
  # print(paste0("middle is ",middle))
  
  outstanding.orders <- ldply(returnOpenOrders(currency.pair=trading.pair), data.frame, stringsAsFactors=F)
  # print(nrow(outstanding.orders))
  if(nrow(outstanding.orders)>0){
    print("there are existing outstanding orders")
    outstanding.orders$rate <- as.numeric(outstanding.orders$rate)
    outstanding.orders$amount <- as.numeric(outstanding.orders$amount)
    # outstanding.orders <- outstanding.orders[,c("orderNumber","type","rate","amount")]
    outstanding.orders <- outstanding.orders[outstanding.orders$margin==0,c("orderNumber","type","rate","amount")]
  }
  
  inside.prices <- c(max(bids$rate), min(asks$rate))
  bid.if.buying <- min(inside.prices)
  ask.if.selling <- max(inside.prices)
  
  bid.range.max <- bids$rate[min(which(cumsum(bids$amount)>=quantile(cumsum(bids$amount), market.making.config$bid.min.quantile)))]
  bid.range.max <- ifelse(position.change>0, bid.if.buying, bid.range.max)
  bid.range.min <- bids$rate[min(which(cumsum(bids$amount)>=quantile(cumsum(bids$amount), market.making.config$bid.max.quantile)))]
  ask.range.min <- asks$rate[min(which(cumsum(asks$amount)>=quantile(cumsum(asks$amount), market.making.config$ask.min.quantile)))]
  ask.range.min <- ifelse(position.change<0, ask.if.selling, ask.range.min)
  ask.range.max <- asks$rate[min(which(cumsum(asks$amount)>=quantile(cumsum(asks$amount), market.making.config$ask.max.quantile)))]
  
  if(nrow(outstanding.orders)){
    outstanding.bids <- outstanding.orders[outstanding.orders$type=="buy",]
    if(nrow(outstanding.bids)){
      bids.to.move <- outstanding.bids[with(outstanding.bids, rate>bid.range.max |
                                              rate<bid.range.min),]
      bids.to.keep <- outstanding.bids[!(outstanding.bids$orderNumber %in% bids.to.move$orderNumber),]
      bids.to.cancel <- bids.to.keep[!(cumsum(bids.to.keep$amount)<asset.bid.exposure),]
      bids.to.keep <- bids.to.keep[!(bids.to.keep$orderNumber %in% bids.to.cancel$orderNumber),]
      current.bid.exposure <- sum(bids.to.keep$amount)
    } else {
      bids.to.move <- bids.to.keep <- bids.to.cancel <- data.frame()
      current.bid.exposure <- 0
    }
    
    outstanding.asks <- outstanding.orders[outstanding.orders$type=="sell",]
    if(nrow(outstanding.asks)){
      asks.to.move <- outstanding.asks[with(outstanding.asks, rate>ask.range.max |
                                              rate<ask.range.min),]
      asks.to.keep <- outstanding.asks[!(outstanding.asks$orderNumber %in% asks.to.move$orderNumber),]
      asks.to.cancel <- asks.to.keep[!(cumsum(asks.to.keep$amount)<asset.ask.exposure),]
      asks.to.keep <- asks.to.keep[!(asks.to.keep$orderNumber %in% asks.to.cancel$orderNumber),]
      current.ask.exposure <- sum(asks.to.keep$amount)
    } else {
      asks.to.move <- asks.to.keep <- asks.to.cancel <- data.frame()
      current.ask.exposure <- 0
    }
    
    orders.to.keep <- rbind(bids.to.keep, asks.to.keep)
    orders.to.move <- rbind(bids.to.move, asks.to.move)
    orders.to.cancel <- rbind(bids.to.cancel, asks.to.cancel)
    if(nrow(orders.to.cancel)){
      sapply(orders.to.cancel$orderNumber, cancelOrder)
    }
  } else {
    orders.to.move <- data.frame()
    current.bid.exposure <- current.ask.exposure <- 0
  }
  
  
  
  bids.to.make <- data.frame(rate=seq(from=bid.range.max,
                                      to=bid.range.min,
                                      length.out = orders.per.side),
                             amount = round(rep((asset.bid.exposure-current.bid.exposure)/orders.per.side, orders.per.side), -log10(satoshi)))
  
  asks.to.make <- data.frame(rate=seq(from=ask.range.min,
                                      to=ask.range.max,
                                      length.out = orders.per.side),
                             amount = round(rep((asset.ask.exposure-current.ask.exposure)/orders.per.side, orders.per.side), -log10(satoshi)))
  bids.to.make$type <- "buy"
  asks.to.make$type <- "sell"
  orders.to.make <- rbind(bids.to.make, asks.to.make)
  orders.to.make$orderNumber <- "new"
  
  if(nrow(orders.to.move)){
    for(row in 1:nrow(orders.to.move)){
      type <- orders.to.move[row,"type"]
      result <- try(orders.to.make[min(which(apply(cbind(orders.to.make$type==type, orders.to.make$orderNumber=="new"),1,all))),"orderNumber"] <- orders.to.move[row,"orderNumber"],
                    silent=TRUE)
      if(inherits(result, "try-error")){cancelOrder(order.number = outstanding.orders[row,"orderNumber"])}
    }
  }
  
  if(nrow(orders.to.make)>0){
    foreach(i=1:nrow(orders.to.make)) %do% {
      processMarketOrders(orders.to.make[i,], currency.pair=trading.pair)
    }
  }
  
  # orders.made <- apply(orders.to.make, 1, processMarketOrders, currency.pair=trading.pair)
  # orders.made <- ldply(orders.made, unlist)
  # print(paste0("Made ",nrow(orders.made)," new orders"))
  newly.outstanding.orders <- ldply(returnOpenOrders(currency.pair=trading.pair), data.frame, stringsAsFactors=F)
  # newly.outstanding.orders$rate <- as.numeric(newly.outstanding.orders$rate)
  # newly.outstanding.orders$amount <- as.numeric(newly.outstanding.orders$amount)
  return(newly.outstanding.orders)
}

processMarketOrders <- function(orders.to.make.row, currency.pair=NULL){
  rate <- orders.to.make.row[["rate"]]
  amount <- orders.to.make.row[["amount"]]
  if(as.numeric(amount)==0){
    print("not executing order of magnitude 0")
    return()
  }
  type <- orders.to.make.row[["type"]]
  order.id <- orders.to.make.row[["orderNumber"]]
  if(order.id=="new"){
    result <- try(do.call(get(type), args=list(currency.pair=currency.pair,
                                               rate=rate,
                                               amount=amount,
                                               fillOrKill=0, immediateOrCancel=0, postOnly=1)))
  } else {
    result <- try(do.call(moveOrder, args=list(orderNumber=order.id, rate=rate, amount=rate)))
    if(!is.null(result$error)){
      result <- try(do.call(get(type), args=list(currency.pair=currency.pair,
                                                 rate=rate,
                                                 amount=amount,
                                                 fillOrKill=0, immediateOrCancel=0, postOnly=1)))
    }
  }
  Sys.sleep(1/6)
  return(result)
}

adjustBaseExchange <- function(base.currency="BTC"){
  current.accounts <- loadCurrentAccounts()
  optimal.accounts <- loadOptimalAccounts()
  current.btc.balances <- loadCurrentBTCAccounts()
  optimal.btc.balances <- loadOptimalBTCAccounts()
  
  optimal.accounts.row <- optimal.accounts[optimal.accounts$currency==base.currency,]
  current.accounts.row <- current.accounts[current.accounts$currency==base.currency,]
  extra.in.exchange <- current.accounts.row$exchange.equity - optimal.accounts.row$exchange.equity
  if(extra.in.exchange > 0){
    transfer.result <- transferBalance(currency=asset, amount=extra.in.exchange,
                                       fromAccount="exchange", toAccount="lending")
    if(!is.null(transfer.result$error)){
      transfer.result <- transferBalance(currency=asset, amount=extra.in.exchange/2,
                                         fromAccount="exchange", toAccount="lending")
    }
  }
}

refreshMarketMakingQuantile <- function(tracking.pair="XMR_BCN"){
  marketMakingDataCapture(tracking.pair = tracking.pair)
  processMarketCaptureData(tracking.pair=tracking.pair)
}

refreshMarketMakingData <- function(){
  active.pairs <- system.config$portfolio.pairs
  pair.to.refresh <- active.pairs[round(runif(n=1, min=1, max=length(active.pairs)),0)]
  refreshMarketMakingQuantile(tracking.pair = pair.to.refresh)
}


marketMakingDataCapture <- function(tracking.pair = "BTC_ETH", sample.length=30, sample.depth=50){
  bids.frame <- data.frame("pull.time"=NA, "price"=NA, "volume"=NA, "order"=NA)
  asks.frame <- bids.frame
  start.time <- pull.time <- Sys.time()
  while(difftime(Sys.time(),start.time, units="min") < sample.length){
    print(difftime(Sys.time(),start.time, units="min"))
    end.time <- pull.time <- Sys.time()
    print(pull.time)
    order.book <- returnOrderBook(currencyPair=tracking.pair, depth=sample.depth)
    asks <- ldply(order.book$asks, unlist)
    names(asks) <- c("price", "volume")
    asks$pull.time <- pull.time
    asks$order <- rownames(asks)
    bids <- ldply(order.book$bids, unlist)
    names(bids) <- c("price", "volume")
    bids$pull.time <- pull.time
    bids$order <- rownames(bids)
    
    bids.frame <- rbind(bids.frame, bids)
    asks.frame <- rbind(asks.frame, asks)
    
    Sys.sleep(55)
  }
  trade.history <- returnMarketTradeHistory(currencyPair=tracking.pair, start.time=start.time, end.time=end.time)
  trade.history <- ldply(trade.history, data.frame, stringsAsFactors=F)
  bids.frame <- na.omit(bids.frame)
  asks.frame <- na.omit(asks.frame)
  bids.frame$type <- "bid"
  asks.frame$type <- "ask"
  full.order.book <- rbind(bids.frame, asks.frame)
  
  market.data <- list(full.order.book=full.order.book, trade.history=trade.history)
  saveRDS(market.data, file=relativePath(paste0("data/clean/market_data_",tracking.pair,".RDS")))
  return(market.data)
}


processMarketCaptureData <- function(tracking.pair="BTC_ETH"){
  market.data <- readRDS(relativePath(paste0("data/clean/market_data_",tracking.pair,".RDS")))
  trade.history <- market.data$trade.history
  order.book <- market.data$full.order.book
  
  trade.history$date <- as.POSIXct(trade.history$date)
  trade.history$rate <- as.numeric(trade.history$rate)
  trade.history$amount <- as.numeric(trade.history$amount)
  trade.history$total <- as.numeric(trade.history$total)
  
  order.book$pull.time <- as.POSIXct(order.book$pull.time, origin="1970-01-01")
  order.book$price <- as.numeric(order.book$price)
  order.book$volume <- as.numeric(order.book$volume)
  order.book$order <- as.numeric(order.book$order)
  
  order.book <- as.data.table(order.book)
  trade.history <- as.data.table(trade.history)
  
  # min(order.book$pull.time) <= min(trade.history$date)
  # 
  # max(order.book$pull.time)
  # max(trade.history$date)
  
  # trade <- trade.history[3,]
  trade.history$volume.quantile <- apply(trade.history, 1, determineVolumeQuantile, order.book=order.book)
  trade.history <- na.omit(trade.history)
  setorder(trade.history, volume.quantile)
  bid.history <- trade.history[type=="sell",]
  ask.history <- trade.history[type=="buy",]
  dust.percent.min <- 0.075 #5%
  dust.percent.max <- 1 - dust.percent.min
  bid.min.quantile <- bid.history$volume.quantile[min(which(cumsum(bid.history$total)>=quantile(cumsum(bid.history$total), dust.percent.min)))]
  bid.max.quantile <- bid.history$volume.quantile[min(which(cumsum(bid.history$total)>=quantile(cumsum(bid.history$total), dust.percent.max)))]
  
  ask.min.quantile <- ask.history$volume.quantile[min(which(cumsum(ask.history$total)>=quantile(cumsum(ask.history$total), dust.percent.min)))]
  ask.max.quantile <- ask.history$volume.quantile[min(which(cumsum(ask.history$total)>=quantile(cumsum(ask.history$total), dust.percent.max)))]
  
  market.making.config <- as.data.table(readRDS(relativePath("data/clean/market_making_config.RDS")))
  market.making.config[pair==tracking.pair,"bid.min.quantile"] <- bid.min.quantile
  market.making.config[pair==tracking.pair,"bid.max.quantile"] <- bid.max.quantile
  market.making.config[pair==tracking.pair,"ask.min.quantile"] <- ask.min.quantile
  market.making.config[pair==tracking.pair,"ask.max.quantile"] <- ask.max.quantile
  saveRDS(as.data.frame(market.making.config), file=relativePath("data/clean/market_making_config.RDS"))
  
}


determineVolumeQuantile <- function(trade, order.book){
  trade.price <- trade["rate"]
  
  order.book.dates <- unique(order.book$pull.time)
  applicable.order.book <- order.book[pull.time==order.book.dates[max(which(order.book.dates<=trade["date"]))],]
  if(trade["type"]=="buy"){
    applicable.order.book <- applicable.order.book[type=="ask",]
    setorder(applicable.order.book, order)
    order.index <- max(which(applicable.order.book$price<=trade.price))
    if(is.infinite(order.index)){
      volume.quantile <- NA
      order.index <- 0
    } else {
      volume.quantile <- cumsum(applicable.order.book$volume)[order.index]/sum(applicable.order.book$volume)
    }
  } else {
    applicable.order.book <- applicable.order.book[type=="bid",]
    setorder(applicable.order.book, order)
    order.index <- max(which(applicable.order.book$price>=trade.price))
    if(is.infinite(order.index)){
      volume.quantile <- NA
      order.index <- 0
    } else {
      volume.quantile <- cumsum(applicable.order.book$volume)[order.index]/sum(applicable.order.book$volume)
    }
  }
  return(volume.quantile)
}

initializeMarketMakingConfig <- function(){
  market.making.config <- data.frame(pair=system.config$portfolio.pairs,
                                     bid.min.quantile=.01,
                                     bid.max.quantile=.05,
                                     ask.min.quantile=.01,
                                     ask.max.quantile=.05)
  saveRDS(market.making.config, relativePath("data/clean/market_making_config.RDS"))
}

# market.data <- marketMakingDataCapture(sample.length = 30)

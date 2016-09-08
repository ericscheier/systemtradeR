
refreshAllMargin <- function(){
  trading.pairs <- system.config$portfolio.pairs
  determineOptimalAllocation.poloniex()
  determineCurrentAllocation.poloniex()
  lapply(trading.pairs, refreshMargin)
}


refreshMargin <- function(trading.pair=NULL, visible.depth=50){
  collateral.currency <-asset <- pairToCurrencies(trading.pair)$asset
  base <- pairToCurrencies(trading.pair)$base
  
  current.balances <- loadCurrentAccounts()
  optimal.balances <- loadOptimalAccounts()
  current.btc.balances <- loadCurrentBTCAccounts()
  optimal.btc.balances <- loadOptimalBTCAccounts()
  
  current.btc.margin.collateral <- sum(current.btc.balances$margin.collateral)
  optimal.btc.margin.collateral <- sum(optimal.btc.balances$margin.collateral)
  position.scalar <- min(1, current.btc.margin.collateral/optimal.btc.margin.collateral)
  
  current.margin.position <- current.balances$margin.position[current.balances$currency==collateral.currency]
  optimal.margin.position <- optimal.balances$margin.position[optimal.balances$currency==collateral.currency]
  
  desired.asset <- optimal.margin.position * position.scalar
  if(current.btc.margin.collateral==0){desired.asset <- 0}
  
  # complete.balances <- ldply(returnCompleteBalances(account="margin"), data.frame, stringsAsFactors=F, .id="currency")
  # complete.balances[,c("available","onOrders","btcValue")] <- lapply(complete.balances[,c("available","onOrders","btcValue")], as.numeric)
  # complete.balances <- as.data.table(complete.balances)
  current.asset <- as.numeric(getMarginPosition(currency.pair=trading.pair)$amount)   #complete.balances[currency==asset,available+onOrders]
  position.change <- desired.asset - current.asset
  asset.bid.exposure <- max(0,desired.asset  + (position.change)) # intentionally doubling down on positoin changes
  asset.ask.exposure <- max(0,desired.asset  - (position.change))
  
  if(asset.bid.exposure==0 && asset.ask.exposure==0){
    print(paste0("not making a market in ",trading.pair))
    return()
  }
  
  # current.base <- current.balances$margin.collateral[current.balances$currency==base]
  print(paste0("Currently holding ",current.asset," ",asset,". Want: ",desired.asset))
  
  orders.per.side <- 5
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
  
  middle <- round(mean(c(max(bids$rate), min(asks$rate))), -log10(system.config$satoshi))
  
  # print(paste0("middle is ",middle))
  
  outstanding.orders <- ldply(returnOpenOrders(currency.pair=trading.pair), data.frame, stringsAsFactors=F)
  if(nrow(outstanding.orders)){
    outstanding.orders$rate <- as.numeric(outstanding.orders$rate)
    outstanding.orders$amount <- as.numeric(outstanding.orders$amount)
    outstanding.orders <- outstanding.orders[outstanding.orders$margin,c("orderNumber","type","rate","amount")]
  }
  
  inside.prices <- c(max(bids$rate), min(asks$rate))
  bid.if.buying <- min(inside.prices)
  ask.if.selling <- max(inside.prices)
  
  bid.range.max <- bids$rate[min(which(cumsum(bids$amount)>=quantile(cumsum(bids$amount), market.making.config$bid.min.quantile)))]
  bid.range.max <- ifelse(position.change<0, bid.if.buying, bid.range.max)
  bid.range.min <- bids$rate[min(which(cumsum(bids$amount)>=quantile(cumsum(bids$amount), market.making.config$bid.max.quantile)))]
  ask.range.min <- asks$rate[min(which(cumsum(asks$amount)>=quantile(cumsum(asks$amount), market.making.config$ask.min.quantile)))]
  ask.range.min <- ifelse(position.change>0, ask.if.selling, ask.range.min)
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
                             amount = round(rep((asset.bid.exposure-current.bid.exposure)/orders.per.side, orders.per.side), -log10(system.config$satoshi)))
  
  asks.to.make <- data.frame(rate=seq(from=ask.range.max,
                                      to=ask.range.min,
                                      length.out = orders.per.side),
                             amount = round(rep((asset.ask.exposure-current.ask.exposure)/orders.per.side, orders.per.side), -log10(system.config$satoshi)))
  bids.to.make$type <- "marginBuy"
  asks.to.make$type <- "marginSell"
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
  orders.made <- apply(orders.to.make, 1, processMarginOrders, currency.pair=trading.pair)
  orders.made <- ldply(orders.made, unlist)
  print(paste0("Made ",nrow(orders.made)," new orders"))
  newly.outstanding.orders <- ldply(returnOpenOrders(currency.pair=trading.pair), data.frame, stringsAsFactors=F)
  newly.outstanding.orders$rate <- as.numeric(newly.outstanding.orders$rate)
  newly.outstanding.orders$amount <- as.numeric(newly.outstanding.orders$amount)
  # return(newly.outstanding.orders)
  
  current.collateral.balance <- current.balances$margin.collateral[current.balances$currency==collateral.currency]
  max.collateral.balance <- optimal.balances$margin.collateral[optimal.balances$currency==collateral.currency]
  
  if(current.collateral.balance > max.collateral.balance){
    transferBalance(currency=collateral.currency, amount=(current.collateral.balance - max.collateral.balance),
                    fromAccount="margin", toAccount="exchange")
  }
  
}

processMarginOrders <- function(orders.to.make.row, currency.pair=NULL){
  rate <- orders.to.make.row[["rate"]]
  amount <- orders.to.make.row[["amount"]]
  if(amount==0){
    return()
  }
  type <- orders.to.make.row[["type"]]
  order.id <- orders.to.make.row[["orderNumber"]]
  if(order.id=="new"){
    result <- try(do.call(get(type), args=list(currency.pair=currency.pair,
                                               rate=rate,
                                               amount=amount#,
                                               # fillOrKill=0, immediateOrCancel=0, postOnly=1
                                               )))
  } else {
    result <- try(do.call(moveOrder, args=list(orderNumber=order.id, rate=rate, amount=rate)))
    if(!is.null(result$error)){
      result <- try(do.call(get(type), args=list(currency.pair=currency.pair,
                                                 rate=rate,
                                                 amount=amount#,
                                                 # fillOrKill=0, immediateOrCancel=0, postOnly=1
                                                 )))
    }
  }
  Sys.sleep(1/6)
  return(result)
}
# pair <- "BTC_XMR"
# date.range <- "2016-07-02::2016-07-05"
# period <- "hours" # "seconds", "minutes", "hours", "days", "weeks", "months", "quarters", and "years"
# type <- "line"

allPriceChart <- function(date.range, period, type){
  
}

currencyAllocationChart <- function(){
  account.cols <- c("exchange.equity","lending","margin.collateral")
  
  current.btc.accounts <- loadCurrentBTCAccounts()
  optimal.btc.accounts <- loadOptimalBTCAccounts()
  
  current <- melt(current.btc.accounts, id.vars="currency", measure.vars=account.cols, variable.name="account")
  current$scenario <- "current"
  current$total.value <- sum(current$value)
  optimal <- melt(optimal.btc.accounts, id.vars="currency", measure.vars=account.cols, variable.name="account")
  optimal$scenario <- "optimal"
  optimal$total.value <- sum(optimal$value)
  
  accounts <- rbind(current, optimal)
  accounts <- accounts[with(accounts, order(currency, account, scenario)),]
  
  result.plot <- ggplot(accounts[order(accounts$currency),], aes(x=total.value/2, y=value, fill=currency, width=total.value)) + 
    geom_bar(position = "fill", stat="identity") + coord_polar(theta="y") + facet_wrap(~scenario) +
    theme_bw() + labs(title="Currency Allocations (BTC)", x="", y="") + theme(axis.text.x=element_blank(),
                                                                              axis.ticks.x=element_blank(),
                                                                              axis.text.y=element_blank(),
                                                                              axis.ticks.y=element_blank())
  
  return(result.plot)
}

accountAllocationChart <- function(scale.by.total.value=TRUE){
  account.cols <- c("exchange.equity","lending","margin.collateral")
  
  current.btc.accounts <- loadCurrentBTCAccounts()
  optimal.btc.accounts <- loadOptimalBTCAccounts()
  
  current <- melt(current.btc.accounts, id.vars="currency", measure.vars=account.cols, variable.name="account")
  current$scenario <- "current"
  total.values.current <- aggregate.data.frame(current$value, by=list(current$currency), sum)
  names(total.values.current) <- c("currency","total.value")
  
  
  optimal <- melt(optimal.btc.accounts, id.vars="currency", measure.vars=account.cols, variable.name="account")
  optimal$scenario <- "optimal"
  total.values.optimal <- aggregate.data.frame(optimal$value, by=list(optimal$currency), sum)
  names(total.values.optimal) <- c("currency","total.value")
  
  total.values.current$total.value <- total.values.current$total.value/
    total.values.optimal[match(total.values.current$currency,total.values.optimal$currency),
                         "total.value"]
  total.values.optimal$total.value <- total.values.optimal$total.value/total.values.optimal$total.value
  
  current <- merge(current, total.values.current)
  optimal <- merge(optimal, total.values.optimal)
  
  accounts <- rbind(current, optimal)
  accounts <- accounts[with(accounts, order(currency, account, scenario)),]
  if(!scale.by.total.value){
    accounts$total.value <- 1
  }
  
  accounts$total.value[is.na(accounts$total.value)] <- 0
  
  result.plot <- ggplot(accounts[order(accounts$currency),], aes(x=total.value/2, y=value, fill=account, width=total.value)) + 
    geom_bar(position = "fill", stat="identity") + coord_polar(theta="y") + facet_grid(scenario~currency) +
    theme_bw() + labs(title="Account Allocations (BTC)", x="", y="") + theme(axis.text.x=element_blank(),
                                                                             axis.ticks.x=element_blank(),
                                                                             axis.text.y=element_blank(),
                                                                             axis.ticks.y=element_blank())
  
  return(result.plot)
}


accountValueChart <- function(){
  account.value <- readRDS("data/clean/btc_account_value.RDS")
  account.value$btc_value <- account.value$btc_value/system.config$starting.capital
  
  result.plot <- ggplot(data=account.value, aes(x=date, y=btc_value)) + geom_line() + theme_bw() + 
    labs(title="Account Value", y="% of Initial Equity",x="Date")
  
  return(result.plot)
}

priceChart <- function(pair, date.range, period, type, overlay=FALSE){
  price.ohlc.xts <- getPairData(pair=pair, ohlc=TRUE, volume=TRUE, live=TRUE)
  price.ohlc.xts <- to.period(price.ohlc.xts, period=period)
  names(price.ohlc.xts) <- tolower(gsub("^.+\\.","",names(price.ohlc.xts)))  # remove "FOSL." from column names
  
  price.ohlc.xts <- price.ohlc.xts[date.range]
  price.ohlc <- data.frame(date=as.POSIXct(index(price.ohlc.xts)), price.ohlc.xts[,1:4])
  
  price.ohlc$chg <- ifelse(Cl(price.ohlc.xts) > Op(price.ohlc.xts), "up", "dn")
  price.ohlc$width <- as.numeric(periodicity(price.ohlc.xts)[1])
  price.ohlc$flat_bar <- price.ohlc[, "high"] == price.ohlc[, "low"]
  
  result.plot <- ggplot(price.ohlc, aes(x=date))
  
  # Bar chart: 
  if(type=="bar"){
    result.plot <- ggplot(data=price.ohlc, aes(x=date, colour = chg)) +
      geom_linerange(aes(ymin=low, ymax=high)) +
      geom_segment(aes(y = open, yend = open, xend = date - width / 2 )) +
      geom_segment(aes(y = close, yend = close, xend = date + width / 2)) +
      scale_colour_manual(values = c("dn" = "darkred", "up" = "darkgreen")) + guides(colour = FALSE)
  }
  if(type=="candle"){
    result.plot <- result.plot +
      geom_linerange(aes(ymin=low, ymax=high)) +
      geom_rect(aes(xmin = date - width/2 * 0.9, xmax = date + width/2 * 0.9,
                    ymin = pmin(open, close), ymax = pmax(open, close), fill = chg)) +
      guides(fill = FALSE, colour = FALSE) + scale_fill_manual(values = c("dn" = "darkred", "up" = "darkgreen"))
    
    # Handle special case of drawing a flat bar where OHLC = Open:
    if (any(price.ohlc$flat_bar)) result.plot <- result.plot +
        geom_segment(data = price.ohlc[price.ohlc$flat_bar,],
                     aes(x = date - width / 2 * 0.9, y = close, yend = close, xend = date + width / 2 * 0.9))
    
  }
  if(type=="line"){
    result.plot <- result.plot +
      geom_line(aes(x=date, y=close))
  }
  
  result.plot <- result.plot + theme_bw() +
    labs(title=pair, x="Date", y="Price")
  
  return(result.plot)
}

orderBookChart <- function(pair, market, overlay=FALSE){ #, depth
  if(market %in% c("exchange", "margin")){
    asset <- pair
    order.book <- loadOrderBook()[[pair]]
    asks <- ldply(order.book$asks, unlist)
    names(asks) <- c("rate", "amount")
    asks <- as.data.frame(apply(asks, 2, as.numeric))
    bids <- ldply(order.book$bids, unlist)
    names(bids) <- c("rate", "amount")
    bids <- as.data.frame(apply(bids, 2, as.numeric))
    
    bids$cum.amount <- cumsum(bids$amount)
    asks$cum.amount <- cumsum(asks$amount)
    
    bids$side <- "bid"
    asks$side <- "ask"
    depth.book <- rbind(bids, asks)
    
    # middle <- mean(c(max(bids$rate), min(asks$rate)))
  }
  if(market=="lending"){
    asset <- pairToCurrencies(pair)$asset
    lending.book <- loadLendingBook(currency=asset)
    
    open.offers <- ldply(lending.book$offers, data.frame, stringsAsFactors=F)
    # open.offers <- open.offers[open.offers$rangeMin<=max.length,]
    open.offers$amount <- as.numeric(open.offers$amount)
    open.offers$rate <- as.numeric(open.offers$rate)
    
    open.demands <- ldply(lending.book$demands, data.frame, stringsAsFactors=F)
    # open.demands <- open.demands[open.demands$rangeMin<=max.length,]
    open.demands$amount <- as.numeric(open.demands$amount)
    open.demands$rate <- as.numeric(open.demands$rate)
    
    asks <- open.offers
    bids <- open.demands
    
    bids$cum.amount <- cumsum(bids$amount)
    asks$cum.amount <- cumsum(asks$amount)
    
    bids$side <- "bid"
    asks$side <- "ask"
    depth.book <- rbind(bids, asks)
  }
  
  result.plot <- ggplot(data=depth.book, aes(x=rate, y=cum.amount)) +
    geom_area(aes(fill=side)) + scale_fill_manual(values = c("ask" = "darkred", "bid" = "darkgreen")) +
    guides(fill = FALSE) + theme_bw() +
    labs(title=paste(asset,market,sep=" "), x="Price", y=paste0(asset," Volume"))
  
  return(result.plot)
}

# pl <- priceChart(pair=pair, date.range=date.range, period=period, type=type)
# print(pl)
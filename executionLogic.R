cancelAllOrders <- function(account="margin"){
  print("Canceling all open orders")
  open.orders <- returnOpenOrders()
  for(pair in names(open.orders)){
    orders <- open.orders[[pair]]
    for(order in orders){
      order.number <- order$orderNumber
      if (!is.null(order.number)){
        result <- cancelOrder(order.number=order.number)
        print(result)
        Sys.sleep(0.2)
      }
    }
  }
}

tradesToMake <- function(){
  print("Determining trades to make")
  optimal.portfolio <- readRDS(file=paste0(getwd(), "/data/clean/optimal_portfolio.RDS"))
  current.portfolio <- readRDS(file=paste0(getwd(), "/data/clean/current_portfolio.RDS"))[names(optimal.portfolio)]
  # print(paste0("Optimal Portfolio: ", optimal.portfolio))
  # print(paste0("Current Portfolio: ", current.portfolio))
  
  portfolio.difference <- optimal.portfolio - current.portfolio
  transactions <- portfolio.difference * (abs(portfolio.difference/current.portfolio) > system.config$minimum.position.change)
  saveRDS(transactions, file=paste0(getwd(), "/data/clean/transactions_to_make.RDS"))
  return(transactions)
}

getMid <- function(ticker, pair){
  mid.point <- mean(c(as.numeric(ticker[[pair]]$highestBid),as.numeric(ticker[[pair]]$lowestAsk)))
  return(mid.point)
}

transactPair <- function(pair, transaction.size){
  # for margin trading only
  ticker <- returnTicker()
  mid.point <- getMid(ticker=ticker, pair=pair)
  # mid.point <- round(mid.point, -log10(system.config$minimum.order.size)) # need to change this rounding if min.order.size is not a factor of 10
  trade.result <- NULL
  if(abs(mid.point * transaction.size) < system.config$minimum.order.size){transaction.size <- 0}
  if(transaction.size>0){
    # buy
    trade.result <- marginBuy(currency.pair=pair, rate=mid.point, amount=transaction.size, lending.rate=0.02)
  }
  if(transaction.size<0){
    # sell
    trade.result <- marginSell(currency.pair=pair, rate=mid.point, amount=abs(transaction.size), lending.rate=0.02)
  }
  print(paste0(pair, ": ",transaction.size))
  return(trade.result)
}

makeTrades <- function(){
  transactions <- as.list(readRDS(file=paste0(getwd(), "/data/clean/transactions_to_make.RDS")))
  for (transaction in 1:length(transactions)){
    pair <- names(transactions[transaction])
    transact <- transactions[[transaction]]
    print(paste0("Transacting: ",transact," of ",pair))
    result <- transactPair(pair, transact)
    Sys.sleep(0.2)
  }
  return(transactions)
}
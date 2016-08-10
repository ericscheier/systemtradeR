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
  updateOpenOrders()
}

tradesToMake <- function(){
  print("Determining trades to make")
  investment.universe <- readRDS(file="data/clean/investment_universe.RDS")
  transactions <- data.frame(asset=investment.universe$asset,
                             to.make=with(investment.universe,
                                          (optimal.position - current.position) *
                                            (abs(optimal.position - current.position) >= abs(system.config$minimum.position.change * current.position)) *
                                            !is.locked)
  )
  
  transactions.to.make <- transactions[transactions$to.make!=0,]
  saveRDS(transactions.to.make, file="data/clean/transactions_to_make.RDS")
  return(transactions.to.make)
}

getMid <- function(ticker, pair){
  mid.point <- mean(c(as.numeric(ticker[[pair]]$highestBid),as.numeric(ticker[[pair]]$lowestAsk)))
  return(mid.point)
}


transactPair <- function(transactions.row){
  pair <- transactions.row["asset"]
  transaction.size <- transactions.row["to.make"]
  # for margin trading only
  ticker <- returnTicker()
  mid.point <- getMid(ticker=ticker, pair=pair)
  print(paste0("Transacting: ",transaction.size," of ",pair," at ",mid.point))
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
  Sys.sleep(0.2)
  return(trade.result)
}

makeTrades <- function(){
  transactions <- readRDS(file=paste0(getwd(), "/data/clean/transactions_to_make.RDS"))
  trades.made <- apply(transactions, 1, transactPair)
  return(trades.made)
}
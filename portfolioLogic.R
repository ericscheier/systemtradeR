accountValue <- function(){
  # leftover of attempts to use exchange account. Using margin instead
  # currencies <- gsub("BTC_*", "", filterPairs())
  # #API call to poloniex requesting value of margin account in BTC, as well as USDT_BTC price
  # balances <- returnCompleteBalances(account="exchange")
  # my.df <- do.call("rbind", lapply(balances, data.frame))
  # for (currency in names(balances)){
  #   
  # }
  # balances[c("available", "onOrders", "btcValue")]
  
  summary <- returnMarginAccountSummary()
  account.value <- as.numeric(summary$netValue)
  
  # account.value <- 0.1 # in BTC
  return(account.value)
}


calculateSubsystemPositions <- function(pairs=config$portfolio.pairs){
  # really need to speed this function up
  recordAccountValue()
  subsystem.positions <- list()
  for(pair in pairs){
    subsystem.positions[[pair]] <- productionSubsystemPosition(pair=pair)
  }
  subsystem.positions <- data.frame(subsystem.positions)
  # want to save these to an RDS every 5 minutes when running live
  return(subsystem.positions)
}

calculateOptimalPortfolio <- function(){
  print("Calculating the optimal portfolio")
  subsystem.positions <- calculateSubsystemPositions()
  instrument.weights <- as.data.frame(tail(readRDS(paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS")),1))[names(subsystem.positions)]
  instrument.diversification.multiplier <- instrumentDiversificationMultiplier()
  
  optimal.portfolio <- subsystem.positions * instrument.weights * instrument.diversification.multiplier
  saveRDS(optimal.portfolio, file=paste0(getwd(), "/data/clean/optimal_portfolio.RDS"))
  # return(portfolio)
}

calculateCurrentPortfolio <- function(){
  print("Calculating the current portfolio")
  balances <- getMarginPosition(currency.pair="all")
  current.portfolio <- data.frame(lapply(balances, function(x) as.numeric(x$amount)), stringsAsFactors = FALSE)
  saveRDS(current.portfolio, file=paste0(getwd(), "/data/clean/current_portfolio.RDS"))
  # return(current.portfolio)
}

refreshPortfolio <- function(){
  calculateOptimalPortfolio()
  calculateCurrentPortfolio()
}

filterPairs <- function(){
  # update universe of pairs I am interested in
  
  # right now only want BTC pairs with leverage available
  bases <- c("BTC")
  
  # volatility should be higher than benchmark
  volatility.benchmark <- 0.001
  volume.benchmark <- 100 #BTC/24 hours
  
  # if account size isn't big enough to support maximum position, exclude it
  
  portfolio.universe <- c("BTC_BTS", "BTC_CLAM", "BTC_DASH", "BTC_DOGE", "BTC_ETH", "BTC_FCT"
                          , "BTC_LTC", "BTC_MAID", "BTC_STR", "BTC_XMR", "BTC_XRP")
  
  portfolio.pairs <- portfolio.universe
  
  return(portfolio.pairs)
}

refreshPairs <- function(){
  portfolio.pairs <- filterPairs()
  
  saveRDS(portfolio.pairs, file=paste0(getwd(),"/data/clean/portfolio_pairs.RDS"))
}

getPairs <- function(){
  portfolio.pairs <- readRDS(file=paste0(getwd(),"/data/clean/portfolio_pairs.RDS"))
  return(portfolio.pairs)
}
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
    subsystem.positions[[pair]] <- subsystemPosition(pair=pair)
  }
  subsystem.positions <- data.frame(subsystem.positions)
  # want to save these to an RDS every 5 minutes when running live
  return(subsystem.positions)
}

calculateOptimalPortfolio <- function(){
  subsystem.positions <- calculateSubsystemPositions()
  instrument.weights <- as.data.frame(tail(readRDS(paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS")),1))[names(subsystem.positions)]
  instrument.diversification.multiplier <- instrumentDiversificationMultiplier()
  
  portfolio <- subsystem.positions * instrument.weights * instrument.diversification.multiplier
  return(portfolio)
}

calculateCurrentPortfolio <- function(){
  balances <- getMarginPosition(currency.pair="all")
  current.portfolio <- data.frame(lapply(balances, function(x) as.numeric(x$amount)), stringsAsFactors = FALSE)
  return(current.portfolio)
}
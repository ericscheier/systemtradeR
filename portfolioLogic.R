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




# truncated.hour.price.xts <- hour.price.xts[which(index(hour.price.xts) <= simulation.hour)]
# current.price <- as.numeric(tail(truncated.hour.price.xts,1))
# account.value <- exchange.rate * (position.size * current.price + account.cash)
# simulation.results[simulation.hour] <- account.value
# # print(account.value)
# combined.instrument.forecast <- combinedInstrumentForecast(ohlc.prices) # filter for simulation.hour
# cash.volatility.target <- cashVolatilityTarget(account.value, volatility.target)
# instrument.value.volatility <- instrumentValueVolatility(exchange.rate, truncated.hour.price.xts, minimum.order.size, volatility.lookback)
# volatility.scalar <- volatilityScalar(cash.volatility.target, instrument.value.volatility)
# subsystem.position <- subsystemPosition(volatility.scalar, combined.instrument.forecast)
# subsystem.position <- max(min(account.value, subsystem.position),0)
# # print(paste0("Postion of ",subsystem.position," in ",pair))
# subsystem.position.blocks <- (subsystem.position/exchange.rate)
# blocks.to.transact <- ifelse(abs((subsystem.position.blocks - position.size)/position.size)<(minimum.position.change),
#                              0, subsystem.position.blocks - position.size)
# blocks.to.transact <- ifelse(abs(blocks.to.transact) < minimum.order.size, 0, blocks.to.transact)
# 
# execution.price <- as.numeric(five.price.xts[(simulation.hour + minutes(10))])
# execution.exchange.rate <- as.numeric(five.exchange.rate[(simulation.hour + minutes(10))])
# blocks.transacted <- min(account.cash/execution.price, blocks.to.transact)
# 
# # if(blocks.transacted!=0){print(paste0("Transacted ",blocks.transacted," BTC worth of ",pair))}
# 
# position.size <- position.size + blocks.transacted * execution.price
# total.transaction.fee <- blocks.transacted * execution.price * transaction.fee
# account.cash <- account.cash - blocks.transacted * execution.price - total.transaction.fee
# post.execution.account.value <- execution.exchange.rate * (position.size * execution.price + account.cash)
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


calculateSubsystemPositions <- function(pairs=system.config$portfolio.pairs){
  # really need to speed this function up
  # recordAccountValue()
  portfolio <- data.frame(asset=pairs, stringsAsFactors = F)
  portfolio$subsystem.position <- apply(portfolio, 1, productionSubsystemPosition)
  # want to save these to an RDS every 5 minutes when running live
  return(portfolio)
}

calculateOptimalPortfolio <- function(){
  print("Calculating the optimal portfolio")
  portfolio <- calculateSubsystemPositions()
  iw <- tail(readRDS(relativePath("/data/clean/smoothed_instrument_weights.RDS")),1)
  instrument.weights <- data.frame(asset=portfolio$asset, instrument.weight=t(iw)[portfolio$asset,], row.names = NULL)
  instrument.diversification.multiplier <- instrumentDiversificationMultiplier()
  portfolio <- merge(portfolio, instrument.weights)
  
  portfolio$optimal.position <- with(portfolio, instrument.weight * subsystem.position * instrument.diversification.multiplier)
  investment.universe <- readRDS("data/clean/investment_universe.RDS")
  
  investment.universe$optimal.position[match(portfolio$asset, investment.universe$asset)] <- portfolio$optimal.position
  investment.universe$optimal.position[is.na(match(investment.universe$asset, portfolio$asset))] <- 0
  saveRDS(investment.universe, file="data/clean/investment_universe.RDS")
  return(investment.universe)
}

calculateCurrentPortfolio <- function(){
  print("Calculating the current portfolio")
  balances <- getMarginPosition(currency.pair="all")
  portfolio <- data.frame(asset=names(balances), stringsAsFactors = FALSE)
  portfolio$current.position <- apply(portfolio["asset"], 1, function(x) as.numeric(balances[[x]]$amount))
  
  investment.universe <- readRDS(relativePath("data/clean/investment_universe.RDS"))
  
  investment.universe$current.position[match(portfolio$asset, investment.universe$asset)] <- portfolio$current.position
  investment.universe$current.position[is.na(match(investment.universe$asset, portfolio$asset))] <- 0
  
  saveRDS(investment.universe, file=relativePath("data/clean/investment_universe.RDS"))
  return(investment.universe)
}

refreshPortfolio <- function(){
  calculateOptimalPortfolio()
  calculateCurrentPortfolio()
  
  investment.universe <- readRDS(relativePath("data/clean/investment_universe.RDS"))
  return(investment.universe[investment.universe$passes.filter,])
}

# maxPosition <- function(pair=NULL, account.value){
#   original.account.value <- system.config$poloniex.margin.value
#   system.config$poloniex.margin.value <- account.value
#   volatility.scalar <- volatilityScalar(pair=pair)
#   instrument.weight <- as.numeric(tail(readRDS(paste0(getwd(),"/data/clean/smoothed_instrument_weights.RDS")),1)[,pair])
#   instrument.diversification.multiplier <- instrumentDiversificationMultiplier()
#   max.position <- 1 * volatility.scalar * instrument.weight * instrument.diversification.multiplier
#   system.config$poloniex.margin.value <- original.account.value
#   price <- getExchangeRate(pair=pair)
#   btc.max.position <- max.position * price
#   return(btc.max.position)
# }
# 
# minAccountValue <- function(){
#   optFunc <- function(pair, X){
#     max.position <- maxPosition(pair=pair, account.value=X)
#     return(abs(max.position - 4*system.config$minimum.order.size))
#   }
#   optimFunc <- function(pair){
#     return(optimize(optFunc, pair=pair, interval=c(0,6), tol=0.1)$minimum)
#   }
#   min.account.values <- sapply(system.config$portfolio.pairs, optimFunc)
#   min.account.value <- max(min.account.values)
#   return(min.account.value)
# }

assetFilterRules <- function(investment.universe.row){
  asset <- investment.universe.row["asset"]
  # print(investment.universe.row)
  if(strsplit(asset, "_")[1] %in% c("XMR", "ETH", "USDT")){return(FALSE)}
  # print(investment.universe.row["is.restricted"])
  if(trimws(investment.universe.row["is.restricted"])){return(FALSE)}
  
  asset.data <- getPairData(pair=asset, ohlc = TRUE, volume = TRUE)
  asset.volatility <- as.numeric(tail(emaVolatility(Cl(asset.data)),1))
  asset.volume <- sum(as.numeric(tail(asset.data$volume, system.config$volatility.lookback*(60/5))))
  if(strsplit(asset, "_")[1]=="USDT"){asset.volume <- asset.volume/system.config$current.exchange.rate}
  
  # print(paste0(asset," volatility: ",asset.volatility, " volume: ",asset.volume))
  
  rule1 <- asset.volatility >= system.config$volatility.benchmark
  rule2 <- asset.volume >= system.config$volume.benchmark
  rules <- c(rule1, rule2)
  
  # print(rules)
  
  return(all(rules))
}

filterPairs <- function(){
  # update universe of pairs I am interested in
  
  # right now only want BTC pairs with leverage available
  investment.universe <- readRDS("data/clean/investment_universe.RDS")
  
  investment.universe$passes.filter <- apply(investment.universe, 1, assetFilterRules)
  saveRDS(investment.universe, "data/clean/investment_universe.RDS")
  return()
}

refreshPortfolioPairs <- function(){
  filterPairs()
  system.config$portfolio.pairs <- getPortfolioPairs()
  investment.universe <- readRDS("data/clean/investment_universe.RDS")
  return(investment.universe[!investment.universe$is.restricted,])
}

getPortfolioPairs <- function(){
  if(!file.exists("data/clean/investment_universe.RDS")){initializeInvestmentUniverse()}
  investment.universe <- readRDS("data/clean/investment_universe.RDS")
  portfolio.pairs <- investment.universe$asset[investment.universe$passes.filter]
  return(portfolio.pairs)
}

initializeInvestmentUniverse <- function(){
  
  initial.pairs <- c("BTC_BTS","BTC_CLAM","BTC_DASH","BTC_DOGE","BTC_ETH",
                     "BTC_FCT","BTC_LTC","BTC_MAID","BTC_STR","BTC_XMR","BTC_XRP")
  
  investment.universe <- data.frame(asset=initial.pairs, is.restricted=FALSE, passes.filter=TRUE,
                                    current.position=0,optimal.position=0, is.locked=FALSE,
                                    stringsAsFactors = FALSE)
  base.currency <- data.frame(asset="USDT_BTC", is.restricted=TRUE, passes.filter=FALSE, current.position=0,
                              optimal.position=0, is.locked=FALSE)
  investment.universe <- rbind(investment.universe, base.currency)
  
  saveRDS(investment.universe, file="data/clean/investment_universe.RDS")
}
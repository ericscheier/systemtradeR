simulateSubsystems <- function(){
  start.time <- Sys.time()
  portfolio.pairs <- config$portfolio.pairs
  
  
  results.matrix <- xts(x=NA, order.by=floor_date(config$last.exchange.rate,unit="hour"))
  
  for(pair in portfolio.pairs){
    simulation.results <- simulateSubsystem(pair=pair)
    
    results.matrix <- merge.xts(results.matrix, simulation.results)
  }
  
  results.matrix$results.matrix <- NULL
  colnames(results.matrix) <- portfolio.pairs
  subsystem.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
  
  
  saveRDS(subsystem.returns, file=paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
  execution.time <- round(difftime(Sys.time(), start.time, units="hours"),2)
  print(paste0("Finished simulating subsystem returns in ",execution.time," hours."))
}

simulateSubsystem <- function(pair=NULL){
  print(paste0("Simulating subsystem returns for ",pair))
  account.cash <- config$poloniex.margin.value #btc
  position.size <- 0 #pair in BTC base
  base <- unlist(strsplit(pair, "_"))[1]
  
  
  ohlc.prices <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE) # five minute frequency
  
  five.price.xts <- xts(x=ohlc.prices[,"close"]
                        , order.by = strptime(ohlc.prices[,"date"], format="%Y-%m-%d %H:%M:%S")
                        , tzone = "UTC")
  hour.price.xts <- to.hourly(five.price.xts, OHLC=FALSE, indexAt="endof")
  
  first.hour <- index(head(hour.price.xts,1))
  first.hour <- ceiling_date(max(first.hour, config$first.exchange.rate), unit="hour")
  trading.start.hour <- first.hour + hours(config$volatility.lookback)
  last.hour <- index(tail(hour.price.xts,1))
  last.hour <- floor_date(min(last.hour, config$last.exchange.rate), unit="hour")
  
  simulation.range <- seq.POSIXt(from=trading.start.hour, to=last.hour, by="hour")
  simulation.results <- xts(data.frame(account.value=rep(NA, length(simulation.range))), order.by=simulation.range)
  
  for(simulation.hour in as.list(simulation.range)){
    exchange.rate <- as.numeric(config$five.exchange.rate[simulation.hour])
    truncated.hour.price.xts <- hour.price.xts[which(index(hour.price.xts) <= simulation.hour)]
    truncated.five.minute.price.xts <- five.price.xts[which(index(five.price.xts) <= simulation.hour)]
    current.price <- as.numeric(tail(truncated.hour.price.xts,1))
    account.value <- exchange.rate * (position.size * current.price + account.cash)
    simulation.results[simulation.hour] <- account.value
    # print(account.value)
    subsystem.position <- subsystemPosition(pair=pair, five.minute.price.xts=truncated.five.minute.price.xts)
    # combined.instrument.forecast <- combinedInstrumentForecast(ohlc.prices) # filter for simulation.hour
    # cash.volatility.target <- cashVolatilityTarget(account.value, config$volatility.target)
    # instrument.value.volatility <- instrumentValueVolatility(exchange.rate, truncated.hour.price.xts)
    # volatility.scalar <- volatilityScalar(cash.volatility.target, instrument.value.volatility)
    # subsystem.position <- subsystemPosition(volatility.scalar, combined.instrument.forecast)
    # subsystem.position <- max(min(account.value, subsystem.position),0)
    # print(paste0("Postion of ",subsystem.position," in ",pair))
    portfolio.difference <- subsystem.position - position.size
    transaction.size <- portfolio.difference * (abs(portfolio.difference/position.size) > config$minimum.position.change)
    # subsystem.position.blocks <- (subsystem.position/exchange.rate)
    # blocks.to.transact <- ifelse(abs((subsystem.position.blocks - position.size)/position.size)<(minimum.position.change),
    #                              0, subsystem.position.blocks - position.size)
    # blocks.to.transact <- ifelse(abs(blocks.to.transact) < minimum.order.size, 0, blocks.to.transact)
    
    execution.price <- as.numeric(five.price.xts[(simulation.hour + minutes(10))])
    if(abs(execution.price * transaction.size) < config$minimum.order.size){transaction.size <- 0}
    execution.exchange.rate <- as.numeric(config$five.exchange.rate[(simulation.hour + minutes(10))])
    blocks.transacted <- min(account.cash/execution.price, transaction.size)
    
    # if(blocks.transacted!=0){print(paste0("Transacted ",blocks.transacted," BTC worth of ",pair))}
    
    position.size <- position.size + transaction.size * execution.price
    total.transaction.fee <- transaction.size * execution.price * config$transaction.fee
    account.cash <- account.cash - transaction.size * execution.price - total.transaction.fee
    post.execution.account.value <- execution.exchange.rate * (position.size * execution.price + account.cash)
    
    # print(paste0("Account value for ",pair,": $",account.value," [$",post.execution.account.value," after trading]"))
  }
  
  return(simulation.results)
}


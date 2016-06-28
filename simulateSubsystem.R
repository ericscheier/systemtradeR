portfolio.pairs <- filterPairs()

base = "BTC"

exchange.rate.prices <- read.csv(paste0(getwd(),"/data/raw/USDT_",base,"_ohlc.csv"), stringsAsFactors = FALSE) # instrument currency / account value currency (USD)

five.exchange.rate <- xts(x=exchange.rate.prices[,"close"]
                          , order.by = strptime(exchange.rate.prices[,"date"], format="%Y-%m-%d %H:%M:%S")
                          , tzone = "UTC")
# fix missing datapoint, caused by 0 volume in an interval above
# five.exchange.rate["2016-03-06 08:00:00",] <- mean(five.exchange.rate["2016-03-06 07:55:00",], five.exchange.rate["2016-03-06 08:05:00",])


first.exchange.rate <- index(head(five.exchange.rate,1))
last.exchange.rate <- index(tail(five.exchange.rate,1)) - minutes(10)

results.matrix <- xts(x=NA, order.by=floor_date(last.exchange.rate,unit="hour"))

# parallelize this
# registerDoParallel()
for(pair in portfolio.pairs){
  print(paste0("Simulating subsystem returns for ",pair))
  account.cash <- .1 #btc
  position.size <- 0 #pair in BTC base
  base <- unlist(strsplit(pair, "_"))[1]
  
  
  ohlc.prices <- read.csv(paste0(getwd(),"/data/raw/",pair,"_ohlc.csv"), stringsAsFactors = FALSE) # five minute frequency
  
  five.price.xts <- xts(x=ohlc.prices[,"close"]
                        , order.by = strptime(ohlc.prices[,"date"], format="%Y-%m-%d %H:%M:%S")
                        , tzone = "UTC")
  hour.price.xts <- to.hourly(five.price.xts, OHLC=FALSE, indexAt="endof")
  
  first.hour <- index(head(hour.price.xts,1))
  first.hour <- ceiling_date(max(first.hour, first.exchange.rate), unit="hour")
  trading.start.hour <- first.hour + hours(volatility.lookback)
  last.hour <- index(tail(hour.price.xts,1))
  last.hour <- floor_date(min(last.hour, last.exchange.rate), unit="hour")
  
  simulation.range <- seq.POSIXt(from=trading.start.hour, to=last.hour, by="hour")
  simulation.results <- xts(data.frame(account.value=rep(NA, length(simulation.range))), order.by=simulation.range)
  
  for(simulation.hour in as.list(simulation.range)){
    exchange.rate <- as.numeric(five.exchange.rate[simulation.hour])
    truncated.hour.price.xts <- hour.price.xts[which(index(hour.price.xts) <= simulation.hour)]
    current.price <- as.numeric(tail(truncated.hour.price.xts,1))
    account.value <- exchange.rate * (position.size * current.price + account.cash)
    simulation.results[simulation.hour] <- account.value
    # print(account.value)
    combined.instrument.forecast <- combinedInstrumentForecast(ohlc.prices) # filter for simulation.hour
    cash.volatility.target <- cashVolatilityTarget(account.value, volatility.target)
    instrument.value.volatility <- instrumentValueVolatility(exchange.rate, truncated.hour.price.xts, minimum.order.size, volatility.lookback)
    volatility.scalar <- volatilityScalar(cash.volatility.target, instrument.value.volatility)
    subsystem.position <- subsystemPosition(volatility.scalar, combined.instrument.forecast)
    subsystem.position <- max(min(account.value, subsystem.position),0)
    # print(paste0("Postion of ",subsystem.position," in ",pair))
    subsystem.position.blocks <- (subsystem.position/exchange.rate)
    blocks.to.transact <- ifelse(abs((subsystem.position.blocks - position.size)/position.size)<(minimum.position.change),
                                 0, subsystem.position.blocks - position.size)
    blocks.to.transact <- ifelse(abs(blocks.to.transact) < minimum.order.size, 0, blocks.to.transact)

    execution.price <- as.numeric(five.price.xts[(simulation.hour + minutes(10))])
    execution.exchange.rate <- as.numeric(five.exchange.rate[(simulation.hour + minutes(10))])
    blocks.transacted <- min(account.cash/execution.price, blocks.to.transact)
    
    # if(blocks.transacted!=0){print(paste0("Transacted ",blocks.transacted," BTC worth of ",pair))}
    
    position.size <- position.size + blocks.transacted * execution.price
    total.transaction.fee <- blocks.transacted * execution.price * transaction.fee
    account.cash <- account.cash - blocks.transacted * execution.price - total.transaction.fee
    post.execution.account.value <- execution.exchange.rate * (position.size * execution.price + account.cash)
    
    # print(paste0("Account value for ",pair,": $",account.value," [$",post.execution.account.value," after trading]"))
  }
  
  results.matrix <- merge.xts(results.matrix, simulation.results)
}

results.matrix$results.matrix <- NULL
colnames(results.matrix) <- portfolio.pairs
subsystem.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]


saveRDS(subsystem.returns, file=paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
charts.PerformanceSummary(subsystem.returns, main="Subsystem Backtested Performance")
charts.PerformanceSummary(na.omit(subsystem.returns), main="NA-Removed Subsystem Backetested Performance")


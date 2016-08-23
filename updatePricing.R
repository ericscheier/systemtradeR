# add more checks to make sure data isn't faulty
# random 0 found in five minute USDT_BTC data

# parallelize this
refreshPricing <- function(pairs){
  pairs <- c(pairs) #, "USDT_BTC"
  sapply(pairs, updatePricing)
  return()
}

refreshPortfolioPricing <- function(){
  portfolio.pairs <- getPortfolioPairs()
  refreshPricing(portfolio.pairs)
}

refreshAllPricing <- function(){
  investment.universe <- readRDS("data/clean/investment_universe.RDS")
  all.pairs <- investment.universe$asset[!investment.universe$is.restricted]
  refreshPricing(all.pairs)
}

updatePricing <- function(pair){
  investment.universe <- readRDS(relativePath("/data/clean/investment_universe.RDS"))
  pair.exchange <- investment.universe[investment.universe$asset==pair,"exchange"]
  
  print(paste0("Updating ",pair))
  file.name <- paste0(getwd(), "/data/raw/",pair,"_ohlc.csv")
  if(!file.exists(file.name)){
    initialized.data <- initializePricing(pair=pair, pair.exchange=pair.exchange)
    write.csv(x = initialized.data, file = file.name, row.names = FALSE)
  }
  existing.data <- read.csv(file.name, stringsAsFactors = FALSE)
  
  start.time <- tail(existing.data$date,1)
  # stop.seconds <- as.numeric(seconds(as.POSICct(end.time, origin = "1970-01-01"))))
  
  new.data <- getPrices(pair=pair, pair.exchange=pair.exchange, start.time=start.time, interval=5)
  new.data <- new.data[names(existing.data)]
  
  existing.data[nrow(existing.data),] <- new.data[1,]
  
  full.data <- rbind(existing.data, new.data[2:nrow(new.data),])
  
  actions <- NULL

  if(sum(is.na(full.data[,"volume"])) >= 1){
    
    full.data <- na.omit(full.data)
    replace <- TRUE
    actions <- c(actions, paste0("Going to remove NAs for pair: ",pair))
  }
  if(nrow(full.data[duplicated(full.data),]) >= 1){
    replace <- TRUE
    full.data <- unique(full.data)
    actions <- c(actions, paste0("Going to remove duplicate rows for pair:", pair))
  }
  
  write.csv(x = full.data, file = file.name, row.names = FALSE)
  print(paste0(pair," successfully updated"))
  
  return(paste0(pair," successfully updated"))
}

initializePricing <- function(pair, pair.exchange){
  print(paste0("Initializing ",pair))
  earliest.date <- "1992-04-25 07:40:00"
  
  if(pair=="USD_BTC"){
    pair.swap <- TRUE
    pair <- "USDT_BTC"
    pair.exchange <- "poloniex"
  }
  
  initialize.interval <- switch (pair.exchange,
    "poloniex" = 5,
    "kraken" = 24 * 60
  )
  
  initialized.data <- getPrices(pair=pair, pair.exchange=pair.exchange, start.time=earliest.date,
                                interval=initialize.interval)
  
  if(pair.swap){
    initialized.data$vwap <- NA
    initialized.data$count <- NA
    initialized.data$quoteVolume <- NULL
    initialized.data$weightedAverage <- NULL
  }
  
  return(initialized.data)
}

getPrices <- function(pair=NULL, pair.exchange=NULL, start.time=NULL, interval=NULL){
  web.prices <- do.call(paste0("getPairOHLC.",pair.exchange),
                        args=list(pair=pair, start.time=start.time, interval=interval))
  
  return(web.prices)
}

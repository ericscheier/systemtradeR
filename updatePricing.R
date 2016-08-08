# add more checks to make sure data isn't faulty
# random 0 found in five minute USDT_BTC data

# parallelize this
refreshPricing <- function(pairs){
  pairs <- c(pairs, "USDT_BTC")
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

getPoloniexPrices <- function(pair, start.time){
  start.seconds <- as.numeric(seconds(as.POSIXct(start.time, origin = "1970-01-01")))
  new.data.raw <- content(GET(paste0("https://poloniex.com/public?command=returnChartData&currencyPair=",pair,"&start=",start.seconds,"&end=9999999999&period=300")))  # https://poloniex.com/support/api/
  new.data <- ldply(new.data.raw, data.frame)
  new.data$date <- as.character(as.POSIXct(new.data$date, origin = "1970-01-01"))
  return(new.data)
}

updatePricing <- function(pair)
  {
  print(paste0("Updating ",pair))
  file.name <- paste0(getwd(), "/data/raw/",pair,"_ohlc.csv")
  if(!file.exists(file.name)){
    print(paste0("Initializing ",pair))
    earliest.date <- "1992-04-25 07:40:00"
    initialized.data <- getPoloniexPrices(pair=pair, start.time=earliest.date)
    write.csv(x = initialized.data, file = file.name, row.names = FALSE)
  }
  existing.data <- read.csv(file.name, stringsAsFactors = FALSE)
  
  start.time <- tail(existing.data$date,1)
  # stop.seconds <- as.numeric(seconds(as.POSICct(end.time, origin = "1970-01-01"))))
  
  new.data <- getPoloniexPrices(pair=pair, start.time=start.time)
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

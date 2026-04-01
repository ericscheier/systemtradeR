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
  
  new.data <- getPrices(pair=pair, pair.exchange=pair.exchange, start.time=start.time, interval=1)
  new.data <- new.data[names(existing.data)]
  
  existing.data[nrow(existing.data),] <- new.data[1,]
  
  full.data <- rbind(existing.data, new.data[2:nrow(new.data),])
  
  actions <- NULL
  if(sum(is.na(full.data[,"date"])) >= 1){
    
    full.data <- na.omit(full.data)
    replace <- TRUE
    actions <- c(actions, paste0("Going to remove NAs for date in pair: ",pair))
  }
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
  
  # pair.swap <- FALSE
  # if(pair=="USD_BTC"){
  #   pair.swap <- TRUE
  #   pair <- "USDT_BTC"
  #   pair.exchange <- "poloniex"
  # }
  
  # initialize.interval <- switch (pair.exchange,
  #   "poloniex" = 5,
  #   "kraken" = 5 #24 * 60
  # )
  initialize.interval <- 60
  
  initialized.data <- getPrices(pair=pair, pair.exchange=pair.exchange, start.time=earliest.date,
                                interval=initialize.interval)
  
  # if(pair.swap){
  #   initialized.data$vwap <- NA
  #   initialized.data$count <- NA
  #   initialized.data$quoteVolume <- NULL
  #   initialized.data$weightedAverage <- NULL
  # }
  
  return(initialized.data)
}

getPrices <- function(pair=NULL, pair.exchange=NULL, start.time=NULL, interval=NULL){
  print(paste0("pair exchange test ",pair.exchange))
  web.prices <- do.call(paste0("getPairOHLC.",pair.exchange),
                        args=list(pair=pair, start.time=start.time, interval=interval))
  
  return(web.prices)
}

getPoloniexPrices <- function(pair, start.time){
  start.seconds <- as.numeric(seconds(as.POSIXct(start.time, origin = "1970-01-01")))
  new.data.raw <- content(GET(paste0("https://poloniex.com/public?command=returnChartData&currencyPair=",pair,"&start=",start.seconds,"&end=9999999999&period=300")))  # https://poloniex.com/support/api/
  new.data <- ldply(new.data.raw, data.frame)
  new.data$date <- as.character(as.POSIXct(new.data$date, origin = "1970-01-01"))
  return(new.data)
}

library(httr)
library(plyr)

getPairOHLC.kraken <- function(pair, start.time, interval) {
  # Convert start time to Unix timestamp
  start.seconds <- as.numeric(as.POSIXct(start.time, origin = "1970-01-01"))
  
  # Convert the interval to Kraken's format (interval is in minutes)
  interval_map <- list(
    "1" = 1, "5" = 5, "15" = 15, "30" = 30, "60" = 60, "240" = 240, "1440" = 1440, "10080" = 10080, "21600" = 21600
  )
  interval_kraken <- interval_map[[as.character(interval)]]
  
  pair_kraken <- translateToKrakenNotation(pair)
  
  # Define Kraken's OHLC endpoint
  base_url <- "https://api.kraken.com/0/public/OHLC"
  
  # Make the API request
  response <- GET(base_url, query = list(pair = pair_kraken, since = start.seconds, interval = interval_kraken))
  response_content <- content(response, as = "parsed", simplifyVector = TRUE)
  
  # Print the entire response for debugging
  # print("Full API response:")
  # print(response_content)
  
  # Check for errors in the response
  if (!is.null(response_content$error) && length(response_content$error) > 0) {
    stop("Error fetching data: ", paste(response_content$error, collapse = ", "))
  }
  
  # Extract the OHLC data
  ohlc_data_raw <- response_content$result[[pair_kraken]]
  
  # Print the structure of the raw data for debugging
  # print("Raw OHLC data:")
  # print(str(ohlc_data_raw))
  
  # Convert the raw data to a data frame
  # ohlc_data <- do.call(rbind, lapply(ohlc_data_raw, as.numeric))
  ohlc_data <- as.data.frame(ohlc_data_raw)
  colnames(ohlc_data) <- c("date", "open", "high", "low", "close", "vwap", "volume", "count")
  
  # Convert time to a human-readable format
  ohlc_data$date <- as.character(as.POSIXct(as.numeric(ohlc_data$date), origin = "1970-01-01", tz = "UTC"))
  
  return(ohlc_data)
}

library(jsonlite)

getKrakenPairs <- function() {
  # Define Kraken's asset pairs endpoint
  base_url <- "https://api.kraken.com/0/public/AssetPairs"
  
  # Make the API request
  response <- GET(base_url)
  response_content <- content(response, as = "text", encoding = "UTF-8")
  response_json <- fromJSON(response_content)
  
  # Check for errors in the response
  if (length(response_json$error) == 0) {
    # Extract the asset pairs
    asset_pairs <- names(response_json$result)
    
    return(asset_pairs)
  } else {
    stop("Error fetching asset pairs: ", paste(response_json$error, collapse = ", "))
  }
}


translateToKrakenNotation <- function(pair) {
  # Define a mapping of common currencies to Kraken's notation
  currency_map <- list(
    BTC = "XXBT",
    ETH = "XETH",
    LTC = "XLTC",
    XRP = "XXRP",
    BCH = "BCH",
    ADA = "ADA",
    USDC = "USDC",
    USD = "ZUSD",
    EUR = "ZEUR",
    JPY = "ZJPY",
    GBP = "ZGBP",
    CAD = "ZCAD",
    CHF = "ZCHF"
  )
  
  # Split the input pair
  currencies <- strsplit(pair, "_")[[1]]
  
  if (length(currencies) != 2) {
    stop("Invalid pair format. It should be in the format 'currency-x_currency-y'.")
  }
  
  # Translate each currency
  currency_x <- currency_map[[currencies[1]]]
  currency_y <- currency_map[[currencies[2]]]
  
  if (is.null(currency_x) || is.null(currency_y)) {
    stop("One or both currencies are not recognized.")
  }
  
  # Combine the translated currencies into Kraken's notation
  kraken_pair <- paste0(currency_x, currency_y)
  return(kraken_pair)
}

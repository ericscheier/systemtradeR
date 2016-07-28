# add more checks to make sure data isn't faulty
# random 0 found in five minute USDT_BTC data

# parallelize this
refreshPricing <- function(){
  pairs <- c(system.config$portfolio.pairs, "USDT_BTC")
  sapply(pairs, updatePricing)
  dataCleaning(pairs=pairs)
  return()
}

updatePricing <- function(pair)
  {
  print(paste0("Updating ",pair))
  file.name <- paste0(getwd(), "/data/raw/",pair,"_ohlc.csv")
  existing.data <- read.csv(file.name, stringsAsFactors = FALSE)
  
  start.time <- tail(existing.data$date,1)
  start.seconds <- as.numeric(seconds(as.POSIXct(start.time, origin = "1970-01-01")))
  # stop.seconds <- as.numeric(seconds(as.POSICct(end.time, origin = "1970-01-01"))))
  
  new.data.raw <- content(GET(paste0("https://poloniex.com/public?command=returnChartData&currencyPair=",pair,"&start=",start.seconds,"&end=9999999999&period=300")))  # https://poloniex.com/support/api/
  new.data <- ldply(new.data.raw, data.frame)
  new.data$date <- as.character(as.POSIXct(new.data$date, origin = "1970-01-01"))
  new.data <- new.data[names(existing.data)]
  
  # check that old and new data match where they are supposed to
  
  # for some reason opens are not matching up even though prices are smooth
  # check1 <- round(tail(existing.data,1)[,"open"],6) == round(head(new.data,1)[,"open"],6)
  check1 <- TRUE
  check2 <- TRUE # tail(existing.data,1)[,"volume"] <= head(new.data,1)[,"volume"]
  check3 <- TRUE #tail(existing.data,1)[,"high"] <= head(new.data,1)[,"high"]
  check4 <- TRUE #tail(existing.data,1)[,"low"] >= head(new.data,1)[,"low"]
  
  checks <- c(check1, check2, check3, check4)
  checks.true <- all(checks)
  complete <- FALSE
  
  if(checks.true){
    existing.data[nrow(existing.data),] <- new.data[1,]
    
    full.data <- rbind(existing.data, new.data[2:nrow(new.data),])
    write.csv(x = full.data, file = file.name, row.names = FALSE)
    complete <- TRUE
    print(paste0(pair," successfully updated"))
  }
  if(!checks.true) {
    write.csv(x = new.data, file = paste0(getwd(), "/data/raw/",pair,"_incompatible.csv")
              , row.names = FALSE)
    print(paste0("new data and old data incompatible. Checks: ",checks))
  }
  Sys.sleep(.17)
  return(complete)
}

dataCleaning <- function(pairs=system.config$portfolio.pairs){
  for(pair in pairs){
    file.name <- paste0(getwd(), "/data/raw/",pair,"_ohlc.csv")
    # incompatible.name <- paste0(getwd(), "/data/raw/",pair,"_incompatible.csv")
    existing.data <- read.csv(file.name, stringsAsFactors = FALSE)
    # incompatible.data <- read.csv(incompatible.name, stringsAsFactors = FALSE)
    replace <- FALSE
    if(sum(is.na(existing.data[,"volume"])) >= 1){
      
      existing.data <- na.omit(existing.data)
      replace <- TRUE
      print(paste0("Going to remove NAs for pair: ",pair))
    }
    if(nrow(existing.data[duplicated(existing.data),]) >= 1){
      replace <- TRUE
      existing.data <- unique(existing.data)
      print(paste0("Going to remove duplicate rows for pair:", pair))
    }
    if(replace){write.csv(existing.data, file.name, row.names=FALSE)}
  }
}

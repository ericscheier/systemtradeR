# recordAccountValue <- function()
# {
#   config$poloniex.margin.value <- accountValue()
#   new.data <- data.frame(date=Sys.time(), account.value=config$poloniex.margin.value)
#   
#   file.name <- paste0(getwd(), "/data/clean/account_value.RDS")
#   old.data <- readRDS(file=file.name)
#   combo.data <- rbind(old.data, new.data)
#   saveRDS(combo.data, file=file.name)
#   return(config$poloniex.margin.value)
# }

appendNewData <- function(file.name=NULL, new.data=NULL){
  
  file.name <- paste0(getwd(), "/data/clean/",file.name,".RDS")
  old.data <- try(readRDS(file=file.name))
  if(inherits(old.data, "try-error")){old.data <- NULL}
  combo.data <- rbind(old.data, new.data)
  saveRDS(combo.data, file=file.name)
}

recordAccountValue <- function(){
  config$poloniex.margin.value <- accountValue()
  Sys.sleep(.15)
  usdt.exchange.rate <- getMid(ticker=returnTicker(), pair="USDT_BTC")
  current.time <- Sys.time()
  usdt.value <- config$poloniex.margin.value * usdt.exchange.rate
  new.data <- data.frame(date=current.time, usdt_value=usdt.value, btc_value=config$poloniex.margin.value)
  
  appendNewData(file.name="margin_account_value", new.data=new.data)
  # print(new.data)
  return(new.data)
}

timeDifferences <- function(last.updated, current.time){
  difftime(current.time, last.updated, units="mins")
}

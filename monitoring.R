# recordAccountValue <- function()
# {
#   system.config$poloniex.margin.value <- accountValue()
#   new.data <- data.frame(date=Sys.time(), account.value=system.config$poloniex.margin.value)
#   
#   file.name <- paste0(getwd(), "/data/clean/account_value.RDS")
#   old.data <- readRDS(file=file.name)
#   combo.data <- rbind(old.data, new.data)
#   saveRDS(combo.data, file=file.name)
#   return(system.config$poloniex.margin.value)
# }

generateReports <- function(){
  # file.time <- Sys.time()
  # pdf.name <- paste0("figures/final/send/MergedPDFs_",file.time,".pdf")
  # 
  # plotflow:::mergePDF(
  #   in.file=relativePath("/figures/final/reports"),
  #   file=relativePath(pdf.name)
  # )
  
  # clear reports folder
}

sendReports <- function(){
  # list the files in the send folder
  # for each try to send and move to backup if successful
  # try.to.send <- try(slackr_upload(pdf.name, channels = "reports"))
  #move to backups folder
}

appendNewData <- function(file.name=NULL, new.data=NULL){
  
  file.name <- paste0(getwd(), "/data/clean/",file.name,".RDS")
  old.data <- try(readRDS(file=file.name))
  if(inherits(old.data, "try-error")){old.data <- NULL}
  combo.data <- rbind(old.data, new.data)
  saveRDS(combo.data, file=file.name)
}

recordAccountValue <- function(){
  system.config$account.value <- accountValue()
  # Sys.sleep(.15)
  # usdt.exchange.rate <- getMid(ticker=returnTicker(), pair="USDT_BTC")
  current.time <- Sys.time()
  # usdt.value <- system.config$poloniex.margin.value * usdt.exchange.rate
  new.data <- data.frame(date=current.time, btc_value=system.config$account.value)
  
  appendNewData(file.name="btc_account_value", new.data=new.data)
  # checkAccountValueLog()
  updateHighWaterMark()
  # print(new.data)
  return(new.data)
}

updateHighWaterMark <- function(){
  account.value <- readRDS("data/clean/btc_account_value.RDS")
  system.config$high.water.mark <- max(account.value$btc_value)
}

timeDifferences <- function(last.updated, current.time){
  difftime(current.time, last.updated, units="mins")
}

volatilityTargetChecking <- function(){
  account.value <- readRDS(paste0(getwd(), "/data/clean/margin_account_value.RDS"))
  vol.target <- round(100*system.config$volatility.target,2)
  
  value.xts <- as.xts(account.value[c("usdt_value", "btc_value")], order.by=account.value[,"date"])
  hourly.value.xts <- to.hourly(value.xts, OHLC=FALSE, indexAt="endof")
  hourly.returns.xts <- na.omit(CalculateReturns(hourly.value.xts))
  realized.vol <- round(100*sd(hourly.returns.xts[,"usdt_value"]),2)
  print(paste0("Hourly Volatility Target: ",vol.target,"%. All-Time Realized Hourly Volatility: ",realized.vol,"%. (St. Dev.'s)"))
}
# recordAccountValue <- function()
# {
#   system.config$poloniex.margin.value <- accountValue()
#   new.data <- data.frame(date=Sys.time(), account.value=system.config$poloniex.margin.value)
#   
#   file.name <- paste0(getwd(), "/data/clean/account_value.RDS")
#   old.data <- readRDS(file=file.name)
#   combo.data <- rbind(old.data, new.data)
#   saveRDS(combo.data, file=file.name)
#   return(system.config$poloniex.margin.value)
# }

generateReports <- function(){
  # file.time <- Sys.time()
  # pdf.name <- paste0("figures/final/send/MergedPDFs_",file.time,".pdf")
  # 
  # plotflow:::mergePDF(
  #   in.file=relativePath("/figures/final/reports"),
  #   file=relativePath(pdf.name)
  # )
  
  # clear reports folder
}

sendReports <- function(){
  # list the files in the send folder
  # for each try to send and move to backup if successful
  # try.to.send <- try(slackr_upload(pdf.name, channels = "reports"))
  #move to backups folder
}

appendNewData <- function(file.name=NULL, new.data=NULL){
  
  file.name <- paste0(getwd(), "/data/clean/",file.name,".RDS")
  old.data <- try(readRDS(file=file.name))
  if(inherits(old.data, "try-error")){old.data <- NULL}
  combo.data <- rbind(old.data, new.data)
  saveRDS(combo.data, file=file.name)
}

recordAccountValue <- function(){
  system.config$poloniex.margin.value <- accountValue()
  Sys.sleep(.15)
  usdt.exchange.rate <- getMid(ticker=returnTicker(), pair="USDT_BTC")
  current.time <- Sys.time()
  usdt.value <- system.config$poloniex.margin.value * usdt.exchange.rate
  new.data <- data.frame(date=current.time, usdt_value=usdt.value, btc_value=system.config$poloniex.margin.value)
  
  appendNewData(file.name="margin_account_value", new.data=new.data)
  # print(new.data)
  return(new.data)
}

timeDifferences <- function(last.updated, current.time){
  difftime(current.time, last.updated, units="mins")
}

volatilityTargetChecking <- function(){
  account.value <- readRDS(paste0(getwd(), "/data/clean/margin_account_value.RDS"))
  vol.target <- round(100*system.config$volatility.target,2)
  
  value.xts <- as.xts(account.value[c("usdt_value", "btc_value")], order.by=account.value[,"date"])
  hourly.value.xts <- to.hourly(value.xts, OHLC=FALSE, indexAt="endof")
  hourly.returns.xts <- na.omit(CalculateReturns(hourly.value.xts))
  realized.vol <- round(100*sd(hourly.returns.xts[,"usdt_value"]),2)
  print(paste0("Hourly Volatility Target: ",vol.target,"%. All-Time Realized Hourly Volatility: ",realized.vol,"%. (St. Dev.'s)"))
}
# recordAccountValue <- function()
# {
#   system.config$poloniex.margin.value <- accountValue()
#   new.data <- data.frame(date=Sys.time(), account.value=system.config$poloniex.margin.value)
#   
#   file.name <- paste0(getwd(), "/data/clean/account_value.RDS")
#   old.data <- readRDS(file=file.name)
#   combo.data <- rbind(old.data, new.data)
#   saveRDS(combo.data, file=file.name)
#   return(system.config$poloniex.margin.value)
# }

generateReports <- function(){
  # file.time <- Sys.time()
  # pdf.name <- paste0("figures/final/send/MergedPDFs_",file.time,".pdf")
  # 
  # plotflow:::mergePDF(
  #   in.file=relativePath("/figures/final/reports"),
  #   file=relativePath(pdf.name)
  # )
  
  # clear reports folder
}

sendReports <- function(){
  # list the files in the send folder
  # for each try to send and move to backup if successful
  # try.to.send <- try(slackr_upload(pdf.name, channels = "reports"))
  #move to backups folder
}

appendNewData <- function(file.name=NULL, new.data=NULL){
  
  file.name <- paste0(getwd(), "/data/clean/",file.name,".RDS")
  old.data <- try(readRDS(file=file.name))
  if(inherits(old.data, "try-error")){old.data <- NULL}
  combo.data <- rbind(old.data, new.data)
  saveRDS(combo.data, file=file.name)
}

recordAccountValue <- function(){
  system.config$poloniex.margin.value <- accountValue()
  Sys.sleep(.15)
  usdt.exchange.rate <- getMid(ticker=returnTicker(), pair="USDT_BTC")
  current.time <- Sys.time()
  usdt.value <- system.config$poloniex.margin.value * usdt.exchange.rate
  new.data <- data.frame(date=current.time, usdt_value=usdt.value, btc_value=system.config$poloniex.margin.value)
  
  appendNewData(file.name="margin_account_value", new.data=new.data)
  # print(new.data)
  return(new.data)
}

timeDifferences <- function(last.updated, current.time){
  difftime(current.time, last.updated, units="mins")
}

volatilityTargetChecking <- function(){
  account.value <- readRDS(paste0(getwd(), "/data/clean/margin_account_value.RDS"))
  vol.target <- round(100*system.config$volatility.target,2)
  
  value.xts <- as.xts(account.value[c("usdt_value", "btc_value")], order.by=account.value[,"date"])
  hourly.value.xts <- to.hourly(value.xts, OHLC=FALSE, indexAt="endof")
  hourly.returns.xts <- na.omit(CalculateReturns(hourly.value.xts))
  realized.vol <- round(100*sd(hourly.returns.xts[,"usdt_value"]),2)
  print(paste0("Hourly Volatility Target: ",vol.target,"%. All-Time Realized Hourly Volatility: ",realized.vol,"%. (St. Dev.'s)"))
}

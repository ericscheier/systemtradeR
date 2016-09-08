fullAPIPull <- function(){
  fullAPIPull.poloniex()
}

fullAPIPull.poloniex <- function(){
  saveLendingBook()
  saveOrderBook()
}

# transition to refresh for things like:
## order book [done]
## lending book [done]
## open orders
## current positions
## open loan offers
## recent market trades
## recent portfolio trades
## past orders

saveLendingBook <- function(){
  data.dir <- "data/clean/market/"
  market.files <- list.files(data.dir)
  for(currency in system.config$portfolio.currencies){
    file.to.move <- market.files[grep(paste0("lendingbook_",currency),market.files)]
    file.rename(from=paste0(data.dir,file.to.move), to=paste0(data.dir,"archive/",file.to.move))
    update.time <- as.numeric(Sys.time())*10^5
    
    loan.orders <- returnLoanOrders(currency = currency)
    
    file.name <- paste0(data.dir,"lendingbook_",currency,"_",as.numeric(update.time),".RDS")
    saveRDS(loan.orders, file=file.name)
    Sys.sleep(1/5)
  }
}

loadLendingBook <- function(currency){
  data.dir <- "data/clean/market/"
  market.files <- list.files(data.dir)
  file.to.load <- market.files[grep(paste0("lendingbook_",currency),market.files)]
  return(readRDS(paste0(data.dir,file.to.load)))
}

# saveLendingBook()

# lb <- loadLendingBook(currency = "XMR")

saveOrderBook <- function(){
  data.dir <- "data/clean/market/"
  market.files <- list.files(data.dir)
  file.to.move <- market.files[grep("orderbook_",market.files)]
  file.rename(from=paste0(data.dir,file.to.move), to=paste0(data.dir,"archive/",file.to.move))
  update.time <- as.numeric(Sys.time())*10^5
  
  order.book <- returnOrderBook(currencyPair="all", depth=50)
  
  file.name <- paste0(data.dir,"orderbook_",as.numeric(update.time),".RDS")
  saveRDS(order.book, file=file.name)
}

loadOrderBook <- function(){
  data.dir <- "data/clean/market/"
  market.files <- list.files(data.dir)
  file.to.load <- market.files[grep("orderbook_",market.files)]
  return(readRDS(paste0(data.dir,file.to.load)))
}

# ls(loadOrderBook())

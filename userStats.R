source("userConfig.R")

returnLendingHistory <- function(start.time=NULL, end.time=NULL){
  command <- "returnLendingHistory"
  
  # API method discovered by trial and error
  
  start.seconds <- as.numeric(seconds(as.POSIXct(start.time, origin = "1970-01-01")))
  end.seconds <- as.numeric(seconds(as.POSIXct(end.time, origin = "1970-01-01")))
  config.specs <- list(
    #currencyPair=currency.pair,
    start=start.seconds,
    end=end.seconds,
    limit=5000)
  command.result <- api.poloniex(command=command, args=config.specs)
  return(command.result)
}

returnFullLendingHistory <- function(){
  # do month by month and then combine
}


start.time <- user.config$account.created
current.time <- Sys.time()

dep.with <- returnDepositsWithdrawals(start.time=start.time, end.time=current.time)
trade.history <- returnTradeHistory(currency.pair="all", start.time=ustart.time, end.time=current.time)
lending.history <- read.csv("data/clean/lendingHistory.csv")# returnLendingHistory(start.time=start.time, end.time=current.time)

dw <- data.table(ldply(dep.with, function(x) ldply(x, data.frame, stringsAsFactors=FALSE, .id="type"), .id="type"))
th <- data.table(ldply(trade.history, function(x) ldply(x, data.frame, stringsAsFactors=FALSE), .id="pair"))
lh <- data.table(lending.history) #data.table(ldply(lending.history, data.frame, stringsAsFactors=FALSE, .id="order.number"))

base.currency <- "BTC"
currencies <- system.config$portfolio.currencies
fx.pairs <- paste(base.currency, currencies[currencies!=base.currency], sep="_")
fx.rates.list <- lapply(fx.pairs, function(x) {
  dt <- data.table(getPairData(x), keep.rownames = T)
  names(dt) <- c("date",x)
  return(dt)
})
fx.rates <- Reduce(function(...) merge(..., all = T, by="date"), fx.rates.list)

dw[,amount:=as.numeric(amount)]
dw[,date:=as.POSIXct(timestamp, origin="1970-01-01")]
dw[,type:=ifelse(type=="deposits","deposit","withdrawal")]

th$pair <- as.character(th$pair)
th$asset <- sapply(th$pair, function(x) pairToCurrencies(x)$asset)
th$base <- sapply(th$pair, function(x) pairToCurrencies(x)$base)
th$date <- as.POSIXct(th$date, origin="1970-01-01")
th$rate <- as.numeric(th$rate)
th$amount <- as.numeric(th$amount)
th$total <- as.numeric(th$total)
th$fee <- as.numeric(th$fee)

names(lh) <- tolower(names(lh))

# dw: type, currency, address, amount, confirmations, txid, timestamp, status
#     added: date
# th: pair, globalTradeID, tradeID, date, rate, amount, total, fee, orderNumber, type, category
# amount in terms of asset
# rate in asset/base
# total = rate * amount
# lh: currency, rate, amount, duration, interest, fee, earned, open, close

curr <- "XMR"

curr.deposits <- dw[currency==curr & type=="deposits",list(amount, currency)]
curr.withdrawals <- dw[currency==curr & type=="withdrawals",list(amount, currency)]

tradeCategory <- function(x.row){
  if(x.row[["category"]]=="exchange"){
    currencies <- system.config$portfolio.currencies
    asset.not.currency <- !(x.row[["asset"]] %in% currencies)
    base.not.currency <- !(x.row[["base"]] %in% currencies)
    if(xor(asset.not.currency, base.not.currency)){
      if(asset.not.currency){
        portfolio.currency <- x.row[["base"]]
        portfolio.amount <- as.numeric(x.row[["rate"]]) * as.numeric(x.row[["amount"]])
        if(x.row[["type"]]=="buy"){
          # base is used to buy asset
          accounting.type <- "withdrawal"
          
        }
        if(x.row[["type"]]=="sell"){
          accounting.type <- "deposit"
          # asset is sold for base
        }
      }
      if(base.not.currency){
        portfolio.currency <- x.row[["asset"]]
        portfolio.amount <- as.numeric(x.row[["amount"]])
        if(x.row[["type"]]=="buy"){
          # base is used to buy asset
          accounting.type <- "deposit"
          
        }
        if(x.row[["type"]]=="sell"){
          accounting.type <- "withdrawal"
          # asset is sold for base
        }
      }
    }
    if(asset.not.currency & base.not.currency){
      portfolio.currency <- NA
      portfolio.amount <- NA
      accounting.type <- NA
    }
    if(!asset.not.currency & !base.not.currency){
      portfolio.currency <- NA
      portfolio.amount <- NA
      accounting.type <- "trade"
    }
  } else {
    portfolio.currency <- NA
    portfolio.amount <- NA
    accounting.type <- NA
  }
  return(data.frame(date=as.POSIXct(x.row[["date"]], origin="1970-01-01"),
                    currency=portfolio.currency,
                    amount=portfolio.amount,
                    type=accounting.type, stringsAsFactors=FALSE))
}

other.dw <- ldply(apply(th, 1, tradeCategory))
dws <- rbind(dw[currency %in% currencies,list(date,currency,amount,type)], other.dw[other.dw$type %in% c("deposit","withdrawal"),])

curr.exchange.deposits <- 1
curr.exchange.withdrawals <- 1







# we are only going to track within the margin currencies, any trades into or out of this set are counted as deposits/withdrawals
# probably blotter has all of this logic already embedded, just need to get to correct format
# also need to start tracking bot orders/trades so that pnl can be correctly attributed
# track orders live, then check which orders resulted in trades. Better done in python
# 
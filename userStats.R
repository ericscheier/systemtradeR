source("userConfig.R")

returnFullLendingHistory <- function(start.time=NULL, end.time=Sys.time()){
  # do month by month and then combine
  if(is.null(end.time)){
    end.time <- Sys.time()
  }
  
  i <- 0
  full.lh <- c()
  while(i <12){
    month.back <- max(end.time-months(1), start.time)
    lh <- returnLendingHistory(start.time=month.back, end.time=end.time)
    end.time <- month.back
    full.lh <- c(full.lh, lh)
    if(length(lh)==0){i <- i + 1}
    if(!is.null(start.time)){
      if(month.back==start.time){return()}
    }
  }
  
  return(full.lh)
}


start.time <- user.config$account.created
current.time <- Sys.time()

dep.with <- returnDepositsWithdrawals(start.time=start.time, end.time=current.time)
trade.history <- returnTradeHistory(currency.pair="all", start.time=start.time, end.time=current.time)
lending.history <- returnFullLendingHistory()

dw <- data.table(ldply(dep.with, function(x) ldply(x, data.frame, stringsAsFactors=FALSE, .id="type"), .id="type"))
th <- data.table(ldply(trade.history, function(x) ldply(x, data.frame, stringsAsFactors=FALSE), .id="pair"))
lh <- lh <- ldply(lending.history, data.frame, stringsAsFactors=FALSE, .id="order.number")

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
lh$rate <- as.numeric(lh$rate)
lh$amount <- as.numeric(lh$amount)
lh$duration <- as.numeric(lh$duration)
lh$interest <- as.numeric(lh$interest)
lh$fee <- as.numeric(lh$fee)
lh$earned <- as.numeric(lh$earned)
lh$open <- as.POSIXct(lh$open)
lh$close <- as.POSIXct(lh$close)


# dw: type, currency, address, amount, confirmations, txid, timestamp, status
#     added: date
# th: pair, globalTradeID, tradeID, date, rate, amount, total, fee, orderNumber, type, category
# amount in terms of asset
# rate in asset/base
# total = rate * amount
# lh: currency, rate, amount, duration, interest, fee, earned, open, close

tradeCategory <- function(x.row){
  
  if(x.row[["category"]]=="exchange"){
    currencies <- system.config$portfolio.currencies
    asset.not.in.currency <- !(x.row[["asset"]] %in% currencies)
    base.not.in.currency <- !(x.row[["base"]] %in% currencies)
    if(xor(asset.not.in.currency, base.not.in.currency)){
      if(asset.not.in.currency){
        portfolio.currency <- x.row[["base"]]
        portfolio.amount <- as.numeric(x.row[["rate"]]) * as.numeric(x.row[["amount"]])
        if(x.row[["type"]]=="buy"){
          # base is used to buy asset
          accounting.type <- "withdrawal"
          portfolio.amount <- -1 * portfolio.amount
        }
        if(x.row[["type"]]=="sell"){
          accounting.type <- "deposit"
          # asset is sold for base
        }
      }
      if(base.not.in.currency){
        portfolio.currency <- x.row[["asset"]]
        portfolio.amount <- as.numeric(x.row[["amount"]])
        if(x.row[["type"]]=="buy"){
          # base is used to buy asset
          accounting.type <- "deposit"
          
        }
        if(x.row[["type"]]=="sell"){
          accounting.type <- "withdrawal"
          portfolio.amount <- -1 * portfolio.amount
          # asset is sold for base
        }
      }
      return(data.frame(date=as.POSIXct(x.row[["date"]], origin="1970-01-01"),
                        currency=portfolio.currency,
                        amount=portfolio.amount,
                        type=accounting.type, stringsAsFactors=FALSE))
    }
    if(asset.not.in.currency & base.not.in.currency){
      portfolio.currency <- NA
      portfolio.amount <- NA
      accounting.type <- "outside.trade"
    }
    if(!asset.not.in.currency & !base.not.in.currency){
      asset.currency <- x.row[["asset"]]
      asset.amount <- as.numeric(x.row[["amount"]])
      base.currency <- x.row[["base"]]
      base.amount <- as.numeric(x.row[["total"]])
      fee.amount <- -1 * as.numeric(x.row[["fee"]]) * base.amount
      accounting.type <- "trade"
      if(x.row[["type"]]=="buy"){
        # base is used to buy asset
        base.amount <- -1 * base.amount
        
      }
      if(x.row[["type"]]=="sell"){
        asset.amount <- -1 * asset.amount
        # asset is sold for base
      }
      trade.frame <- data.frame(date=rep(as.POSIXct(x.row[["date"]], origin="1970-01-01"),3),
                                currency=c(asset.currency, base.currency, base.currency),
                                amount=c(asset.amount, base.amount, fee.amount),
                                type=c(accounting.type, accounting.type, "fee"), stringsAsFactors=FALSE)
      return(trade.frame)
    }
  } else if(x.row[["category"]]=="marginTrade"){
    # x.row[["category"]]=="settlement" || 
    asset.currency <- x.row[["asset"]]
    asset.amount <- as.numeric(x.row[["amount"]])
    base.currency <- x.row[["base"]]
    base.amount <- as.numeric(x.row[["total"]])
    fee.amount <- -1 * as.numeric(x.row[["fee"]]) * base.amount
    accounting.type <- "exposure"
    if(x.row[["type"]]=="buy"){
      # base is used to buy asset
      asset.amount <- 1 * asset.amount
      
    }
    if(x.row[["type"]]=="sell"){
      asset.amount <- -1 * asset.amount
      # asset is sold for base
    }
    margin.frame <- data.frame(date=rep(as.POSIXct(x.row[["date"]], origin="1970-01-01"),2),
                              currency=c(asset.currency, base.currency),
                              amount=c(asset.amount, fee.amount),
                              type=c(rep(accounting.type, 1), "fee"), stringsAsFactors=FALSE)
    return(margin.frame)
  } else if(x.row[["category"]]=="settlement"){
    # x.row[["category"]]=="settlement" || 
    asset.currency <- x.row[["asset"]]
    asset.amount <- as.numeric(x.row[["amount"]])
    base.currency <- x.row[["base"]]
    base.amount <- as.numeric(x.row[["total"]])
    fee.amount <- -1 * as.numeric(x.row[["fee"]]) * base.amount
    accounting.type <- "fee"
    if(x.row[["type"]]=="buy"){
      # base is used to buy asset
      asset.amount <- -1 * asset.amount
      
    }
    if(x.row[["type"]]=="sell"){
      asset.amount <- -1 * asset.amount
      # asset is sold for base
    }
    settlement.frame <- data.frame(date=rep(as.POSIXct(x.row[["date"]], origin="1970-01-01"),2),
                               currency=c(asset.currency, base.currency),
                               amount=c(asset.amount, fee.amount),
                               type=c(rep(accounting.type, 1), "fee"), stringsAsFactors=FALSE)
    return(settlement.frame)
  } else {
    return(data.frame(date=rep(as.POSIXct(x.row[["date"]], origin="1970-01-01"),1),
                     currency=NA,
                     amount=NA,
                     type=NA, stringsAsFactors=FALSE))
  }
  return()
}
cat.trades <- data.table(ldply(apply(th, 1, tradeCategory)))
# other.dw <- cat.trades[cat.trades$type %in% c("deposit","withdrawal"),]


# make sure that dw deposits & withdrawals have the correct sign
# have made no withdrawals yet so filter is not necessary
# dws <- rbind(dw[currency %in% currencies,list(date,currency,amount,type)], cat.trades[type %in% c("deposit", "withdrawal"),])

lent <- lh[,c("close", "currency", "earned")]
lent$type <- "interest"
names(lent) <- c("date","currency","amount","type")

currencies <- system.config$portfolio.currencies

master.list <- rbind(cat.trades, lent)
master.list <- rbind(master.list, dw[currency %in% currencies,list(date,currency,amount,type)])

master.list <- na.omit(master.list)
master.list$date <- align.time(master.list$date, 60*5)



base.currency <- "BTC"

fx.pairs <- paste(base.currency, currencies[currencies!=base.currency], sep="_")
fx.rates.list <- lapply(fx.pairs, function(x) {
  dt <- data.table(getPairData(x), keep.rownames = T)
  names(dt) <- c("date",x)
  return(dt)
})
fx.rates <- Reduce(function(...) merge(..., all = T, by="date"), fx.rates.list)
fx.rates.xts <- as.xts.data.table(fx.rates)

fx.rates.melted <- melt.data.table(fx.rates, id.vars=c("date"),variable.name = "currency", value.name = "rate")
fx.rates.melted$currency <- as.character(fx.rates.melted$currency)
fx.rates.melted <- na.omit(fx.rates.melted)
fx.rates.melted$currency <- sapply(fx.rates.melted$currency, function(x) pairToCurrencies(x)$asset)

merged.list <- merge(master.list, fx.rates.melted, by=c("date","currency"), all.x = TRUE)
merged.list[currency==base.currency, rate:=1]
merged.list[,adjusted.amount:=amount * rate]
merged.list <- merged.list[order(date)]
merged.list <- na.omit(merged.list)

merged.list[type %in% c("deposit", "withdrawal"),basis:=adjusted.amount]
merged.list[!(type %in% c("deposit", "withdrawal")),basis:=0]
merged.list[,basis:=cumsum(basis)]
merged.list[type %in% c("deposit", "withdrawal"),adjusted.amount:=0]

basis.xts <- as.xts(x=merged.list$basis, order.by=merged.list$date)
adjusted.amount <- as.xts(x=merged.list$adjusted.amount, order.by=merged.list$date)

final.xts <- as.xts(x=merged.list[,cumsum(adjusted.amount)/basis],order.by=merged.list$date)
plot.xts(to.hourly(final.xts))

plot(x=merged.list$date, y=merged.list[,cumsum(adjusted.amount)/basis], type="l")
plot(x=merged.list$date, y=merged.list[,cumsum(adjusted.amount)], type="l")

# we are only going to track within the margin currencies, any trades into or out of this set are counted as deposits/withdrawals
# probably blotter has all of this logic already embedded, just need to get to correct format
# also need to start tracking bot orders/trades so that pnl can be correctly attributed
# track orders live, then check which orders resulted in trades. Better done in python
# 

poloniex.currencies <- c("BTC", "BTS", "CLAM", "DOGE", "DASH", "LTC", "MAID", "STR", "XMR", "XRP", "ETH", "FCT")
poloniex.portfolios <- c("exchange", "margin", "lending")
poloniex.summary <- expand.grid(portfolio=poloniex.portfolios, currency=poloniex.currencies, balance=NA, stringsAsFactors = F)

poloniex.balances <- returnAvailableAccountBalances()

balanceCalc <- function(x, poloniex.balances=NULL){
  balance <- poloniex.balances[[x["portfolio"]]][[x["currency"]]]
  return(ifelse(is.null(balance),0,balance))
}

poloniex.summary$balance <- apply(poloniex.summary, 1, balanceCalc, poloniex.balances=poloniex.balances)

sapply(poloniex.portfolios, function(x) poloniex.balances[[x]])

investment.universe <- loadInvestmentUniverse()

investment.pairs <- investment.universe[!investment.universe$is.restricted && investment.universe$exchange=="poloniex","asset"]

# need to account for if I have no margin positions
margin.positions <- ldply(getMarginPosition(), data.frame, stringsAsFactors=FALSE)
# complete.balances <- returnCompleteBalances(account = "all")
if(nrow(margin.positions) > 0){
  margin.holdings <- margin.positions[,c(".id",'amount')]
  colnames(margin.holdings) <- c("currency", "balance")
  margin.holdings$portfolio <- "margin.holdings"
  margin.holdings$currency <- gsub("BTC_","",margin.holdings$currency)
  margin.holdings$balance <- as.numeric(margin.holdings$balance)
  
  btc.holdings <- data.frame(portfolio="margin.holdings", currency="BTC", balance=sum(as.numeric(margin.positions$total)))
  
  margin.holdings <- rbind(btc.holdings, margin.holdings)
} else {
  margin.holdings <- data.frame(portfolio="margin.holdings", currency="BTC", balance=0)
}


poloniex.summary <- rbind(poloniex.summary, margin.holdings)

active.loans <- returnActiveLoans()

active.used.loans <- ldply(active.loans$used, data.frame, stringsAsFactors=F)
if(nrow(active.used.loans) > 0){
  borrowed <- aggregate(as.numeric(active.used.loans$amount), list(currency=active.used.loans$currency), sum)
  names(borrowed) <- c("currency", "balance")
  borrowed$portfolio <- "borrowed"
} else {
  borrowed <- data.frame(portfolio="borrowed", currency="BTC", balance=0)
}
poloniex.summary <- rbind(poloniex.summary, borrowed)

active.provided.loans <- ldply(active.loans$provided, data.frame, stringsAsFactors=F)
# haven't tested yet with actual loan data
if(nrow(active.provided.loans) > 0){
  lent <- aggregate(as.numeric(active.provided.loans$amount), list(currency=active.provided.loans$currency), sum)
  names(lent) <- c("currency", "balance")
  lent$portfolio <- "lent"
} else {
  lent <- data.frame(portfolio="lent", currency="BTC", balance=0)
  }

poloniex.summary <- rbind(poloniex.summary, lent)

loan.offers <- returnOpenLoanOffers()
# TO-DO incorporate open loan offers into account summary

open.orders <- returnOpenOrders()
# TO-DO incorporate open orders into account summary

poloniex.summary$balance <- as.numeric(poloniex.summary$balance)

aggregate(x=poloniex.summary$balance, by=list(currency=poloniex.summary$currency), FUN=sum)

dcast(as.data.table(poloniex.summary), currency ~ portfolio, value.var="balance", fill=0)[,list(currency, exchange, lending, margin, margin.holdings, borrowed, lent)]

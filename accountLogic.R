


# poloniex.summary <- refreshAccount.poloniex()
# aggregate(x=poloniex.summary$balance, by=list(currency=poloniex.summary$currency), FUN=sum)

determineOptimalAllocation <- function(){
  account.overview <- loadAccountOverview()
  investment.universe <- loadInvestmentUniverse()
  account.value <- system.config$poloniex.margin.value
  
  account.overview.cols <- colnames(account.overview)
  account.overview.cols <- account.overview.cols[account.overview.cols != "currency"]
  
  investment.universe <- investment.universe[investment.universe$exchange=="poloniex",]
  investment.universe$currency <- sapply(investment.universe$asset, function(x) pairToCurrencies(x)$asset)
  
  account.universe <- merge(investment.universe, account.overview, by="currency")
  # net.btc.position <- sum(with(account.universe, (optimal.position<0) * optimal.position * ref.price))
  
  optimal.account.overview <- ldply(apply(account.universe, 1, optimizeAllocation), data.frame, stringsAsFactors=F)
  
  optimal.btc.account.overview <- optimal.account.overview[,account.overview.cols] * optimal.account.overview$ref.price
  optimal.btc.account.overview$currency <- as.character(optimal.account.overview$currency)
  
  current.btc.account.overview <- account.universe[,account.overview.cols] * account.universe$ref.price
  current.btc.account.overview$currency <- as.character(account.universe$currency)
  current.btc.account.overview <- rbind(current.btc.account.overview, account.overview[currency=="BTC",])
  
  btc.available <- max(0,account.value - sum(optimal.btc.account.overview[,c("exchange.equity","lending","margin.collateral")]))
  optimal.btc.exchange.equity <- sum(optimal.btc.account.overview$exchange.equity) * system.config$market.making.exposure.ratio
  optimal.btc.margin.collateral <- abs(sum(optimal.btc.account.overview$margin.position)) * system.config$margin.maintenance.percent
  optimal.btc.lending <- max(0,btc.available - btc.exchange.equity - btc.margin.collateral)
  optimal.btc.account.overview
  data.frame(exchange.equity=optimal.btc.exchange.equity, lending=optimal.btc.lending, margin.collateral=optimal.btc.margin.collateral)
  
  
}

optimizeAllocation <- function(account.universe.row){
  currency <- as.character(account.universe.row["currency"])
  
  margin.maintenance.percent <- system.config$margin.maintenance.percent
  optimal.exchange.percent <- 0.3
  
  optimal.position <- 16 #account.universe.row[["optimal.position"]]
  ref.price <- as.numeric(account.universe.row[["ref.price"]])
  exchange.equity <- as.numeric(account.universe.row[["exchange.equity"]])
  lending <- as.numeric(account.universe.row[["lending"]])
  margin.collateral <- as.numeric(account.universe.row[["margin.collateral"]])
  margin.position <- as.numeric(account.universe.row[["margin.position"]])
  lent <- as.numeric(account.universe.row[["lent"]])
  loan.offers <- as.numeric(account.universe.row[["loan.offers"]])
  borrowed <- as.numeric(account.universe.row[["borrowed"]])
  open.orders <- account.universe.row[["open.orders"]]
  # optimal.position.btc <- optimal.position * ref.price
  if(optimal.position < 0){
    optimal.lending <- 0
    optimal.equity <- 0
    optimal.margin.collateral <- abs(optimal.position) * margin.maintinence.level
    optimal.margin.position <- optimal.position
  } else {
    optimal.equity <- optimal.position * optimal.exchange.percent
    optimal.lending <- optimal.position - optimal.equity
    optimal.margin.collateral <- 0
    optimal.margin.position <- 0
  }
  return(data.frame(currency=currency,
                    exchange.equity=optimal.equity,
                    margin.collateral=optimal.margin.collateral,
                    margin.position=optimal.margin.position,
                    lending=optimal.lending,
                    lent=lent,
                    loan.offers=loan.offers,
                    borrowed=abs(optimal.margin.position),
                    open.orders=as.numeric(open.orders),
                    ref.price=ref.price))
}

refreshAccount.poloniex <- function(){
  poloniex.currencies <- system.config$portfolio.currencies
  poloniex.portfolios <- c("exchange", "margin", "lending")
  poloniex.summary <- expand.grid(portfolio=poloniex.portfolios, currency=poloniex.currencies, balance=NA, stringsAsFactors = F)
  
  poloniex.balances <- returnAvailableAccountBalances()
  
  balanceCalc <- function(x, poloniex.balances=NULL){
    balance <- poloniex.balances[[x["portfolio"]]][[x["currency"]]]
    return(ifelse(is.null(balance),0,balance))
  }
  
  poloniex.summary$balance <- apply(poloniex.summary, 1, balanceCalc, poloniex.balances=poloniex.balances)
  
  poloniex.summary$portfolio[poloniex.summary$portfolio=="exchange"] <- "exchange.equity"
  poloniex.summary$portfolio[poloniex.summary$portfolio=="margin"] <- "margin.collateral"
  
  # sapply(poloniex.portfolios, function(x) poloniex.balances[[x]])
  
  # investment.universe <- loadInvestmentUniverse()
  # 
  # investment.pairs <- investment.universe[!investment.universe$is.restricted && investment.universe$exchange=="poloniex","asset"]
  
  # need to account for if I have no margin positions
  margin.positions <- ldply(getMarginPosition(), data.frame, stringsAsFactors=FALSE)
  # complete.balances <- returnCompleteBalances(account = "all")
  if(nrow(margin.positions) > 0){
    margin.holdings <- margin.positions[,c(".id",'amount')]
    colnames(margin.holdings) <- c("currency", "balance")
    margin.holdings$portfolio <- "margin.position"
    margin.holdings$currency <- gsub("BTC_","",margin.holdings$currency)
    margin.holdings$balance <- as.numeric(margin.holdings$balance)
    
    btc.holdings <- data.frame(portfolio="margin.position", currency="BTC", balance=sum(as.numeric(margin.positions$total)))
    
    margin.holdings <- rbind(btc.holdings, margin.holdings)
  } else {
    margin.holdings <- data.frame(portfolio="margin.position", currency="BTC", balance=0)
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
  if(nrow(active.provided.loans)){
    lent <- aggregate(as.numeric(active.provided.loans$amount), list(currency=active.provided.loans$currency), sum)
    names(lent) <- c("currency", "balance")
    lent$portfolio <- "lent"
  } else {
    lent <- data.frame(portfolio="lent", currency="BTC", balance=0)
  }
  
  poloniex.summary <- rbind(poloniex.summary, lent)
  
  open.loan.offers <- ldply(returnOpenLoanOffers(), function(x) ldply(x, data.frame, stringsAsFactors=F), .id="currency")
  # rbind(lapply(ls(open.loan.offers), function(x) ldply(open.loan.offers[[x]], data.frame, stringsAsFactors=FALSE)))
  if(nrow(open.loan.offers)){
    loans.offered <- aggregate(as.numeric(open.loan.offers$amount), list(currency=open.loan.offers$currency), sum)
    names(loans.offered) <- c("currency", "balance")
    loans.offered$portfolio <- "loan.offers"
  } else {
    loans.offered <- data.frame(portfolio="loan.offers", currency="BTC", balance=0)
  }
  
  poloniex.summary <- rbind(poloniex.summary, loans.offered)
  
  # open.orders <- ldply(returnOpenOrders(), function(x) ldply(x, data.frame, stringsAsFactors=F), .id="pair")
  # if(nrow(open.orders)){
  #   open.orders$pair <- as.character(open.orders$pair)
  #   sapply(open.orders$pair, pairToCurrencies)
  # }
  # TO-DO incorporate open orders into account summary
  
  complete.balances <- ldply(returnCompleteBalances(account="all"), data.frame, stringsAsFactors=F, .id="currency")
  complete.balances[,c("available","onOrders","btcValue")] <- lapply(complete.balances[,c("available","onOrders","btcValue")], as.numeric)
  open.orders <- complete.balances[match(poloniex.currencies,complete.balances$currency),c("currency","onOrders")]
  names(open.orders) <- c("currency", "balance")
  open.orders$portfolio <- "open.orders"
  
  poloniex.summary <- rbind(poloniex.summary, open.orders)
  
  poloniex.summary$balance <- as.numeric(poloniex.summary$balance)
  poloniex.overview <- dcast(as.data.table(poloniex.summary), currency ~ portfolio, value.var="balance", fill=0)[,list(currency,
                                                                                                                      exchange.equity,
                                                                                                                      lending,
                                                                                                                      margin.collateral,
                                                                                                                      margin.position,
                                                                                                                      borrowed, lent,
                                                                                                                      loan.offers,
                                                                                                                      open.orders
  )]
  
  saveRDS(poloniex.overview, relativePath("data/clean/poloniex_account_overview.RDS"))
  
  return(poloniex.overview)
}

loadAccountOverview <- function(){
  return(readRDS(relativePath("data/clean/poloniex_account_overview.RDS")))
}
  


# poloniex.summary <- refreshAccount.poloniex()
# aggregate(x=poloniex.summary$balance, by=list(currency=poloniex.summary$currency), FUN=sum)

refreshExecution <- function(){
  initializationChecks()
  recordAccountValue()
  determineCurrentAllocation.poloniex()
  determineOptimalAllocation.poloniex()
  
  refreshAllLoans()
  refreshAllMargin()
  refreshAllExchange()
  return()
}

initializationChecks <- function(){
  if(!file.exists("data/clean/market_making_config.RDS")){initializeMarketMakingConfig()}
}

# transferTowardOptimalAccounts <- function(){
#   current.accounts <- loadCurrentAccounts()
#   optimal.accounts <- loadOptimalAccounts()
#   accounts <- c("margin","exchange","lending")
#   accountsDataFrame <- function(account){
#     account.balance <- ldply(returnCompleteBalances(account=account), unlist, .id="currency")
#     account.balance$account <- account
#     return(account.balance)
#   }
#   account.balances <- as.data.table(ldply(accounts, accountsDataFrame))
#   account.balances <- account.balances[currency %in% optimal.accounts$currency,]
#   account.balances[,available:=as.numeric(available)]
#   account.balances[,onOrders:=as.numeric(onOrders)]
#   
#   for(i in 1:nrow(optimal.accounts)){
#     current.account.value <- sum(account.balances[currency==optimal.accounts$currency[i],c(available, onOrders)])
#   }
# }

determineCurrentAllocation.poloniex <- function(){
  # investment.universe <- loadInvestmentUniverse()
  
  
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
    # sum(as.numeric(margin.positions$total))
    
    btc.holdings <- data.frame(portfolio="margin.position", currency="BTC", balance=0)
    btc.margin.pl <- sum(as.numeric(margin.positions$total))
    
    margin.holdings <- rbind(btc.holdings, margin.holdings)
  } else {
    margin.holdings <- data.frame(portfolio="margin.position", currency="BTC", balance=0)
    btc.margin.pl <- 0
  }
  
  # current.btc.margin.collateral <- poloniex.summary[poloniex.summary$portolio=="margin.collateral" & poloniex.summary$currency=="BTC", "balance"]
  # poloniex.summary[poloniex.summary$portolio=="margin.collateral" & poloniex.summary$currency=="BTC", "balance"] <- 
  #   current.btc.margin.collateral + btc.margin.pl
  
  poloniex.summary <- rbind(poloniex.summary, margin.holdings)
  
  active.loans <- returnActiveLoans()
  
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
  
  # exchange.offers <- ldply(returnCompleteBalances(account="exchange"), data.frame, stringsAsFactors=F, .id="currency")
  # exchange.offers$onOrders <- as.numeric(exchange.offers$onOrders)
  # exchange.offers <- complete.balances[match(poloniex.currencies,exchange.offers$currency),c("currency","onOrders")]
  # names(exchange.offers) <- c("currency", "balance")
  # exchange.offers$portfolio <- "exchange.offers"
  # 
  # poloniex.summary <- rbind(poloniex.summary, exchange.offers)
  
  
  
  poloniex.summary$balance <- as.numeric(poloniex.summary$balance)
  
  current.btc.margin.collateral <- poloniex.summary[poloniex.summary$portfolio=="margin.collateral" & poloniex.summary$currency=="BTC","balance"]
  poloniex.summary[poloniex.summary$portfolio=="margin.collateral" & poloniex.summary$currency=="BTC","balance"] <- 
    current.btc.margin.collateral + btc.margin.pl
  
  c("lending","loan.offers","lent")
  c("margin.collateral")
  c("exchange.equity","exchange.offers")
  
  poloniex.summary <- as.data.table(poloniex.summary)
  
  lending <- poloniex.summary[portfolio %in% c("lending","loan.offers","lent"), list(balance=sum(balance)), by=list(currency)]
  lending$portfolio <- "lending"
  
  margin.collateral <- poloniex.summary[portfolio %in% c("margin.collateral"), list(balance=sum(balance)), by=list(currency)]
  margin.collateral$portfolio <- "margin.collateral"
  
  exchange.equity <- poloniex.summary[portfolio %in% c("exchange.equity","exchange.offers"), list(balance=sum(balance)), by=list(currency)]
  exchange.equity$portfolio <- "exchange.equity"
  
  margin.position <- poloniex.summary[portfolio %in% c("margin.position"), list(balance=sum(balance)), by=list(currency)]
  margin.position$portfolio <- "margin.position"
  
  current.accounts <- rbindlist(list(lending, margin.collateral, margin.position, exchange.equity))
  
  poloniex.overview <- dcast(current.accounts, currency ~ portfolio, value.var="balance", fill=0)[,list(currency,
                                                                                                        exchange.equity,
                                                                                                        lending,
                                                                                                        margin.collateral,
                                                                                                        margin.position#,
                                                                                                        # borrowed, lent,
                                                                                                        # loan.offers,
                                                                                                        # open.orders
                                                                                                        # open.exchange.orders,
                                                                                                        # open.margin.orders
  )]
  
  # poloniex.overview <- 
  
  saveRDS(as.data.frame(poloniex.overview), relativePath("data/clean/current_accounts.RDS"))
  
  investment.universe <- loadInvestmentUniverse()
  ref.prices <-data.table(currency=sapply(investment.universe$asset, function(x) pairToCurrencies(x)$asset),
                                      ref.price=investment.universe$ref.price)
  ref.prices[currency=="BTC",ref.price:=1]
  
  poloniex.btc.overview <- poloniex.overview[,list(exchange.equity, lending, margin.collateral, margin.position)] * 
    ref.prices[match(poloniex.overview$currency, ref.prices$currency),c(ref.price)]
  poloniex.btc.overview[,currency:=poloniex.overview$currency]
  poloniex.btc.overview <- poloniex.btc.overview[,list(currency,exchange.equity, lending, margin.collateral, margin.position)]
  
  saveRDS(as.data.frame(poloniex.btc.overview), relativePath("data/clean/current_btc_accounts.RDS"))
  
  return(poloniex.overview)
  
  # current.btc.account.overview <- account.universe[,optimal.account.overview.cols] * account.universe$ref.price
  # current.btc.account.overview$currency <- as.character(account.universe$currency)
  # current.btc.account.overview <- rbind(current.btc.account.overview, account.overview[currency=="BTC",])
}

loadCurrentAccounts <- function(){
  return(readRDS(relativePath("data/clean/current_accounts.RDS")))
}

loadCurrentBTCAccounts <- function(){
  return(readRDS(relativePath("data/clean/current_btc_accounts.RDS")))
}

determineOptimalAllocation.poloniex <- function(){
  investment.universe <- loadInvestmentUniverse()
  account.value <- system.config$poloniex.margin.value
  
  investment.universe <- investment.universe[investment.universe$exchange=="poloniex",]
  investment.universe$currency <- sapply(investment.universe$asset, function(x) pairToCurrencies(x)$asset)
  
  account.universe <- investment.universe # merge(investment.universe, account.overview, by="currency")
  # net.btc.position <- sum(with(account.universe, (optimal.position<0) * optimal.position * ref.price))
  
  optimal.account.overview <- ldply(apply(account.universe, 1, optimizeAllocation))
  optimal.account.overview$.id <- NULL
  optimal.account.overview.cols <- colnames(optimal.account.overview)
  optimal.account.overview.cols <- optimal.account.overview.cols[optimal.account.overview.cols != "currency"]
  
  optimal.btc.account.overview <- optimal.account.overview[,optimal.account.overview.cols] * optimal.account.overview$ref.price
  
  btc.available <- account.value - sum(optimal.btc.account.overview[,c("exchange.equity","lending","margin.collateral")])
  if(btc.available < 0){
    # just in case, reduce everything proportinally to get to 0 btc remaining
    # in future may want to use additional margin to go long to beef up account
    scalar <- account.value/sum(optimal.btc.account.overview[,c("exchange.equity","lending","margin.collateral")])
    optimal.btc.account.overview <- optimal.btc.account.overview * scalar
    btc.available <- account.value - sum(optimal.btc.account.overview[,c("exchange.equity","lending","margin.collateral")])
  }
  
  optimal.btc.account.overview$currency <- as.character(optimal.account.overview$currency)
  
  optimal.btc.exchange.equity <- sum(optimal.btc.account.overview$exchange.equity) * system.config$market.making.exposure.ratio
  
  optimal.btc.margin.collateral <- sum(optimal.btc.account.overview$margin.collateral)
  optimal.btc.account.overview$margin.collateral <- 0
  
  # adapt this logic s.t. I use long positions for margin collateral if I can lend higher elsewhere
  # long.lending <- optimal.btc.account.overview[optimal.btc.account.overview$lending>0,"lending"] * .2
  # long.lending <- long.lending * min(1,optimal.btc.margin.collateral/sum(long.lending))
  # optimal.btc.account.overview[optimal.btc.account.overview$lending>0,"margin.collateral"] <- long.lending
  # optimal.btc.account.overview[optimal.btc.account.overview$lending>0,"lending"] <-
  #   optimal.btc.account.overview[optimal.btc.account.overview$lending>0,"lending"] - long.lending
    #abs(sum(optimal.btc.account.overview$margin.position)) * system.config$margin.maintenance.percent
  optimal.btc.margin.collateral <- optimal.btc.margin.collateral - sum(optimal.btc.account.overview$margin.collateral)
  optimal.btc.lending <- max(0,btc.available - optimal.btc.exchange.equity)# - optimal.btc.margin.collateral)
  # optimal.btc.account.overview
  optimal.btc.allocation <- data.frame(currency="BTC",
                                       exchange.equity=optimal.btc.exchange.equity,
                                       lending=optimal.btc.lending,
                                       margin.collateral=optimal.btc.margin.collateral)
  
  account.columns <- c("exchange.equity","lending","margin.collateral")
  optimal.btc.accounts <- rbind(optimal.btc.account.overview[,c("currency","exchange.equity","lending","margin.collateral")],
                                optimal.btc.allocation)
  too.small.orders <- sum(optimal.btc.accounts[,account.columns][optimal.btc.accounts[,account.columns] < system.config$minimum.order.size & 
                                                                   optimal.btc.accounts[,account.columns] > 0])
  if(too.small.orders){
    optimal.btc.accounts[,account.columns][optimal.btc.accounts[,account.columns] < system.config$minimum.order.size & 
                                             optimal.btc.accounts[,account.columns] > 0] <- 0
    optimal.btc.accounts[optimal.btc.accounts$currency=="BTC", "lending"] <-
      optimal.btc.accounts[optimal.btc.accounts$currency=="BTC", "lending"] + too.small.orders
  }
  
  saveRDS(optimal.btc.accounts, relativePath("data/clean/optimal_btc_accounts.RDS"))
  
  optimal.accounts <- optimal.btc.accounts
  optimal.accounts <- merge(optimal.accounts, optimal.btc.account.overview[c("currency","margin.position")], all.x=T)
  optimal.accounts[optimal.accounts$currency=="BTC","margin.position"] <- 0
  
  ref.prices <- account.universe$ref.price[match(optimal.accounts$currency, account.universe$currency)]
  ref.prices[is.na(ref.prices)] <- 1
  ref.prices[ref.prices==0] <- 1
  
  optimal.accounts[,c(account.columns,"margin.position")] <-
    optimal.accounts[,c(account.columns,"margin.position")] / ref.prices
  
  saveRDS(optimal.accounts, relativePath("data/clean/optimal_accounts.RDS"))
  return(optimal.accounts)
}

loadOptimalAccounts <- function(){
  return(readRDS(relativePath("data/clean/optimal_accounts.RDS")))
}

loadOptimalBTCAccounts <- function(){
  return(readRDS(relativePath("data/clean/optimal_btc_accounts.RDS")))
}

optimizeAllocation <- function(account.universe.row){
  currency <- as.character(account.universe.row["currency"])
  
  margin.maintenance.percent <- system.config$margin.maintenance.percent
  optimal.exchange.percent <- system.config$optimal.exchange.percent # 0.3
  
  optimal.position <- as.numeric(account.universe.row[["optimal.position"]])
  ref.price <- as.numeric(account.universe.row[["ref.price"]])
  # exchange.equity <- as.numeric(account.universe.row[["exchange.equity"]])
  # lending <- as.numeric(account.universe.row[["lending"]])
  # margin.collateral <- as.numeric(account.universe.row[["margin.collateral"]])
  # margin.position <- as.numeric(account.universe.row[["margin.position"]])
  # lent <- as.numeric(account.universe.row[["lent"]])
  # loan.offers <- as.numeric(account.universe.row[["loan.offers"]])
  # borrowed <- as.numeric(account.universe.row[["borrowed"]])
  # open.orders <- account.universe.row[["open.orders"]]
  # optimal.position.btc <- optimal.position * ref.price
  
  optimal.equity <- 0
  optimal.margin.collateral <- abs(optimal.position) * margin.maintenance.percent
  optimal.margin.position <- optimal.position
  optimal.lending <- 0 #optimal.position - optimal.margin.collateral
  
  # if(optimal.position < 0){
  #   optimal.lending <- 0
  #   optimal.equity <- 0
  #   optimal.margin.collateral <- abs(optimal.position) * margin.maintenance.percent
  #   optimal.margin.position <- optimal.position
  # } else {
  #   optimal.equity <- optimal.position * optimal.exchange.percent
  #   optimal.lending <- optimal.position - optimal.equity
  #   optimal.margin.collateral <- 0
  #   optimal.margin.position <- 0
  # }
  return(data.frame(currency=currency,
                    exchange.equity=optimal.equity,
                    margin.collateral=optimal.margin.collateral,
                    margin.position=optimal.margin.position,
                    lending=optimal.lending,
                    # lent=lent,
                    # loan.offers=loan.offers,
                    # borrowed=abs(optimal.margin.position),
                    # open.orders=as.numeric(open.orders),
                    ref.price=ref.price))
}

refreshAccount.poloniex <- function(){
  poloniex.currencies <- system.config$portfolio.currencies
  poloniex.portfolios <- c("exchange", "margin", "lending")
  
  
  active.used.loans <- ldply(active.loans$used, data.frame, stringsAsFactors=F)
  if(nrow(active.used.loans) > 0){
    borrowed <- aggregate(as.numeric(active.used.loans$amount), list(currency=active.used.loans$currency), sum)
    names(borrowed) <- c("currency", "balance")
    borrowed$portfolio <- "borrowed"
  } else {
    borrowed <- data.frame(portfolio="borrowed", currency="BTC", balance=0)
  }
  poloniex.summary <- rbind(poloniex.summary, borrowed)
  
  # open.orders <- ldply(returnOpenOrders(), function(x) ldply(x, data.frame, stringsAsFactors=F), .id="pair")
  # if(nrow(open.orders)){
  #   open.orders$pair <- as.character(open.orders$pair)
  #   sapply(open.orders$pair, pairToCurrencies)
  # }
  # TO-DO incorporate open orders into account summary
  
  poloniex.summary <- rbind(poloniex.summary, open.orders)
  
  
}

loadAccountOverview <- function(){
  return(readRDS(relativePath("data/clean/poloniex_account_overview.RDS")))
}
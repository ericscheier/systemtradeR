cancelOpenLoanOffers <- function(currencies=NULL){
  print(paste0("Canceling open loan offers for ",paste0(currencies, collapse = " ")))
  open.offers <- returnOpenLoanOffers()
  for(currency in names(open.offers)){
    if(currency %in% currencies){
      offers <- open.offers[[currency]]
      for(offer in offers){
        offer.number <- offer$id
        if (!is.null(offer.number)){
          result <- cancelLoanOffer(orderNumber=offer.number)
          print(result$message)
          Sys.sleep(0.2)
        }
      }
    }
  }
}

lending.currency <- "BTC"

refreshLoans <- function(lending.currency=NULL){
  max.lending.balance <- 0.085
  max.length <- 2
  dust.percent.min <- 0.075 #5%
  dust.percent.max <- 1 - dust.percent.min
  order.distributions <- 5 # number of orders to place
  max.lending.rate <- .05
  satoshi <- 10^-8
  
  
  cancelOpenLoanOffers(currencies = lending.currency)
  
  active.provided.loans <- ldply(returnActiveLoans()$provided, data.frame, stringsAsFactors=F)
  if(nrow(active.provided.loans) > 0){
    current.lending.balance <- sum(as.numeric(active.provided.loans$amount))
  } else {
    current.lending.balance <- 0
  }
  
  balance.to.lend <- max(0,max.lending.balance - current.lending.balance)
  print(paste0(balance.to.lend," ",lending.currency," to lend"))
  loan.offers <- c()
  if(balance.to.lend){
    lending.book <- returnLoanOrders(currency=lending.currency)
    open.offers <- ldply(lending.book$offers, data.frame, stringsAsFactors=F)
    open.offers <- open.offers[open.offers$rangeMin<=max.length,]
    open.offers$amount <- as.numeric(open.offers$amount)
    open.offers$rate <- as.numeric(open.offers$rate)
    # open.demands <- ldply(lending.book$demands, data.frame, stringsAsFactors=F)
    # open.demands <- open.demands[open.demands$rangeMin<=max.length,]
    # if(!is.null(open.demands) && nrow(open.demands) > 0){
    #   
    # }
    # offer.range <- quantile(as.numeric(open.offers$rate), c(dust.percent.min, dust.percent.max))
    offer.range.min <- open.offers$rate[min(which(cumsum(open.offers$amount)>=quantile(cumsum(open.offers$amount), dust.percent.min)))] - satoshi
    offer.range.max <- open.offers$rate[min(which(cumsum(open.offers$amount)>=quantile(cumsum(open.offers$amount), dust.percent.max)))] - satoshi
    offers.to.make <- data.frame(lending.rate=seq(from=offer.range.max,
                                                  to=min(max.lending.rate,offer.range.max),
                                                  length.out = order.distributions),
                                 amount = round(rep(balance.to.lend/order.distributions, order.distributions), -log10(satoshi)))
    for(i in 1:nrow(offers.to.make)){
      offer.row <- offers.to.make[i,]
      offer.response <- createLoanOffer(currency=lending.currency, amount=offer.row[,"amount"], duration=2,
                                        autoRenew=0, lendingRate=offer.row[,"lending.rate"])
      print(offer.response)
      loan.offers <- c(loan.offers, offer.response$orderID)
      Sys.sleep(.2)
    }
  } else {
    print("nothing to lend")
  }
  return(loan.offers)
}



# cancelLoanOffer(orderNumber=NULL)

getMaturityCurve <- function(currency=NULL){
  # for determining when I will have my cash back in order to optimize cash flow in margin and exchange
}

loans.offered <- refreshLoans(lending.currency = lending.currency)
open.loan.offers <- ldply(returnOpenLoanOffers(), function(x) ldply(x, data.frame, stringsAsFactors=F), .id="currency")

api.coinbase <- function(command, args = list()) {
  key <- system.config$coinbase.key
  secret <- system.config$coinbase.secret
  
  req <- c(list(
    command = command,
    nonce = round(as.numeric(Sys.time()) * 1e4, 0)),
    args)
  
  ret <- POST("https://poloniex.com/tradingApi",
              add_headers(key=key, sign=hmac(secret, httr:::compose_query(req), "sha512")),
              body = req,
              encode = "form")
  stop_for_status(ret)
  return(content(ret))
}

api.coinbase.public <- function(command){
  req <- paste0("https://poloniex.com/public?command=",command)
  ret <- POST(req)
  stop_for_status(ret)
  return(content(ret))
}

returnOpenOrders <- function(currency.pair="all"){
  command <- "returnOpenOrders"
  # Returns your open orders for a given market,
  # specified by the "currencyPair" POST parameter, e.g. "BTC_XCP".
  # Set "currencyPair" to "all" to return open orders for all markets.
  # 
  # Sample output for single market:
  #   
  #   [{"orderNumber":"120466","type":"sell","rate":"0.025","amount":"100","total":"2.5"},{"orderNumber":"120467","type":"sell","rate":"0.04","amount":"100","total":"4"}, ... ]
  # 
  # Or, for all markets:
  #   
  # {"BTC_1CR":[],"BTC_AC":[{"orderNumber":"120466","type":"sell","rate":"0.025","amount":"100","total":"2.5"},{"orderNumber":"120467","type":"sell","rate":"0.04","amount":"100","total":"4"}], ... }
  config.specs <- list("currencyPair"=currency.pair)
  
  open.orders <- api.coinbase(command=command, args=config.specs)
  return(open.orders)
}

returnBalances <- function(){
  # returnBalances
  # Returns all of your available balances. Sample output:
  #   
  # {"BTC":"0.59098578","LTC":"3.31117268", ... }
  command <- "returnBalances"
  
  balances <- api.coinbase(command=command)
  return(balances)
}

returnCompleteBalances <- function(account="exchange"){
  command <- "returnCompleteBalances"
  # Returns all of your balances, including available balance, balance on orders, and the estimated BTC value of your balance.
  # By default, this call is limited to your exchange account; set the "account" POST parameter to "all" to include your margin and lending accounts. Sample output:
  #   
  # {"LTC":{"available":"5.015","onOrders":"1.0025","btcValue":"0.078"},"NXT:{...} ... }
  config.specs <- list(account=account)
  balances <- api.coinbase(command=command, args=config.specs)
  return(balances)
}

returnTradeHistory <- function(currency.pair="all"){
  command <- "returnTradeHistory"
  # Returns your trade history for a given market, specified by the "currencyPair" POST parameter.
  # You may specify "all" as the currencyPair to receive your trade history for all markets.
  # You may optionally specify a range via "start" and/or "end" POST parameters, given in UNIX timestamp format;
  # if you do not specify a range, it will be limited to one day.
  # Sample output:
  #   
  #   [{ "globalTradeID": 25129732, "tradeID": "6325758", "date": "2016-04-05 08:08:40", "rate": "0.02565498", "amount": "0.10000000", "total": "0.00256549", "fee": "0.00200000", "orderNumber": "34225313575", "type": "sell", "category": "exchange" }, { "globalTradeID": 25129628, "tradeID": "6325741", "date": "2016-04-05 08:07:55", "rate": "0.02565499", "amount": "0.10000000", "total": "0.00256549", "fee": "0.00200000", "orderNumber": "34225195693", "type": "buy", "category": "exchange" }, ... ]
  # 
  # Or, for all markets:
  #   
  # {"BTC_MAID": [ { "globalTradeID": 29251512, "tradeID": "1385888", "date": "2016-05-03 01:29:55", "rate": "0.00014243", "amount": "353.74692925", "total": "0.05038417", "fee": "0.00200000", "orderNumber": "12603322113", "type": "buy", "category": "settlement" }, { "globalTradeID": 29251511, "tradeID": "1385887", "date": "2016-05-03 01:29:55", "rate": "0.00014111", "amount": "311.24262497", "total": "0.04391944", "fee": "0.00200000", "orderNumber": "12603319116", "type": "sell", "category": "marginTrade" }, ... ],"BTC_LTC":[ ... ] ... }
  
  config.specs <- list(currencyPair=currency.pair)
  trade.history <- api.coinbase(command=command, args=config.specs)
  return(trade.history)
}

cancelOrder <- function(order.number=NULL){
  command <- "cancelOrder"
  # Cancels an order you have placed in a given market. Required POST parameter is "orderNumber". If successful, the method will return:
  #   
  # {"success":1}
  
  config.specs <- list(orderNumber=order.number)
  command.result <- api.coinbase(command=command, args=config.specs)
  return(command.result)
}

buy <- function(currency.pair=NULL, rate=NULL, amount=NULL, fillOrKill=0, immediateOrCancel=0, postOnly=0){
  command <- "buy"
  # Places a limit buy order in a given market. Required POST parameters are "currencyPair", "rate", and "amount".
  # If successful, the method will return the order number. Sample output:
  #   
  # {"orderNumber":31226040,"resultingTrades":[{"amount":"338.8732","date":"2014-10-18 23:03:21","rate":"0.00000173","total":"0.00058625","tradeID":"16164","type":"buy"}]}
  # 
  # You may optionally set "fillOrKill", "immediateOrCancel", "postOnly" to 1.
  # A fill-or-kill order will either fill in its entirety or be completely aborted.
  # An immediate-or-cancel order can be partially or completely filled, but any portion of the order that cannot be filled immediately will be canceled rather than left on the order book.
  # A post-only order will only be placed if no portion of it fills immediately; this guarantees you will never pay the taker fee on any part of the order that fills.
  config.specs <- list(currencyPair=currency.pair, rate=rate, amount=amount
                       , fillOrKill=fillOrKill, immediateOrCancel=immediateOrCancel, postOnly=postOnly)
  command.result <- api.coinbase(command=command, args=config.specs)
  return(command.result)
}

sell <- function(currency.pair=NULL, rate=NULL, amount=NULL, fillOrKill=0, immediateOrCancel=0, postOnly=0){
  command <- "sell"
  # Places a sell order in a given market. Parameters and output are the same as for the buy method.
  # Places a limit buy order in a given market. Required POST parameters are "currencyPair", "rate", and "amount".
  # If successful, the method will return the order number. Sample output:
  #   
  # {"orderNumber":31226040,"resultingTrades":[{"amount":"338.8732","date":"2014-10-18 23:03:21","rate":"0.00000173","total":"0.00058625","tradeID":"16164","type":"buy"}]}
  # 
  # You may optionally set "fillOrKill", "immediateOrCancel", "postOnly" to 1.
  # A fill-or-kill order will either fill in its entirety or be completely aborted.
  # An immediate-or-cancel order can be partially or completely filled, but any portion of the order that cannot be filled immediately will be canceled rather than left on the order book.
  # A post-only order will only be placed if no portion of it fills immediately; this guarantees you will never pay the taker fee on any part of the order that fills.
  config.specs <- list(currencyPair=currency.pair, rate=rate, amount=amount
                       , fillOrKill=fillOrKill, immediateOrCancel=immediateOrCancel, postOnly=postOnly)
  command.result <- api.coinbase(command=command, args=config.specs)
  return(command.result)
}

returnMarginAccountSummary <- function(){
  command <- "returnMarginAccountSummary"
  # Returns a summary of your entire margin account. This is the same information you will find in the Margin Account section of the Margin Trading page, under the Markets list. Sample output:
  #   
  # {"totalValue": "0.00346561","pl": "-0.00001220","lendingFees": "0.00000000","netValue": "0.00345341","totalBorrowedValue": "0.00123220","currentMargin": "2.80263755"}
  command.result <- api.coinbase(command=command)
  return(command.result)
}

getMarginPosition <- function(currency.pair="all"){
  command <- "getMarginPosition"
  # Returns information about your margin position in a given market, specified by the "currencyPair" POST parameter.
  # You may set "currencyPair" to "all" if you wish to fetch all of your margin positions at once.
  # If you have no margin position in the specified market, "type" will be set to "none".
  # "liquidationPrice" is an estimate, and does not necessarily represent the price at which an actual forced liquidation will occur.
  # If you have no liquidation price, the value will be -1. Sample output:
  #   
  # {"amount":"40.94717831","total":"-0.09671314",""basePrice":"0.00236190","liquidationPrice":-1,"pl":"-0.00058655", "lendingFees":"-0.00000038","type":"long"}
  
  config.specs <- list(currencyPair=currency.pair)
  command.result <- api.coinbase(command=command, args=config.specs)
  return(command.result)
}

marginBuy <- function(currency.pair=NULL, rate=0.02, amount=0, lending.rate=0.02){
  command <- "marginBuy"
  # Places a margin buy order in a given market.
  # Required POST parameters are "currencyPair", "rate", and "amount".
  # You may optionally specify a maximum lending rate using the "lendingRate" parameter.
  # If successful, the method will return the order number and any trades immediately resulting from your order. Sample output:
  #   
  # {"success":1,"message":"Margin order placed.","orderNumber":"154407998","resultingTrades":{"BTC_DASH":[{"amount":"1.00000000","date":"2015-05-10 22:47:05","rate":"0.01383692","total":"0.01383692","tradeID":"1213556","type":"buy"}]}}
  
  config.specs <- list(currencyPair=currency.pair, rate=rate, amount=amount, lendingRate=lending.rate)
  command.result <- api.coinbase(command=command, args=config.specs)
  return(command.result)
}

marginSell <- function(currency.pair=NULL, rate=0.02, amount=0, lending.rate=0.02){
  command <- "marginSell"
  # Places a margin sell order in a given market. Parameters and output are the same as for the marginBuy method.
  
  config.specs <- list(currencyPair=currency.pair, rate=rate, amount=amount, lendingRate=lending.rate)
  command.result <- api.coinbase(command=command, args=config.specs)
  return(command.result)
}

returnTicker <- function(){
  command <- "returnTicker"
  # Returns the ticker for all markets. Sample output:
  #   
  # {"BTC_LTC":{"last":"0.0251","lowestAsk":"0.02589999","highestBid":"0.0251","percentChange":"0.02390438",
  #   "baseVolume":"6.16485315","quoteVolume":"245.82513926"},"BTC_NXT":{"last":"0.00005730","lowestAsk":"0.00005710",
  #     "highestBid":"0.00004903","percentChange":"0.16701570","baseVolume":"0.45347489","quoteVolume":"9094"}, ... }
  # 
  # Call: https://poloniex.com/public?command=returnTicker
  command.result <- api.poloniex.public(command)
  return(command.result)
}
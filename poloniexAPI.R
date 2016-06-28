library(jsonlite)
library(httr)
library(digest)

api.poloniex <- function(command, args = list()) {
  key <- "O2NT3UJT-04WVU41J-52ETHGHN-WCGM7DUM"
  secret <- "6dfb2b35a571a745a6190cbf6989b7d52409dbf6f40541fc8823c725b1c352fa2b04edceba44d37cb7c216c6f2a062fc538a3119abcbe8e317f8eee32165168d"
  
  req <- c(list(
    command = command,
    nonce = round(as.numeric(Sys.time()) * 1e4, 0)),
    args)
  
  ret <- POST("https://poloniex.com/tradingApi",
              add_headers(key=key, sign=hmac(secret, httr:::compose_query(req), "sha512")),
              body = req,
              encode = "form")
  stop_for_status(ret)
  content(ret)
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
  
  open.orders <- api.poloniex(command=command, args=config.specs)
  return(open.orders)
}

returnBalances <- function(){
  # returnBalances
  # Returns all of your available balances. Sample output:
  #   
  # {"BTC":"0.59098578","LTC":"3.31117268", ... }
  command <- "returnBalances"
  
  balances <- api.poloniex(command=command)
  return(balances)
}

returnCompleteBalances <- function(account="exchange"){
  command <- "returnCompleteBalances"
  # Returns all of your balances, including available balance, balance on orders, and the estimated BTC value of your balance.
  # By default, this call is limited to your exchange account; set the "account" POST parameter to "all" to include your margin and lending accounts. Sample output:
  #   
  # {"LTC":{"available":"5.015","onOrders":"1.0025","btcValue":"0.078"},"NXT:{...} ... }
  config.specs <- list(account=account)
  balances <- api.poloniex(command=command, args=config.specs)
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
  trade.history <- api.poloniex(command=command, args=config.specs)
  return(trade.history)
}

cancelOrder <- function(order.number=NULL){
  command <- "cancelOrder"
  # Cancels an order you have placed in a given market. Required POST parameter is "orderNumber". If successful, the method will return:
  #   
  # {"success":1}
  
  config.specs <- list(orderNumber=order.number)
  command.result <- api.poloniex(command=command, args=config.specs)
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
  command.result <- api.poloniex(command=command, args=config.specs)
  return(command.result)
}
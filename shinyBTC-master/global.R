suppressPackageStartupMessages({
  library(Rbitcoin)
  library(shiny)
  library(rmarkdown)
})

# welcome page
about.html <- render("about.Rmd",quiet=TRUE)

# perform market api call
perform_call <- function(input){
  market <- input$Imarket
  currency_pair <- input$Icurrency_pair
  action <- input$Iaction
  # auth
  if(action %in% c('wallet','open_orders','place_limit_order','cancel_order')){
    key <- input$Iapi_key
    secret <- input$Iapi_secret
    client_id <- input$Iapi_client_id # bitstamp only
  }
  
  # launch call
  switch(
    action,
    "ticker"= market.api.process(market, split_cp(currency_pair),action),
    "order_book" = market.api.process(market, split_cp(currency_pair),action),
    "wallet" = {
      if(market=='bitstamp') market.api.process(market, action = action, key = key, secret = secret, client_id = client_id)
      else market.api.process(market, action = action, key = key, secret = secret)
    },
    "open_orders" = {
      if(market=='bitstamp') market.api.process(market, action = action, key = key, secret = secret, client_id = client_id)
      else market.api.process(market, action = action, key = key, secret = secret)
    },
    "place_limit_order" = {
      if(is.null(input$Itype)) stop("missing 'type' param to place_limit_order action")
      if(is.na(input$Iprice)) stop("missing 'price' param to place_limit_order action")
      if(is.na(input$Iamount)) stop("missing 'amount' param to place_limit_order action")
      req <- list(type = input$Itype, amount = input$Iamount, price = input$Iprice)
      if(market=='bitstamp') market.api.process(market, split_cp(currency_pair), action, req = req, key = key, secret = secret, client_id = client_id)
      else market.api.process(market, split_cp(currency_pair), action, req = req, key = key, secret = secret)
    },
    "cancel_order" = {
      if(input$Ioid=="") stop("missing 'oid' (order id) param to cancel_order action")
      req <- list(oid = input$Ioid)
      if(market=='bitstamp') market.api.process(market, action = action, req = req, key = key, secret = secret, client_id = client_id)
      else market.api.process(market, action = action, req = req, key = key, secret = secret)
    },
    "trades" = {
      if(input$Itid=="") market.api.process(market, split_cp(currency_pair), action)
      else market.api.process(market, split_cp(currency_pair), action, req = list(tid = input$Itid))
    },
    stop(paste0("action ",action," not supported in shinyBTC:::perform_call, edit global.R file, extend `switch` for new option."))
  )
}

# wallet manager related
wallet_manager_dummy_data <- function(){
  structure(
    list(wallet_id = c(1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L,1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1396310400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1398902400L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1401580800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1404172800L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1406851200L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L, 1409529600L),
         currency = c("BTC", "BTC", "BTC", "BTC", "BTC", "EUR", "EUR", "EUR", "EUR", "GBP", "LTC", "LTC", "LTC", "USD", "USD", "USD", "USD", "USD", "BTC", "BTC", "BTC", "BTC", "BTC", "EUR", "EUR", "EUR", "EUR", "GBP", "LTC", "LTC", "LTC", "USD", "USD", "USD", "USD", "USD", "BTC", "BTC", "BTC", "BTC", "BTC", "EUR", "EUR", "EUR", "EUR", "GBP", "LTC", "LTC", "LTC", "USD", "USD", "USD", "USD", "USD", "BTC", "BTC", "BTC", "BTC", "BTC", "EUR", "EUR", "EUR", "EUR", "GBP", "LTC", "LTC", "LTC", "USD", "USD", "USD", "USD", "USD", "BTC", "BTC", "BTC", "BTC", "BTC", "EUR", "EUR", "EUR", "EUR", "GBP", "LTC", "LTC", "LTC", "USD", "USD", "USD", "USD", "USD", "BTC", "BTC", "BTC", "BTC", "BTC", "EUR", "EUR", "EUR", "EUR", "GBP", "LTC", "LTC", "LTC", "USD", "USD", "USD", "USD", "USD"),
         currency_type = c("crypto", "crypto", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat", "crypto", "crypto", "crypto", "fiat", "fiat", "fiat", "fiat", "fiat"),
         auth = c("john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "jane smith", "john smith", "jane smith", "jane smith", "john smith", "john smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "jane smith", "john smith", "jane smith", "jane smith", "john smith", "john smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "jane smith", "john smith", "jane smith", "jane smith", "john smith", "john smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "jane smith", "john smith", "jane smith", "jane smith", "john smith", "john smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "jane smith", "john smith", "jane smith", "jane smith", "john smith", "john smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "john smith", "john smith", "jane smith", "jane smith", "john smith", "jane smith", "jane smith", "john smith", "john smith", "john smith", "john smith", "jane smith"),
         timestamp = structure(c(1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1396310400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1398902400, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1401580800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1404172800, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1406851200, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600, 1409529600), class = c("POSIXct", "POSIXt"), tzone = "UTC"),
         location = c("bitfinex", "kraken", "kraken", "btce", "15Mb2QcgF3XDMeVn6M7oCG6CQLw4mkedDi", "fidor", "fidor", "kraken", "kraken", "fidor", "kraken", "kraken", "btce", "fidor", "bitfinex", "kraken", "btce", "btce", "bitfinex", "kraken", "kraken", "btce", "15Mb2QcgF3XDMeVn6M7oCG6CQLw4mkedDi", "fidor", "fidor", "kraken", "kraken", "fidor", "kraken", "kraken", "btce", "fidor", "bitfinex", "kraken", "btce", "btce", "bitfinex", "kraken", "kraken", "btce", "15Mb2QcgF3XDMeVn6M7oCG6CQLw4mkedDi", "fidor", "fidor", "kraken", "kraken", "fidor", "kraken", "kraken", "btce", "fidor", "bitfinex", "kraken", "btce", "btce", "bitfinex", "kraken", "kraken", "btce", "15Mb2QcgF3XDMeVn6M7oCG6CQLw4mkedDi", "fidor", "fidor", "kraken", "kraken", "fidor", "kraken", "kraken", "btce", "fidor", "bitfinex", "kraken", "btce", "btce", "bitfinex", "kraken", "kraken", "btce", "15Mb2QcgF3XDMeVn6M7oCG6CQLw4mkedDi", "fidor", "fidor", "kraken", "kraken", "fidor", "kraken", "kraken", "btce", "fidor", "bitfinex", "kraken", "btce", "btce", "bitfinex", "kraken", "kraken", "btce", "15Mb2QcgF3XDMeVn6M7oCG6CQLw4mkedDi", "fidor", "fidor", "kraken", "kraken", "fidor", "kraken", "kraken", "btce", "fidor", "bitfinex", "kraken", "btce", "btce"),
         location_type = c("market", "market", "market", "market", "blockchain", "bank", "bank", "market", "market", "bank", "market", "market", "market", "bank", "market", "market", "market", "market", "market", "market", "market", "market", "blockchain", "bank", "bank", "market", "market", "bank", "market", "market", "market", "bank", "market", "market", "market", "market", "market", "market", "market", "market", "blockchain", "bank", "bank", "market", "market", "bank", "market", "market", "market", "bank", "market", "market", "market", "market", "market", "market", "market", "market", "blockchain", "bank", "bank", "market", "market", "bank", "market", "market", "market", "bank", "market", "market", "market", "market", "market", "market", "market", "market", "blockchain", "bank", "bank", "market", "market", "bank", "market", "market", "market", "bank", "market", "market", "market", "market", "market", "market", "market", "market", "blockchain", "bank", "bank", "market", "market", "bank", "market", "market", "market", "bank", "market", "market", "market", "market"),
         amount = c(0, 0.15, 0, 0, 0.1, 190, 130, 40, 80, 110, 0, 4, 1, 275, 25, 10, 30, 30, 0, 0.15, 0, 0, 0.1, 10, 0, 170, 260, 0, 0, 4, 1, 0, 100, 110, 130, 205, 0.22, 0.6, 0.45, 0.3, 0.1, 10, 10, 0, 40, 15, 10, 8, 10.5, 0, 0, 5, 15, 105, 0.12, 0.1, 0.45, 0.3, 0.7, 10, 20, 0, 40, 105, 10, 0, 18.5, 0, 0, 5, 0, 5, 0, 0.1, 0.2, 0, 0.15, 10, 20, 0, 140, 105, 10, 5, 0, 0, 400, 5, 225, 160, 0.4, 0.1, 0.6, 0.4, 0.55, 10, 20, 0, 0, 105, 10, 5, 35, 0, 0, 5, 50, 15),
         value_currency = c("USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD", "USD"),
         value_rate = c(478.98, 478.98, 478.98, 478.98, 478.98, 1.380905, 1.380905, 1.380905, 1.380905, 1.674109, 13.24, 13.24, 13.24, 1, 1, 1, 1, 1, 460.97, 460.97, 460.97, 460.97, 460.97, 1.373171, 1.373171, 1.373171, 1.373171, 1.68398, 11.02, 11.02, 11.02, 1, 1, 1, 1, 1, 630.99, 630.99, 630.99, 630.99, 630.99, 1.359912, 1.359912, 1.359912, 1.359912, 1.691485, 11.04, 11.04, 11.04, 1, 1, 1, 1, 1, 638.25, 638.25, 638.25, 638.25, 638.25, 1.353611, 1.353611, 1.353611, 1.353611, 1.70729, 7.83, 7.83, 7.83, 1, 1, 1, 1, 1, 589.59, 589.59, 589.59, 589.59, 589.59, 1.331674, 1.331674, 1.331674, 1.331674, 1.669659, 7.67, 7.67, 7.67, 1, 1, 1, 1, 1, 474.54, 474.54, 474.54, 474.54, 474.54, 1.288716, 1.288716, 1.288716, 1.288716, 1.629786, 4.7, 4.7, 4.7, 1, 1, 1, 1, 1),
         value = c(0, 71.847, 0, 0, 47.898, 262.37195, 179.51765, 55.2362, 110.4724, 184.15199, 0, 52.96, 13.24, 275, 25, 10, 30, 30, 0, 69.1455, 0, 0, 46.097, 13.73171, 0, 233.43907, 357.02446, 0, 0, 44.08, 11.02, 0, 100, 110, 130, 205, 138.8178, 378.594, 283.9455, 189.297, 63.099, 13.59912, 13.59912, 0, 54.39648, 25.372275, 110.4, 88.32, 115.92, 0, 0, 5, 15, 105, 76.59, 63.825, 287.2125, 191.475, 446.775, 13.53611, 27.07222, 0, 54.14444, 179.26545, 78.3, 0, 144.855, 0, 0, 5, 0, 5, 0, 58.959, 117.918, 0, 88.4385, 13.31674, 26.63348, 0, 186.43436, 175.314195, 76.7, 38.35, 0, 0, 400, 5, 225, 160, 189.816, 47.454, 284.724, 189.816, 260.997, 12.88716, 25.77432, 0, 0, 171.12753, 47, 23.5, 164.5, 0, 0, 5, 50, 15)),
    .Names = c("wallet_id", "currency", "currency_type", "auth", "timestamp", "location", "location_type", "amount", "value_currency", "value_rate", "value"),
    row.names = c(NA, -108L),
    class = c("data.table", "data.frame"),
    sorted = c("wallet_id", "currency")
  )
}

# wallet_archive_load
load_wallet_archive <- function(archive_path = getOption("shinyBTC.wallet_manager.archive_path")){
  if(is.null(archive_path)) return(wallet_manager_dummy_data())
  if(file.exists(archive_path)) wallet_manager(archive_write=FALSE, archive_read=TRUE, archive_path=archive_path) else wallet_manager_dummy_data()
}
wallet_dt <- load_wallet_archive()

# action order drop-down
action_order <- c("ticker","trades","order_book","wallet","place_limit_order","open_orders","cancel_order")

# helper split "BTCUSD" to c("BTC","USD")
split_cp <- function(currency_pair) c(substr(currency_pair,1,3),substr(currency_pair,4,6))

# opts
options("shinyBTC.trunc.char"=10) # wallet_manager location truncate after N chars

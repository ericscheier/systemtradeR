# https://www.kraken.com/help/api
# 
# https://www.kraken.com/help/api#private-user-funding

api.kraken <- function(url, args = list()) {
  key <- system.config$kraken.key
  secret <- system.config$kraken.secret
  
  req <- c(list(
    nonce = round(as.numeric(Sys.time()) * 1e4, 0)),
    args)
  
  ret <- POST(url,
              add_headers(key=key, sign=hmac(secret, httr:::compose_query(req), "sha512")),
              body = req,
              encode = "form")
  stop_for_status(ret)
  return(content(ret)$result)
  # return(ret)
}

getServerTime.kraken <- function(){
#   Get server time
  url <- "https://api.kraken.com/0/public/Time"
#   
#   Result: Server's time
# 
# unixtime =  as unix timestamp
# rfc1123 = as RFC 1123 time format
# Note: This is to aid in approximating the skew time between the server and client.
  # command <- "Time"
  config.specs <- list()
  server.time <- api.kraken(url=url, args=config.specs)
  return(server.time)
}

getTradeablePairs.kraken <- function(info="info", pair=NULL){
  # Get tradable asset pairs
  url <- "https://api.kraken.com/0/public/AssetPairs"
  # 
  # Input:
  #   
  #   info = info to retrieve (optional):
  #   info = all info (default)
  # leverage = leverage info
  # fees = fees schedule
  # margin = margin info
  # pair = comma delimited list of asset pairs to get info on (optional.  default = all)
  # Result: array of pair names and their info
  # 
  # <pair_name> = pair name
  # altname = alternate pair name
  # aclass_base = asset class of base component
  # base = asset id of base component
  # aclass_quote = asset class of quote component
  # quote = asset id of quote component
  # lot = volume lot size
  # pair_decimals = scaling decimal places for pair
  # lot_decimals = scaling decimal places for volume
  # lot_multiplier = amount to multiply lot volume by to get currency volume
  # leverage_buy = array of leverage amounts available when buying
  # leverage_sell = array of leverage amounts available when selling
  # fees = fee schedule array in [volume, percent fee] tuples
  # fees_maker = maker fee schedule array in [volume, percent fee] tuples (if on maker/taker)
  # fee_volume_currency = volume discount currency
  # margin_call = margin call level
  # margin_stop = stop-out/liquidation margin level
  # Note: If an asset pair is on a maker/taker fee schedule, the taker side is given in "fees" and maker side in "fees_maker". For pairs not on maker/taker, they will only be given in "fees".
  pair <- pairToISO(pair)
  
  config.specs <- list(info=info, pair=pair)
  tradeable.pairs <- api.kraken(url=url, args=config.specs)
  return(tradeable.pairs)
  
}

getPairOHLC.kraken <- function(pair=NULL, start.time=NULL, interval=5){
  # Get OHLC data
  url <- "https://api.kraken.com/0/public/OHLC"
  since <- start.time
  # 
  # Input:
  #   
  #   pair = asset pair to get OHLC data for
  # interval = time frame interval in minutes (optional):
  #   1 (default), 5, 15, 30, 60, 240, 1440, 10080, 21600
  # since = return committed OHLC data since given id (optional.  exclusive)
  # Result: array of pair name and OHLC data
  # 
  # <pair_name> = pair name
  # array of array entries(<time>, <open>, <high>, <low>, <close>, <vwap>, <volume>, <count>)
  # last = id to be used as since when polling for new, committed OHLC data
  # Note: the last entry in the OHLC array is for the current, not-yet-committed frame and will always be present, regardless of the value of "since".
  if(!is.null(since)){since <- as.numeric(seconds(as.POSIXct(since, origin = "1970-01-01"))) - interval * 60}
  # print(since)
  iso.pair <- pairToISO(pair)
  config.specs <- list(pair=iso.pair, interval=interval, since=since)
  ohlc.data <- as.data.frame(rbindlist(api.kraken(url=url, args=config.specs)[[iso.pair]]))
  # print(nrow(ohlc.data))
  ohlc.data[,"V1"] <- as.character(as.POSIXct(ohlc.data[,"V1"] - ifelse(interval>=24*60, 5*60, 0), origin="1970-01-01"))
  colnames(ohlc.data) <- c("date", "open", "high", "low", "close", "vwap", "volume", "count")
  return(ohlc.data)
  
}
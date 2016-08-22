library(Quandl)

getQuandlData <- function(symbol){
  start.date="2013-01-01"
  end.date=Sys.Date()
  Quandl(symbol, api_key="-GNvgv_nqBHeqiyEQjyj", start_date=start.date, end_date=end.date, type="xts")
}


USDBTC = getQuandlData("BCHARTS/LAKEUSD") #"BCHARTS/BITSTAMPUSD" has missing data around start of 2015 # or  for farther back
new.usd <- USDBTC[,c("Open", "High", "Low", "Close", "Volume (BTC)")]
colnames(new.usd) <- c("open", "high", "low", "close", "volume")


start <- as.POSIXct(min(index(new.usd)))
interval <- 60 * 5

end <- as.POSIXct(max(index(new.usd)))

new.index <- seq(from=start, by=interval, to=end)

price.history <- xts(NULL, order.by=new.index)
new.price.history <- na.locf(merge(price.history, new.usd), na.rm = TRUE)

new.price.history.df <- as.data.frame(new.price.history)
new.price.history.df$date <- index(new.price.history)
new.price.history.df <- new.price.history.df[,c("date", "open", "high", "low", "close", "volume")]

write.csv(x = new.price.history.df, file = "data/raw/USD_BTC_ohlc.csv", row.names = FALSE)

test.usd <- getPairData(pair="USD_BTC", ohlc = TRUE, volume = TRUE)

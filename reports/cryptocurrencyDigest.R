#packages I want
library(xts)
library(lubridate)
library(PerformanceAnalytics)
library(quantmod)
library(Quandl)
library(WDI)
library(reshape2)

getSymbols("SPY", src="yahoo") # from yahoo finance
getSymbols("GBP/USD",src="oanda") # Platinum from Oanda

getQuandlData <- function(symbol){
  start.date="2013-01-01"
  end.date=Sys.Date()
  Quandl(symbol, api_key="-GNvgv_nqBHeqiyEQjyj", start_date=start.date, end_date=end.date, type="xts")
}

price.history <- list(
  USDBTC = getQuandlData("BCHARTS/COINBASEUSD")[,"Weighted Price",], # or BCHARTS/BITSTAMPUSD for farther back
  SPY = getQuandlData("YAHOO/INDEX_SPY")[,"Adjusted Close"],
  DOW = getQuandlData("YAHOO/INDEX_DJI")[,"Adjusted Close"],
  R2000 = getQuandlData("YAHOO/INDEX_RUT")[,"Adjusted Close"],
  USDGBP = getQuandlData("BUNDESBANK/BBEX3_D_USD_GBP_CA_AC_000"), #USD/GBP
  USDEUR = getQuandlData("BOE/XUDLERD"), #USD/EUR
  JPYUSD = getQuandlData("BUNDESBANK/BBEX3_D_JPY_USD_CA_AC_000")
)
list.names <- names(price.history)
price.history <- do.call(merge, price.history)
names(price.history) <- list.names
# fix a known mistake point by removing it
price.history["2016-03-22","USDGBP"] <- NA

combined.price.history <- na.fill(CalculateReturns(price.history), fill=0)

# Green as highlight
greenfocus = c("#41AB5D", "#252525", "#525252", "#737373", "#969696", "#BDBDBD", "#D9D9D9", "#F0F0F0")
chart.CumReturns(combined.price.history[,rev(list.names)], legend.loc = "topleft", colorset = greenfocus,
                 main="Cumulative Returns of BTC/USD vs. other assets for 2016")

countries <- c('CN', 'US', 'EU', 'JP', 'IN')


mc <- WDI(indicator = 'NY.GDP.MKTP.KD',
          country = countries,
          start = 2014, end = 2014)

countries.long <- mc$country




library(ggplot2) # edit to load these silently
library(httr)
library(jsonlite)

global.crypto <- content(GET("https://api.coinmarketcap.com/v1/global/"))
SPY <- as.xts(getSymbols("SPY"))

crypto.market.cap <- global.crypto$total_market_cap_usd
crypto.trading.vol <- global.crypto$total_24h_volume_usd

market.stats <- data.frame(market=c("Cryptos", countries.long),
                           # stock.value.usd=c(crypto.market.cap,stock.cap$CM.MKT.LCAP.CD),
                           gdp=c(crypto.market.cap, mc$NY.GDP.MKTP.KD))

asset.stats <- data.frame(asset=c("Cryptos","S&P500","DOW","GBP","R2000"),
                          market.cap.bils=c(crypto.market.cap,1,1,1,1)/(10^9),
                          trading.vol.mils=c(crypto.trading.vol,1,1,1,1)/(10^6))
ggplot(data=market.stats, aes(x=market, y=gdp, fill=market)) +
  geom_bar(colour="black", stat="identity") +
  guides(fill=FALSE) + scale_y_log10(name="Log(USD)")

# ggplot(data=market.stats, aes(x=market, y=stock.value.usd, fill=market)) +
#   geom_bar(colour="black", stat="identity") +
#   guides(fill=FALSE)  + scale_y_log10(name="Log(USD)")

ggplot(data=asset.stats, aes(x=asset, y=market.cap.bils, fill=asset)) +
  geom_bar(colour="black", stat="identity") +
  guides(fill=FALSE)

ggplot(data=asset.stats, aes(x=asset, y=trading.vol.mils, fill=asset)) +
  geom_bar(colour="black", stat="identity") +
  guides(fill=FALSE)

https://api.gdax.com
# BTC/candles
content(GET("https://api.coinmarketcap.com/v1/global/products/"))

# Time Series Plotting
library(ggplot2)
# Get IBM and Linkedin stock data from Yahoo Finance
ibm_url <- "http://real-chart.finance.yahoo.com/table.csv?s=IBM&a=07&b=24&c=2010&d=07&e=24&f=2015&g=d&ignore=.csv"
lnkd_url <- "http://real-chart.finance.yahoo.com/table.csv?s=LNKD&a=07&b=24&c=2010&d=07&e=24&f=2015&g=d&ignore=.csv"

yahoo.read <- function(ticker, start.date, end.date){
  start.date <- as.Date(start.date)
  end.date <- as.Date(end.date)
  url <- paste0("http://real-chart.finance.yahoo.com/table.csv?s=",ticker
                ,"&a=",months(start.date),"&b=",days(start.date),"&c=",years(start.date),
                "&d=",months(end.date),"&e=",days(start.date),"&f=",years(start.date),"&g=d&ignore=.csv")
  dat <- read.table(url,header=TRUE,sep=",")
  df <- dat[,c(1,5)]
  df$Date <- as.Date(as.character(df$Date))
  return(df)}

ibm  <- yahoo.read(ibm_url)
lnkd <- yahoo.read(lnkd_url)
price.levels <- merge(x=ibm, y=lnkd, by = c("Date"))
names(price.levels) <- c("Date", "IBM", "LNKD")

ggplot(price.levels, aes(x=Date, y=Price.Level))

ggplot(ibm,aes(Date,Close)) + 
  geom_line(aes(color="ibm")) +
  geom_line(data=lnkd,aes(color="lnkd")) +
  labs(color="Legend") +
  scale_colour_manual("", breaks = c("ibm", "lnkd"),
                      values = c("blue", "brown")) +
  ggtitle("Closing Stock Prices: IBM & Linkedin") + 
  theme(plot.title = element_text(lineheight=.7, face="bold"))

head(ibm)

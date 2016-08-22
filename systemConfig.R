#!/usr/bin/Rscript

source("sources.R")



Sys.setenv(TZ = "UTC")
set_config(timeout(seconds = 30))

slackr_setup(config_file=paste0(getwd(),"/.slackr"))
if(inherits(try(system.config, silent=TRUE), "try-error")){system.config <- new.env(parent = emptyenv())}

#~~~~~!!!!!~~~~#
system.config$live = is.live.machine
#~~~~!!!!!~~~~#
system.config$debug <- TRUE

system.config$forecast.cap <- 20
system.config$volatility.lookback <- 36 #101 #hours
system.config$lookback.hours <- 450*24
system.config$volatility.target <- .005 # hourly target volatility in % terms 
# started at 0.0005
# bumped up 10x to reflect vol of market & underinvestment
system.config$minimum.order.size <- 0.0001 #BTC, true minimum is 0.0001 for order size
system.config$minimum.position.change <- .2 # % position should change before transacting
system.config$transaction.fee <- 0.0025 #% of each transaction

system.config$portfolio.pairs <- getPortfolioPairs()
system.config$portfolio.forecasts <- getPortfolioForecasts()

system.config$poloniex.key <- "O2NT3UJT-04WVU41J-52ETHGHN-WCGM7DUM"
system.config$poloniex.secret <- "6dfb2b35a571a745a6190cbf6989b7d52409dbf6f40541fc8823c725b1c352fa2b04edceba44d37cb7c216c6f2a062fc538a3119abcbe8e317f8eee32165168d"
if(is.null(system.config$poloniex.margin.value)){system.config$poloniex.margin.value <- try(accountValue())}
if(inherits(system.config$poloniex.margin.value, "try-error")){
  margin_account_value <- readRDS("data/clean/margin_account_value.RDS")
  system.config$poloniex.margin.value <- tail(margin_account_value$btc_value,1)}

base <- "BTC"
exchange.rate.prices.path <- paste0(getwd(),"/data/raw/USDT_",base,"_ohlc.csv")
if(!file.exists(exchange.rate.prices.path)){refreshPortfolioPricing()}
exchange.rate.prices <- read.csv(exchange.rate.prices.path, stringsAsFactors = FALSE) # instrument currency / account value currency (USD)

system.config$five.exchange.rate <- xts(x=exchange.rate.prices[,"close"]
                          , order.by = strptime(exchange.rate.prices[,"date"], format="%Y-%m-%d %H:%M:%S")
                          , tzone = "UTC")
# fix missing datapoint, caused by 0 volume in an interval above
# five.exchange.rate["2016-03-06 08:00:00",] <- mean(five.exchange.rate["2016-03-06 07:55:00",], five.exchange.rate["2016-03-06 08:05:00",])


system.config$first.exchange.rate <- index(head(system.config$five.exchange.rate,1))
system.config$last.exchange.rate <- index(tail(system.config$five.exchange.rate,1)) - minutes(10)
system.config$current.exchange.rate <- as.numeric(system.config$five.exchange.rate[system.config$last.exchange.rate])

system.config$volatility.benchmark <- 0.002 # hourly vol (emaVolatility)
system.config$volume.benchmark <- 10 * system.config$poloniex.margin.value #BTC per volatility lookback period


#!/usr/bin/Rscript

source("sources.R")

Sys.setenv(TZ = "UTC")
set_config(timeout(seconds = 30))

slackr_setup(config_file=paste0(getwd(),"/.slackr"))
if(is.null(config)){config <- new.env(parent = emptyenv())}

#~~~~~!!!!!~~~~#
config$live = is.live.machine
#~~~~!!!!!~~~~#

config$volatility.lookback <- 101 #hours
config$volatility.target <- .005 # hourly target volatility in % terms 
# started at 0.0005
# bumped up 10x to reflect vol of market & underinvestment
config$minimum.order.size <- 0.0001 #BTC, true minimum is 0.0001 for order size
config$minimum.position.change <- .1 # % position should change before transacting
config$transaction.fee <- 0.0025 #% of each transaction
config$portfolio.pairs <- getPairs()
config$poloniex.key <- "O2NT3UJT-04WVU41J-52ETHGHN-WCGM7DUM"
config$poloniex.secret <- "6dfb2b35a571a745a6190cbf6989b7d52409dbf6f40541fc8823c725b1c352fa2b04edceba44d37cb7c216c6f2a062fc538a3119abcbe8e317f8eee32165168d"
if(is.null(config$poloniex.margin.value)){try(config$poloniex.margin.value <- accountValue())}

base <- "BTC"
exchange.rate.prices <- read.csv(paste0(getwd(),"/data/raw/USDT_",base,"_ohlc.csv"), stringsAsFactors = FALSE) # instrument currency / account value currency (USD)

config$five.exchange.rate <- xts(x=exchange.rate.prices[,"close"]
                          , order.by = strptime(exchange.rate.prices[,"date"], format="%Y-%m-%d %H:%M:%S")
                          , tzone = "UTC")
# fix missing datapoint, caused by 0 volume in an interval above
# five.exchange.rate["2016-03-06 08:00:00",] <- mean(five.exchange.rate["2016-03-06 07:55:00",], five.exchange.rate["2016-03-06 08:05:00",])


config$first.exchange.rate <- index(head(config$five.exchange.rate,1))
config$last.exchange.rate <- index(tail(config$five.exchange.rate,1)) - minutes(10)
config$current.exchange.rate <- as.numeric(config$five.exchange.rate[config$last.exchange.rate])


if(config$live){slackr_bot(systemMaster())}
if(!config$live){systemMaster()}
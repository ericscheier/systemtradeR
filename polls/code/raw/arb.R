library(jsonlite)
library(pollstR)
require(jsonlite)
require(data.table)
require(forecast)

# get predictit data
ticker <- "OBAMAAPPR.031816" # "RNOM16"
url <- paste0("https://www.predictit.org/api/marketdata/ticker/", ticker)

contract.info <- fromJSON(url)

contracts <- contract.info$Contracts
contracts$ShortName

# get huffpost data


# get RCP data
prez.appr <- as.data.table(fromJSON("http://spinnernicholas.com/rcp/scraper2/json/?p=1"))
# Forecast obama approval rating on RCP

# install.packages("jsonlite")
# reference http://cran.r-project.org/web/packages/jsonlite/index.html
require(jsonlite)
require(data.table)
require(forecast)

prez.appr <- as.data.table(fromJSON("http://spinnernicholas.com/rcp/scraper2/json/?p=1"))
# want to add to my personal stash of this data [feature]


prez.appr[,datetime:=as.POSIXct(strptime(timestamp,format="%F %T"))]
prez.appr[,date:=as.Date(datetime)]
p.a <- prez.appr[,list(approve.max=max(rcp1)
                       ,approve.min=min(rcp1)),by="date"]
# setnames(p.a,"V1","approve")

input.ts <- zoo(x=p.a[,approve.max],order.by=p.a[,date])
fit <- forecast(as.ts(input.ts))
forecast(fit)

# forecast using X previous polls from each sub-poll [feature]
# ^requires function to calculate per poll
# ^calculate for past X (poll-specific factor) for each poll
# ^then shiny implementation is easy (just checkboxes)
# determine probabilities of each block on offer at predictit [feature]
# ^needs to be input to function (as array?)
# ^there is a specific pr(x|y) function to build and apply
# add the kelly criterion for portfolio management [feature]


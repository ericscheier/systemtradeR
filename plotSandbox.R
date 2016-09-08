pair <- "BTC_XMR"
# date.range <- "2016-07-02::2016-07-05"
# period <- "hours" # "seconds", "minutes", "hours", "days", "weeks", "months", "quarters", and "years"
# type <- "line"
depth <- 50
market <- "lending"

pl <- accountAllocationChart(scale.by.total.value = FALSE)
print(pl)
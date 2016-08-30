


shinyUI(fluidPage(
  titlePanel("altfund"),
  sidebarLayout(
    selectInput(inputId="trading.pair", label="Pair", choices=system.config$portfolio.pairs,
                selected = "BTC_XMR", multiple = FALSE,
                selectize = TRUE, width = NULL, size = NULL),
    dateRangeInput(inputId=price.date.range, label="Market prices date range", start="2015-12-01", end=Sys.Date(),
                 min="2014-01-01",max=Sys.Date(), format = "yyyy-mm-dd", startview = "month", weekstart = 0,
                 language = "en", separator = " to ", width = NULL)
    
  ),
  mainPanel(
    plotOutput("market.price.chart")
  )
  textOutput("currentTime")
))
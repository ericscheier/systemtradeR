source("systemConfig.R")
skin <- Sys.getenv("DASHBOARD_SKIN")
skin <- tolower(skin)
if (skin == "")
  skin <- "green"

server <- function(input, output) {
  
  observe({
    refresh.rate <- 30 #seconds
    if(system.config$live){
      invalidateLater(refresh.rate * 1000)
    }
    
    output$market.price.chart <- renderPlot({priceChart(pair=input$trading.pair,
                                                        date.range=paste0(input$price.date.range, collapse = "::"),
                                                        period=input$chart.frequency,
                                                        type="candle")})
    output$order.book.chart <- renderPlot({orderBookChart(pair=input$trading.pair, market=input$order.book.market)})
    
    output$account.value.chart <- renderPlot({accountValueChart()})
    
    output$currency.allocations.chart <- renderPlot({currencyAllocationChart()})
    
    output$account.allocations.chart <- renderPlot({accountAllocationChart(scale.by.total.value = FALSE)})
  })
  
  
}
source("systemConfig.R")

server <- function(input, output) {
  
  observe({
    # refresh.rate <- 60 #seconds
    # if(system.config$live){
    #   invalidateLater(refresh.rate * 1000)
    # }
    
    output$market.price.chart <- renderPlot({priceChart(pair=input$trading.pair,
                                                        date.range=paste0(input$price.date.range, collapse = "::"),
                                                        period=input$chart.frequency,
                                                        type="candle")})
    output$order.book.chart <- renderPlot({orderBookChart(pair=input$trading.pair, market=input$order.book.market)})
    
    output$account.value.chart <- renderPlot({accountValueChart()})
    
    output$currency.allocations.chart <- renderPlot({currencyAllocationChart()})
    
    output$account.allocations.chart <- renderPlot({accountAllocationChart(scale.by.total.value = FALSE)})
    
    output$update.states.table <- renderDataTable({readRDS("update_states.RDS")})
  })
  
  
}
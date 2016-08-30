shinyServer(function(input, output, session) {
  
  
  
  
  output$market.price.chart <- renderPlot()
  
  
  output$currentTime <- renderText({
    invalidateLater(1000, session)
    paste("The current time is", Sys.time())
  })
})
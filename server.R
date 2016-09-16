source("systemConfig.R")

server <- function(input, output, session) {
  
  refresh.rate <- 30 #seconds
  
  output$currentTime <- renderText({
    options(digits.secs = 0)
    
    # invalidateLater causes this output to automatically
    # become invalidated when input$interval milliseconds
    # have elapsed
    invalidateLater(as.integer(refresh.rate * 1000), session)
    
    format(Sys.time())
  })
    # 
    # if(system.config$live){
    #   invalidateLater()
    # }
    
    output$market.price.chart <- renderPlot({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      priceChart(pair=input$trading.pair,
                 date.range=paste0(input$price.date.range, collapse = "::"),
                 period=input$chart.frequency,
                 type="candle")})
    
    output$order.book.chart <- renderPlot({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      orderBookChart(pair=input$trading.pair, market=input$order.book.market)})
    
    output$account.value.chart <- renderPlot({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      accountValueChart()})
    
    output$currency.allocations.chart <- renderPlot({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      currencyAllocationChart()})
    
    output$account.allocations.chart <- renderPlot({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      accountAllocationChart(scale.by.total.value = TRUE)})
    
    output$update.states.table <- renderDataTable({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      readRDS("update_states.RDS")})
    
    output$investment.universe.table <- renderDataTable({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      loadInvestmentUniverse()})
    
    output$current.btc.accounts.table <- renderDataTable({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      loadCurrentBTCAccounts()})
    
    output$optimal.btc.accounts.table <- renderDataTable({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      loadOptimalBTCAccounts()})
    
    output$current.accounts.table <- renderDataTable({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      loadCurrentAccounts()})
    
    output$optimal.accounts.table <- renderDataTable({
      invalidateLater(as.integer(refresh.rate * 1000), session)
      loadOptimalAccounts()})
  
  
}
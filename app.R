source("systemConfig.R")
skin <- Sys.getenv("DASHBOARD_SKIN")
skin <- tolower(skin)
if (skin == "")
  skin <- "green"

header <- dashboardHeader(title = "altfund")

sidebar <- dashboardSidebar(
  dashboardSidebar(
    sidebarMenu(id="menu",
                menuItem("Markets", tabName = "markets", icon = icon("dashboard")),
                menuItem("Portfolio", tabName = "portfolio", icon = icon("th")),
                menuItem("Bot", tabName = "bot", icon = icon("bar-chart-o"))
    )
  )
)

body <- dashboardBody(
  tabItems(
    tabItem("markets",
  fluidRow(
    box(
      title = "Market Prices",
      status = "primary",
      plotOutput("market.price.chart", width="100%"),
      # height = 500,
      width = 10
    )
  ),
  fluidRow(
    box(
      title = "Price Chart control",
      width = 5, solidHeader = TRUE, status = "warning",
      selectInput(inputId="trading.pair", label="Pair", choices=system.config$portfolio.pairs,
                  selected = "BTC_XMR", multiple = FALSE,
                  selectize = TRUE, width = NULL, size = NULL),
      selectInput(inputId="chart.frequency", label="Frequency", choices=c("hours", "days", "weeks", "months", "quarters", "years"),
                  selected = "hours", multiple = FALSE,
                  selectize = TRUE, width = NULL, size = NULL),
      #c(bar, candle, line)
      dateRangeInput(inputId="price.date.range",
                     label="Date Range",
                     start=Sys.Date() - weeks(2),
                     end=Sys.Date(),
                     min="2014-01-01",max=Sys.Date(), format = "yyyy-mm-dd", startview = "month", weekstart = 0,
                     language = "en", separator = " to ", width = NULL),
      selectInput(inputId="order.book.market", label="Order Book", choices=c("exchange","lending","margin"),
                  selected = "exchange", multiple = FALSE,
                  selectize = TRUE, width = NULL, size = NULL),
      checkboxInput(inputId="overlay.orders",label="Overlay My Orders",value=TRUE)
    ),
    box(title="Order Book",
           # height = 300,
        plotOutput("order.book.chart")
    )
  )
  
  ),
  tabItem("portfolio",
          fluidRow(
            box(title="Account Value",
                plotOutput("account.value.chart")),
            box(title="Currency Allocations",
                plotOutput("currency.allocations.chart"))
          ),
          fluidRow(
            box(title="Account Allocations",
                plotOutput("account.allocations.chart"),
                width=12)
          )
          )
  # tabItem("bot")
  )
)

ui <- dashboardPage(header, sidebar, body, skin=skin)

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

shinyApp(ui, server)
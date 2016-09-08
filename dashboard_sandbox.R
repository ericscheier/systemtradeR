source("systemConfig.R")
skin <- Sys.getenv("DASHBOARD_SKIN")
skin <- tolower(skin)
if (skin == "")
  skin <- "green"

header <- dashboardHeader(title = "Dynamic sidebar")

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
                               language = "en", separator = " to ", width = NULL)
              ),
              tabBox(id="order.book.market",#title="Order Books",
                     height = 300,
                     tabPanel("Exchange",value="exchange",
                              textOutput("order.book.chart")
                              # plotOutput("order.book.chart")
                     ),
                     tabPanel("Margin",value="margin",
                              textOutput("order.book.chart")
                              # plotOutput("order.book.chart")
                     )#,
                     # tabPanel("Lending",value="lending",
                     #          plotOutput("order.book.chart"))
              )
            )
           
    # ),
    # tabItem("portfolio"),
    # tabItem("bot")
  # )
)

ui <- dashboardPage(header, sidebar, body, skin=skin)

server <- function(input, output) {
  
  output$market.price.chart <- renderPlot({priceChart(pair=input$trading.pair,
                                                     date.range=paste0(input$price.date.range, collapse = "::"),
                                                     period=input$chart.frequency,
                                                     type="candle")})
  output$order.book.chart <- #renderPlot({orderBookChart(pair=input$trading.pair, market=input$order.book.market)})
    renderText({input$order.book.market})
  
  # set.seed(122)
  # histdata <- rnorm(500)
  # 
  # output$plot1 <- renderPlot({
  #   if (is.null(input$count) || is.null(input$fill))
  #     return()
  #   
  #   data <- histdata[seq(1, input$count)]
  #   color <- input$fill
  #   if (color == "none")
  #     color <- NULL
  #   hist(data, col = color, main = NULL)
  # })
  # 
  # output$scatter1 <- renderPlot({
  #   spread <- as.numeric(input$spread) / 100
  #   x <- rnorm(1000)
  #   y <- x + rnorm(1000) * spread
  #   plot(x, y, pch = ".", col = "blue")
  # })
  # 
  # output$scatter2 <- renderPlot({
  #   spread <- as.numeric(input$spread) / 100
  #   x <- rnorm(1000)
  #   y <- x + rnorm(1000) * spread
  #   plot(x, y, pch = ".", col = "red")
  # })
}

shinyApp(ui, server)
shinyUI(
  navbarPage(
    "shinyBTC",
    tabPanel("about",
             includeHTML(about.html)),
    tabPanel("market API",
             fluidPage(
               sidebarLayout(
                 sidebarPanel(width = 3,
                              selectInput("Imarket", label = "market:", choices = getOption("Rbitcoin.api.dict")[,unique(market)], selected = getOption("Rbitcoin.api.dict")[,market][1]),
                              selectInput("Icurrency_pair", label = "currency pair:", choices = NULL, selected = NULL),
                              selectInput("Iaction", "action:",  choices = NULL, selected = NULL),
                              p("req args:"),
                              conditionalPanel("input.Iaction == 'place_limit_order'",
                                               selectInput("Itype", "type", as.list(c('buy','sell'))),
                                               numericInput("Iprice", "price", value = NA, min = 0, step = 0.0001),
                                               numericInput("Iamount", "amount", value = NA, min = 0, step = 0.0001)),
                              conditionalPanel("input.Iaction == 'cancel_order'",
                                               textInput("Ioid", "order id")),
                              conditionalPanel("input.Iaction == 'trades'",
                                               textInput("Itid", "last tid")),
                              hr(),
                              p("auth args:"),
                              conditionalPanel("input.Iaction == 'place_limit_order' || input.Iaction == 'cancel_order' || input.Iaction == 'open_orders' || input.Iaction == 'wallet'",
                                               textInput("Iapi_key", "API key", "")),
                              conditionalPanel("input.Iaction == 'place_limit_order' || input.Iaction == 'cancel_order' || input.Iaction == 'open_orders' || input.Iaction == 'wallet'",
                                               textInput("Iapi_secret", "API secret", "")),
                              conditionalPanel("input.Imarket == 'bitstamp' && (input.Iaction == 'place_limit_order' || input.Iaction == 'cancel_order' || input.Iaction == 'open_orders' || input.Iaction == 'wallet')",
                                               textInput("Iapi_client_id", "bitstamp API client id", "")),
                              hr(),
                              actionButton("Iapi_call", label = "market API process"),
                              hr(),
                              downloadButton('Ocsv_market_api_res','data.csv')
                 ),
                 mainPanel(
                   wellPanel(
                     conditionalPanel("input.Iaction == 'trades' || input.Iaction == 'order_book'",
                                      plotOutput("Oplot_market_api_res")),
                     hr(),
                     conditionalPanel("input.Iaction != 'order_book'",
                                      dataTableOutput("Odt_market_api_res")),
                     hr(),
                     verbatimTextOutput("Ostr_market_api_res")
                     )
                 )
               ),
               wellPanel(
                 verbatimTextOutput("Oprint_market_api_res")
                 )
             )),
    tabPanel("blockchain API",
             fluidPage(
               sidebarLayout(
                 sidebarPanel(width = 3,
                              textInput("Iblockchain_api_x", label = "address or tx", value = ""),
                              actionButton("Iblockchain_api_call", label = "blockchain API process")
                 ),
                 mainPanel(
                   wellPanel(
                     dataTableOutput("Odt_blockchain_api_res"),
                     hr(),
                     verbatimTextOutput("Ostr_blockchain_api_res")
                     )
                   )
               ),
               wellPanel(
                 verbatimTextOutput("Oprint_blockchain_api_res")
               )
             )),
    tabPanel("wallet manager",
             fluidPage(
               sidebarLayout(
                 sidebarPanel(width = 2,
                              selectInput("Iwallet_manager_plot_type", label = "type", choices = c("value","recent"), selected = "value"),
                              actionButton("Iwallet_manager_plot", label = "plot")
                 ),
                 mainPanel(width = 10,
                           h3("plot"),
                           conditionalPanel("input.Iwallet_manager_plot > 0",
                                            p("Legend may not scale well in shiny App"),
                                            plotOutput("Oplot_wallet_manager", height="auto"))
                 )
               ),
               hr(),
               h3("wallet archive"),
               dataTableOutput("Odt_wallet_manager"),
               hr(),
               h3("recent wallet"),
               verbatimTextOutput("Odt_wallet_manager_recent")
             )),
    tabPanel("options",
             fluidPage(
               titlePanel("Rbitcoin options"),
               fluidRow(
                 column(2, numericInput("Rbitcoin.verbose","Rbitcoin verbose:", value = 1L, min = 0L, max = 10L, step = 1L)),
                 column(2, numericInput("Rbitcoin.antiddos.verbose","Rbitcoin antiddos verbose:", value = 1L, min = 0L, max = 1L, step = 1L))
                 ),
               fluidRow(
                 column(2, numericInput("Rbitcoin.antiddos.sec","Rbitcoin antiddos sec:", value = 10, min = 1, max = 60, step = 1)),
                 column(2, checkboxInput("Rbitcoin.plot.mask","Rbitcoin plot mask", value = FALSE)) # not yet utilized TODO
               ),
               fluidRow(
                 column(2, numericInput("Rbitcoin.plot.limit_pct","Rbitcoin plot order book limit pct:", value = 0.75, min = 0, max = 10, step = 0.01)),
                 column(2, NULL)
               )))
  )
)

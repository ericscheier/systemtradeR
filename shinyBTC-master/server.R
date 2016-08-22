
# tip: start by folding all the sub processes

shinyServer(function(input, output, session){
  
  ### market api
  
  observe({
    market <- input$Imarket
    isolate({
      updateSelectInput(session, 
                        "Icurrency_pair", 
                        choices = getOption("Rbitcoin.api.dict")[market][!is.na(base),list(currency_pair = paste(base,quote,sep=""))][,currency_pair], 
                        selected = getOption("Rbitcoin.api.dict")[market][!is.na(base),list(currency_pair = paste(base,quote,sep=""))][,currency_pair][1])
    })
  }) # update Icurrency_pair
  observe({
    market <- input$Imarket
    currency_pair <- input$Icurrency_pair
    isolate({
      if(nchar(currency_pair)!=6){
        base <- NA_character_; quote <- NA_character_
      }
      else{
        base <- c(NA_character_,substr(currency_pair,1,3)); quote <- c(NA_character_,substr(currency_pair,4,6))
      }
      iq <- bquote(list(.(market), .(base), .(quote)))
      # get available actions for those currencies
      action_rand <- getOption("Rbitcoin.api.dict")[eval(iq),action,nomatch=0]
      # sort actions for market+currency_pair according above action_order defined in global.R
      action_sort <- action_rand[order(match(action_rand,action_order))]
      updateSelectInput(session, 
                        "Iaction", 
                        choices = action_sort, 
                        selected = NULL)
    })
  }) # update Iaction
  
  market_api_res <- reactive({
    validate(need(input$Iapi_call > 0, ""))
    isolate({
      action <- input$Iaction
      invisible(perform_call(input = input))
    })
  }) # perform api call
  
  output$Oprint_market_api_res <- renderPrint({
    input$Iapi_call
    isolate({
      validate(need(input$Iapi_call > 0, ""))
      market_api_res()
      })
  }) # render console log
  
  output$Oplot_market_api_res <- renderPlot({
    input$Iapi_call
    isolate({
      validate(need(input$Iapi_call > 0, ""))
      validate(need(input$Iaction %in% c("order_book","trades"), ""))
      x <- market_api_res()
      tryCatch(rbtc.plot(x, verbose=0), error=function(e) NULL) # no verbose print for plot, bottom panel display only one function call Oprint_market_api_res, tryCatch to easy handle exception error on input switches
    })
  }) # render plot result
  
  market_api_res_dt <- reactive({
    input$Iapi_call
    isolate({
      validate(need(input$Iapi_call > 0, ""))
      validate(need(!(input$Iaction %in% c("order_book")), ""))
      action <- input$Iaction
      if(action=="order_book"){
        data.table()
      }
      if(action %in% c("trades","wallet","open_orders")){
        market_api_res()[[action]]
      }
      else if(action %in% c("ticker","cancel_order","place_limit_order")){
        market_api_res()
      }
    })
  })
  
  output$Odt_market_api_res <- renderDataTable({
    market_api_res_dt()
  }, options = list(pageLength = 5, lengthMenu = c(5,10,15,100))) # render data table result
  
  output$Ocsv_market_api_res <- downloadHandler(
    filename = function() {
      paste('data_', as.character(Sys.time(),"%Y%m%d_%H%M%S"), '.csv', sep='')
    },
    content = function(file) {
      write.csv(market_api_res_dt(), file, na = "", row.names=FALSE)
    },
    contentType = "text/csv"
  ) # data table csv
  
  output$Ostr_market_api_res <- renderPrint({
    input$Iapi_call
    isolate({
      validate(need(input$Iapi_call > 0, ""))
      str(market_api_res())
    })
  }) # render verbatim str on market response
  
  ### blockchain api
  
  blockchain_api_res <- reactive({
    validate(need(input$Iblockchain_api_call > 0, ""))
    isolate({
      validate(need(nchar(input$Iblockchain_api_x) > 0, ""))
      x <- input$Iblockchain_api_x
      invisible(blockchain.api.process(x))
    })
  }) # perform blochchain query
  
  output$Oprint_blockchain_api_res <- renderPrint({
    input$Iblockchain_api_call
    isolate({
      validate(need(input$Iblockchain_api_call > 0, ""))
      blockchain_api_res()
    })
  }) # render console log
  
  output$Odt_blockchain_api_res <- renderDataTable({
    input$Iblockchain_api_call
    isolate({
      validate(need(input$Iblockchain_api_call > 0, ""))
      r <- blockchain_api_res()
      if(!is.data.table(r)) NULL else r
    })
  }, options = list(pageLength = 5, lengthMenu = c(5,10,15,100))) # blockchain data table result
  
  output$Ostr_blockchain_api_res <- renderPrint({
    input$Iblockchain_api_call
    isolate({
      validate(need(input$Iblockchain_api_call > 0, ""))
      str(blockchain_api_res())
    })
  }) #  blockchain plot result
  
  ### wallet manager api
  
  wallet_manager_data <- function(){
    wallet_dt
  } # non-reactive fun to provide wallet manager data
  
  output$Oplot_wallet_manager <- renderPlot({
    input$Iwallet_manager_plot
    isolate({
      validate(need(input$Iwallet_manager_plot > 0, ""))
      type = input$Iwallet_manager_plot_type
      rbtc.plot(wallet_manager_data(), type = type, verbose = 0)
    })
  }, height = function() {
    session$clientData$output_Oplot_wallet_manager_width
  }) # wallet manager plot
  
  output$Odt_wallet_manager_recent <- renderPrint({
    wallet_manager_data()[wallet_id==max(wallet_id)
                          ][amount>0
                            ][order(currency,auth,location_type,location)
                              ][nchar(location)>getOption("shinyBTC.trunc.char",10), location:=paste0(substr(location,1,getOption("shinyBTC.trunc.char",10)-3),"...")
                                ][]
  }) # wallet manager recent verbatim
  
  output$Odt_wallet_manager <- renderDataTable({
    last_wallet_dt <- copy(wallet_manager_data()[value > 0][order(-wallet_id, value_currency, -value)])
    # format for table
    last_wallet_dt[nchar(location)>getOption("shinyBTC.trunc.char",10), location:=paste0(substr(location,1,getOption("shinyBTC.trunc.char",10)-3),"...")]
    # format headers
    setnames(last_wallet_dt,names(last_wallet_dt), gsub("_"," ",names(last_wallet_dt)))
  }, options = list(pageLength = 5, lengthMenu = c(5,10,15,100))) # wallet manager dt
  
  ### options
  
  setRbitcoinVerbose <- observe(options(Rbitcoin.verbose = input$Rbitcoin.verbose))
  setRbitcoinAntiddosVerbose <- observe(options(Rbitcoin.antiddos.verbose = input$Rbitcoin.antiddos.verbose))
  setRbitcoinAntiddosSec <- observe(options(Rbitcoin.antiddos.sec = input$Rbitcoin.antiddos.sec))
  setRbitcoinPlotMask <- observe(options(Rbitcoin.plot.mask = input$Rbitcoin.plot.mask))
  setRbitcoinPlotLimitPct <- observe(options(Rbitcoin.plot.limit_pct = input$Rbitcoin.plot.limit_pct))
  
})
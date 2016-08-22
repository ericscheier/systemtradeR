


shinyUI(pageWithSidebar(
  headerPanel("Market Analytics Dashboard"),
  sidebarPanel(   
  
    ############################################################################################
    # Main Panel
    ############################################################################################
    conditionalPanel(condition="input.tabs=='Main'",
                     createNonReactiveTextInput("symbol", "Yahoo Ticker(s) separated by comma:", 
                                                value = "SPY", "Update")
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     selectInput("chart.length", strong("Zoom: "), choices = c("YTD","1 Month","3 Month","6 Month","1 Year","2 Year","5 Year","Full"),selected=c("YTD"))
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     selectInput("misc.length", strong("Zoom Secondary Charts: "), choices = c("YTD","1 Month","3 Month","6 Month","1 Year","2 Year","5 Year","Full"),selected=c("YTD"))
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     sliderInput("rolling.return.lookback", "Rolling Return Lookback:",min = 1,max = 250,value = 120)
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     sliderInput("sd.lookback", "Risk Lookback:",min = 1,max = 250,value = 60)
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     sliderInput("percent.lookback", "Percent Rank Lookback:",min = 1,max = 250,value = 250)
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     sliderInput("turb.lookback", "Turbulence Lookback:",min = 1,max = 250,value = 250)
    ),
    conditionalPanel(condition="input.tabs=='Main'",
                     sliderInput("er.lookback", "Efficiency Ratio Lookback:",min = 1,max = 250,value = 250)
    ),
    
    ############################################################################################
    # Second Panel
    ############################################################################################
    conditionalPanel("input.tabs=='AssetAnalytics'",
                     selectInput("chart.length.second.panel", strong("Zoom: "), choices = c("YTD","1 Month","3 Month","6 Month","1 Year","2 Year","5 Year","Full"),selected=c("YTD"))
                     
    )
    
 
  ),
  
  mainPanel(
    tabsetPanel(
      tabPanel("Main",
               htmlOutput("view")
               ),
      
      tabPanel("AssetAnalytics",
               htmlOutput("view2"),
               plotOutput("cluster", height = 1000, width = 1000)),
      
      tabPanel("MacroAnalytics",
               htmlOutput("view3")),
      id="tabs"     
    )
    
  )#mainPane;
  
))
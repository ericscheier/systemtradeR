library(googleVis)
library(shiny)
library(lattice)
library(kernlab)
library(Quandl)
library(TTR)
library(cluster)
shinyServer(function(input, output) {
  symbol_env <- new.env() #global storage of data files
  
  #*****************************************************************
  # Shared Reactive functions
  # http://rstudio.github.com/shiny/tutorial/#inputs-and-outputs
  #******************************************************************      
  #Custom Tab
  getData <- reactive({    
    cat('getData was called\n')
    
    data <- new.env()
    for(symbol in spl(toupper(input$symbol))) {
      if (is.null(symbol_env[[symbol]]))
        tryCatch({
          symbol_env[[symbol]] = getSymbols(symbol, from='1970-01-01', src='yahoo', auto.assign = FALSE)
        }, error = function(e) { stop(paste('Problem getting prices for',symbol)) })
      data[[symbol]] = symbol_env[[symbol]]
    }
    
    bt.prep(data, align='remove.na')
    return(data)    
  })
  
  getRolling <- reactive({
    temp<-getData()
    prices<-temp$prices
    ret<-prices/mlag(prices,as.numeric(input$rolling.return.lookback)) - 1
    ret<-na.omit(ret)
    norm.prices = ret
    new_df = as.data.frame(norm.prices)
    Date = index(ret)
    wi_df = data.frame(Date, new_df)
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="12 Month Rolling Performance",
                                  width=1500,
                                  height=500,
                                  left=-100,
                                  logScale=F))
    
    return(x)
  }) #[Main]
  
  getPerformance <- reactive({
    cat("############################PERF\n")
    temp<-temp<-getData()
    prices<-temp$prices
    ret<-prices/mlag(prices) - 1
    ret<-na.omit(ret)
    
    if(input$chart.length == "YTD"){
      cur.yr<-format(Sys.time(), "%Y")
      ret<-ret[cur.yr]
      
    }else if(input$chart.length == "1 Month"){   
      ret<-ret[(nrow(ret)-20):nrow(ret)]
    }else if(input$chart.length == "3 Month"){
      ret<-ret[(nrow(ret)-60):nrow(ret)]
    }else if(input$chart.length == "6 Month"){
      ret<-ret[(nrow(ret)-120):nrow(ret)]
      
    }else if(input$chart.length == "1 Year"){
      ret<-ret[(nrow(ret)-252):nrow(ret)]
      
    }else if(input$chart.length == "2 Year"){
      ret<-ret[(nrow(ret)-504):nrow(ret)]
      
    }else if(input$chart.length == "5 Year"){ 
      ret<-ret[(nrow(ret)-1260):nrow(ret)]
      
    }else{
      
    }
    cat("perfdim",dim(ret),"\n")
    norm.prices = cumprod(1+ret)
    new_df = as.data.frame(norm.prices)
    Date = index(ret)
    wi_df = data.frame(Date, new_df)
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Normalized Prices",
                                  width=1500,
                                  height=500,
                                  left=-100,
                                  logScale=T))
    
    return(x)
  }) #[Main]
  
  getMomentum <- reactive({
    temp<-getData()
    prices<-temp$prices
    sym<-colnames(prices)
    ret<-prices/mlag(prices) - 1
    ret<-na.omit(ret)
    
    lookback<-c(20,40,60,120,250) #lookbacks

    cagr.list<-list()
    for(i in 1:length(lookback)){
      ret.temp<-ret[(nrow(ret)-lookback[i]):nrow(ret),]
      cagr.list[[i]]<-compute.cagr(cumprod(1+ret.temp)) #annualized
    }

    cagr<-as.data.frame(100*do.call(cbind,cagr.list))
    
    cagr<-data.frame(sym,cagr)
    colnames(cagr)<-c("Symbols","20 Day","40 Day","60 Day","120 Day","250 Day")


    x<-gvisBarChart(cagr, xvar = "", yvar = "", options = list(title="Momentum (Annualized CAGR)", 
                                                               width=1500,
                                                               height=500,
                                                               left=100))

    return(x)
  }) #[Main]
  
  getTable <- reactive({
    temp<-getData()
    
    prices<-temp$prices
    ret<-prices / mlag(prices) - 1
    ret<-na.omit(ret)
    n<-ncol(prices)
    
    sym<-colnames(prices)
    
    #1 Day Change
    daily.delta<-round(last(ret),4) * 100
    weekly.delta<-matrix(round(apply(ret[(nrow(ret)-5):nrow(ret),],2,mean),5)) * 100
    
    #Sharpe 250 Day
    hist1<-ret[(nrow(ret)-250):nrow(ret),]
    sharpe<-ret[1,] * NA
    for(i in 1:ncol(sharpe)){
      sharpe[,i]<-compute.sharpe(hist1[,i])
    }
    sharpe<-round(sharpe,4)
    
    #Percent Volatility Risk
    hist1<-ret[(nrow(ret)-250):nrow(ret),]
    hv<-ret[1,] * NA
    perc.rank<-function(x) trunc(rank(as.vector(x)))/length(x)
    hist.vol = sqrt(252) * bt.apply.matrix(ret, runSD, n = as.numeric(input$sd.lookback))  
    
    rank.vol<-matrix(last(apply(hist.vol[(nrow(hist.vol)-as.numeric(input$percent.lookback)):nrow(hist.vol)],2,perc.rank)))
    rank.vol<-round(100*rank.vol,4)
    
    main.mat<-data.frame(sym,t(daily.delta),(weekly.delta),t(sharpe),rank.vol)
    colnames(main.mat)<-c("Symbols","Daily % Change","5 Day % Change","Annualized 250 Day Simply Sharpe",
                          "HV 250 % Rank")
    x<-gvisTable(main.mat ,options = list(title="Asset Class Statistics", 
                                          width=1500,
                                          height=500,
                                          left=-100))  
    return(x)
  }) #[Main]
  
  getPercentVolatility<-reactive({
    cat("############################VOL\n")
    temp<-getData()
    
    prices<-temp$prices
    ret<-prices / mlag(prices) - 1
    ret<-na.omit(ret)
    

    #n<-ncol(prices)

    sym<-colnames(prices)

    std<-sqrt(252) *bt.apply.matrix(ret,runSD,as.numeric(input$sd.lookback))
    vol.rank<-bt.apply.matrix(std,runPercentRank,as.numeric(input$percent.lookback))
    
    if(input$misc.length == "YTD"){
      cur.yr<-format(Sys.time(), "%Y")
      cat("curyr=",cur.yr,"\n")
      vol.rank<-vol.rank[cur.yr]
      
    }else if(input$misc.length == "1 Month"){ 
      
      vol.rank<-vol.rank[(nrow(vol.rank)-20):nrow(vol.rank)]
    }else if(input$misc.length == "3 Month"){
      
      vol.rank<-vol.rank[(nrow(vol.rank)-60):nrow(vol.rank)]
    }else if(input$misc.length == "6 Month"){
      
      vol.rank<-vol.rank[(nrow(vol.rank)-120):nrow(vol.rank)]
      
    }else if(input$misc.length == "1 Year"){
      vol.rank<-vol.rank[(nrow(vol.rank)-252):nrow(vol.rank)]
      
    }else if(input$misc.length == "2 Year"){
      vol.rank<-vol.rank[(nrow(vol.rank)-504):nrow(vol.rank)]
      
    }else if(input$misc.length == "5 Year"){ 
      vol.rank<-vol.rank[(nrow(vol.rank)-1260):nrow(vol.rank)]
      
    }else{
      
    }
    
    
    new_df = as.data.frame(vol.rank)
    Date = index(vol.rank)
    wi_df = data.frame(Date, new_df)
    cat("hey---\n")
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Percent Volatility Rank",
                                  width=1500,
                                  height=500,
                                  left=-100,
                                  logScale=F))
    cat("hey---\n")
    return(x)
  })
  
  if(F){
    input<-list()
    input$er.lookback<-250
    
  }
  getTurbulence<-reactive({
    cat("############################VOL\n")
    temp<-getData()
    
    prices<-temp$prices
    ret<-prices / mlag(prices) - 1
    ret<-na.omit(ret)
    
    nperiods = nrow(ret)
    turbulence = ret[,1] * NA
    for( i in (input$turb.lookback+1) : nperiods ) {
      temp = ret[(i - input$turb.lookback + 1):(i-1), ]
      
      # measures turbulence for the current observation
      turbulence[i] = mahalanobis(ret[i,], colMeans(temp), cov(temp))
      
      if( i %% 200 == 0) cat(i, 'out of', nperiods, '\n')
    }   
    
    ema.turb<-EMA(turbulence,60)
    
    if(input$misc.length == "YTD"){
      cur.yr<-format(Sys.time(), "%Y")
      cat("curyr=",cur.yr,"\n")
      ema.turb<-ema.turb[cur.yr]
      
    }else if(input$misc.length == "1 Month"){ 
      
      ema.turb<-ema.turb[(nrow(ema.turb)-20):nrow(ema.turb)]
    }else if(input$misc.length == "3 Month"){
      
      ema.turb<-ema.turb[(nrow(ema.turb)-60):nrow(ema.turb)]
    }else if(input$misc.length == "6 Month"){
      
      ema.turb<-ema.turb[(nrow(ema.turb)-120):nrow(ema.turb)]
      
    }else if(input$misc.length == "1 Year"){
      ema.turb<-ema.turb[(nrow(ema.turb)-252):nrow(ema.turb)]
      
    }else if(input$misc.length == "2 Year"){
      ema.turb<-ema.turb[(nrow(ema.turb)-504):nrow(ema.turb)]
      
    }else if(input$misc.length == "5 Year"){ 
      ema.turb<-ema.turb[(nrow(ema.turb)-1260):nrow(ema.turb)]
      
    }else{
      
    }
    
    new_df = as.data.frame(ema.turb)
    Date = index(ema.turb)
    wi_df = data.frame(Date, new_df)
    cat("hey---\n")
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Financial Turbulence Index",
                                  width=1500,
                                  height=500,
                                  left=-100,
                                  logScale=F))
    return(x)
  })
  
  getEffRatio<-reactive({
    temp<-getData()
    prices<-temp$prices
    er<-efficiency.ratio(prices,input$er.lookback)
    
    if(input$misc.length == "YTD"){
      cur.yr<-format(Sys.time(), "%Y")
      cat("curyr=",cur.yr,"\n")
      er<-er[cur.yr]
      
    }else if(input$misc.length == "1 Month"){ 
      
      er<-er[(nrow(er)-20):nrow(er)]
    }else if(input$misc.length == "3 Month"){
      
      er<-er[(nrow(er)-60):nrow(er)]
    }else if(input$misc.length == "6 Month"){
      
      er<-er[(nrow(er)-120):nrow(er)]
      
    }else if(input$misc.length == "1 Year"){
      er<-er[(nrow(er)-252):nrow(er)]
      
    }else if(input$misc.length == "2 Year"){
      er<-er[(nrow(er)-504):nrow(er)]
      
    }else if(input$misc.length == "5 Year"){ 
      er<-er[(nrow(er)-1260):nrow(er)]
      
    }else{
      
    }
    
    new_df = as.data.frame(er)
    Date = index(er)
    wi_df = data.frame(Date, new_df)
    cat("hey---\n")
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Efficiency Ratio",
                                  width=1500,
                                  height=500,
                                  left=-100,
                                  logScale=F))
    
  })
  
  
  #Asset Class Performance Tab
  getAssetClassData<-reactive({
    cat('getData was called\n')
    
    stocks<-c("SPY","EWH","EWA","EWJ","EWU","EWG","EWQ","INDA")
    corporate<-c("LQD", #US Investment Grade Corporate
                 "IBCX.MI",#EURO Corporate
                 "CEMB") #emerging corporate
    
    soverign<-c("AGG", #US
                "JGBL", #Japan
                "BUND", #German
                "AUD", #Aussie 
                "EMB",#emerging market
                "TIP") #TIPS
    
    fx<-c("UUP", #dollar
          "FXE",#Euro
          "FXY", #Yen
          "FXF") #Franc
    
    commodity<-c("BNO", #Brent Oil
                 "GLD", #Gold
                 "JJC") #Copper
    
    asset.class<-c(commodity,stocks,corporate,soverign,fx)
    data <- new.env()
    for(symbol in asset.class) {
      if (is.null(symbol_env[[symbol]]))
        tryCatch({
          symbol_env[[symbol]] = getSymbols(symbol, from='1970-01-01', src='yahoo', auto.assign = FALSE)
        }, error = function(e) { stop(paste('Problem getting prices for',symbol)) })
      data[[symbol]] = symbol_env[[symbol]]
    }
    
    bt.prep(data, align='remove.na')
    return(data) 
    
  })
  
  getAssetClassReturn<-reactive({
    data<-getAssetClassData()
    prices<-data$prices
    ret<-prices/mlag(prices)-1
    ret<-na.omit(ret)
    
    index.names<-c("US Govt Bonds (AGG)", #
      "Australian Currency (AUD)",
      "US Brent Oil COM (BNO)",
      "German Govt Bonds (BUND)",
      "Emerging Market Corp Spreads (CMB)",
      "Emerging Market Govt Bonds (EMB)",
      "Australian Equities (EWA)",
      "German Equities (EWG)",
      "Hong Kong Equities (EWH)",
      "Japanese Equities (EWJ)",
      "French Equities (EWQ)",
      "UK Equities (EWU)",
      "Euro Currency(FXE)",
      "Swiss Franc Currency(FXF)",
      "Yen Currency(FXY)",
      "Gold COM(GLD)",
      "European Corp Spread (IBCX.MI)",
      "Indian Equities (INDA)",
      "Japanese Govt Bonds (JGBL)",
      "Copper COM (JJC)",
      "US Corp Spreads (LQD)",
      "US Equities (SPY)",
      "Dollar Index Currency(UUP)",
      "US Govt TIPS (TIP)")
    
    colnames(prices)[which(colnames(prices) == "CEMB")]<-"CMB"
    for(i in 1:ncol(prices)){
      
      sym<-colnames(prices)[i]
      colnames(prices)[i]<-index.names[which(regexpr(sym,index.names) > 1)]
      
    }
    #colnames(prices)<-index.names
    
    prices.mat<-(prices)
    
    
    if(input$chart.length.second.panel == "YTD"){
      cur.yr<-format(Sys.time(), "%Y")
      
      cat("curyr=",cur.yr,"\n")
      cat("TYPE: ",str(prices.mat),"\n")
      prices.mat<-prices.mat[cur.yr,]
      
      cat("Done YTD Cal\n")
    }else if(input$chart.length.second.panel == "1 Month"){ 
      
      prices.mat<-prices.mat[(nrow(prices.mat)-20):nrow(prices.mat),]
      cat("Done 1m Cal\n")
    }else if(input$chart.length.second.panel == "3 Month"){
      
      prices.mat<-prices.mat[(nrow(prices.mat)-60):nrow(prices.mat),]
      cat("Done 3m Cal\n")
    }else if(input$chart.length.second.panel == "6 Month"){
      
      prices.mat<-prices.mat[(nrow(prices.mat)-120):nrow(prices.mat),]
      
    }else if(input$chart.length.second.panel == "1 Year"){
      prices.mat<-prices.mat[(nrow(prices.mat)-252):nrow(prices.mat),]
      
    }else if(input$chart.length.second.panel == "2 Year"){
      prices.mat<-prices.mat[(nrow(prices.mat)-504):nrow(prices.mat),]
      
    }else if(input$chart.length.second.panel == "5 Year"){ 
      prices.mat<-prices.mat[(nrow(prices.mat)-1260):nrow(prices.mat),]
      
    }else if(input$chart.length.second.panel == "1 Week"){
      prices.mat<-prices.mat[(nrow(prices.mat)-5):nrow(prices.mat),]
    }else{
      
    }
    prices.mat<-as.matrix(prices.mat)
    returns<-round((prices.mat[nrow(prices.mat),] - prices.mat[1,])  / prices.mat[1,],4) * 100
    returns<-sort(returns,decreasing=T)
    returns.assets<-data.frame(names(returns),returns)
    x<-gvisColumnChart(returns.assets, xvar = "", yvar = "", options = list(title="Asset Class Performance",
                                                                     width=1600,
                                                                     height=800,
                                                                     left=-100,
                                                                     logScale=F,
                                                                            legend="none"))
    cat("Done First Chart Gen\n")
    #Get index based on asset type
    index.com<-which(regexpr("COM",names(returns)) > 1)    
    index.eq<-which(regexpr("Equities",names(returns)) > 1) 
    index.govt<-which(regexpr("Govt",names(returns)) > 1) 
    index.corp<-which(regexpr("Corp",names(returns)) > 1)
    index.fx<-which(regexpr("Currency",names(returns)) > 1)
    
    returns.com<-sort(returns[index.com],decreasing=T)
    returns.eq<-sort(returns[index.eq],decreasing=T)
    returns.govt<-sort(returns[index.govt],decreasing=T)
    returns.corp<-sort(returns[index.corp],decreasing=T)
    returns.fx<-sort(returns[index.fx],decreasing=T)
    
    returns.com<-data.frame(names(returns.com),returns.com)
    returns.eq<-data.frame(names(returns.eq),returns.eq)
    returns.govt<-data.frame(names(returns.govt),returns.govt)
    returns.corp<-data.frame(names(returns.corp),returns.corp)
    returns.fx<-data.frame(names(returns.fx),returns.fx)
    
    x1<-gvisColumnChart(returns.com, xvar = "", yvar = "", options = list(title="Commodities",
                                                                            width=800,
                                                                            height=400,
                                                                            left=-100,
                                                                            logScale=F,
                                                                          legend="none"))
    x2<-gvisColumnChart(returns.eq, xvar = "", yvar = "", options = list(title="Equities",
                                                                            width=800,
                                                                            height=400,
                                                                            left=-100,
                                                                            logScale=F,
                                                                         legend="none"))
    x3<-gvisColumnChart(returns.govt, xvar = "", yvar = "", options = list(title="Governtment Bonds",
                                                                            width=800,
                                                                            height=400,
                                                                            left=-100,
                                                                            logScale=F,
                                                                           legend="none"))
    x4<-gvisColumnChart(returns.corp, xvar = "", yvar = "", options = list(title="Corporate Bonds",
                                                                            width=800,
                                                                            height=400,
                                                                            left=-100,
                                                                            logScale=F,
                                                                           legend="none"))
    x5<-gvisColumnChart(returns.fx, xvar = "", yvar = "", options = list(title="Currencies",
                                                                            width=800,
                                                                            height=400,
                                                                            left=-100,
                                                                            logScale=F,
                                                                         legend="none"))
    return(list(agg=x,com=x1,eq=x2,govt=x3,corp=x4,fx=x5))
  })
  
  ####################################################################
  #Non Reactive Functions
  ####################################################################
  efficiency.ratio<-function(prices,lookback){
    
    er<-NA*prices
    for(i in (lookback+1):nrow(prices)){
      cat(i,"\n")
      price<-prices[(i-lookback):(i-1),]
      cur.price<-prices[(i-1),]
      last.price<-prices[(i-lookback),]
      direction<-as.vector(cur.price) - as.vector(last.price)
      
      dif<-price - mlag(price)
      er[i,]<-abs(direction)/colSums(abs(dif),na.rm=T)
    }
    
    
    return(er)
  }
  
  cluster.group.kmeans.elbow.local<-function(ia){

    if(ia$n <= 2) return(c(1,1)[1:ia$n])
    dissimilarity = 1 - cor(ia$hist.returns, use='complete.obs',method='spearman')
    distance = as.dist(dissimilarity)
    n = ncol(ia$correlation)
    n = ceiling(n*2/3)
    xy = cmdscale(distance)
    p.exp = rep(NA, n)
    for (i in 2:n) {
      fit = kmeans(xy, centers=i, iter.max=100, nstart=100)
      p.exp[i] = 1- fit$tot.withinss / fit$totss
    }
    icluster = find.maximum.distance.point(p.exp[-1]) + 1
    fit = kmeans(xy, centers=icluster, iter.max=100, nstart=100)
    group = fit$cluster

    return( list(cluster=group,xy=xy) )
  }
  
  getClusterChart<-function(lookback){
    data<-getAssetClassData()
    prices<-data$prices
    ret<-prices/mlag(prices)-1
    ret<-na.omit(ret)

    ret.yr<-ret[(nrow(ret)-lookback):nrow(ret),] #yearly cluster

    fit<-cluster.group.kmeans.elbow.local(create.ia(ret.yr))

    return(fit)
  }
  
  get.Quandl<-function(symbols){
    sym.list<-list()
    for(i in 1:length(symbols)){
      cat("i\n")
      sym.list[[i]]<-Quandl(symbols[i],type = "xts", start_date="1970-01-01")
    }
    return(sym.list)
  }
  
  get.Fred<-function(symbols){
    sym.list<-list()
    for(i in 1:length(symbols)){
      cat("i\n")
      sym.list[[i]]<-getSymbols(symbols[i],src="FRED")
    }
    return(sym.list)
  }
  
  getGDP <-function(){
    Quandl.auth("yUVpcQioH6GRsiGhZtRS") #authenticate
    growth<-c("FRED/GDPC96")
    data<-get.Quandl(growth) #list
    data<-do.call(cbind,data)
    yoy<-data/mlag(data,12) - 1
    Date = index(yoy)
    wi_df = data.frame(Date,yoy)
    
    
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Real GDP",
                                  width=1500,
                                  height=500,
                                  left=-100))
    return(x)
  }
  
  getInflation <-function(){
    Quandl.auth("yUVpcQioH6GRsiGhZtRS") #authenticate
    growth<-c("FRED/CPIAUCSL")
    data<-get.Quandl(growth) #list
    data<-do.call(cbind,data)
    yoy<-data/mlag(data,12) - 1
    Date = index(yoy)
    wi_df = data.frame(Date,yoy)
    
    
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Inflation",
                                  width=1500,
                                  height=500,
                                  left=-100))
    return(x)
  }
  
  getYieldCurve <- function(){
    Quandl.auth("yUVpcQioH6GRsiGhZtRS") #authenticate
    growth<-c("USTREASURY/YIELD")
    data<-get.Quandl(growth) #list
    data<-do.call(cbind,data)
    
    temp<-matrix(last(data))
    
    n<-c("1Mo",  "3Mo",  "6Mo",  "1Yr",  "2Yr",  "3Yr",  "5Yr",  "7Yr",  "10Yr", "20Yr", "30Yr")
    temp1<-data.frame(rep(1:length(temp)),temp)
    colnames(temp1)<-c("x","Yields")
    rownames(temp1)<-n
    
    x<-gvisScatterChart(temp1,options=list(title="Yield Curve",
                                           width=1500,
                                           height=500,
                                           left=-100))
    
    
    return(x)
  }
  
  getInflationExpectation <- function(){
    Quandl.auth("yUVpcQioH6GRsiGhZtRS") #authenticate
    tips<-c("FRED/DFII20", #20 year tips yield
            "FRED/DFII10", #10 year tips yield
            "FRED/DFII7",  #7 year tips yield
            "FRED/DFII5")   #5 year tips yield
    
    bond<-c("FRED/DGS20", #20 year  yield
            "FRED/DGS10", #10 year  yield
            "FRED/DGS7",  #7 year  yield
            "FRED/DGS5")   #5 year  yield
    
    
    tips<-get.Quandl(tips)
    bonds<-get.Quandl(bond)
    
    tips<-do.call(cbind,tips)
    bonds<-do.call(cbind,bonds)
    
    tips<-tips[(nrow(tips) - 250):nrow(tips),]
    bonds<-bonds[(nrow(bonds) - 250):nrow(bonds),]
    
    tips<-tips/100
    bonds<-bonds/100
    
    
    
    data<-bonds-tips
    
    colnames(data)<-c("20Yr","10Yr","7Yr","5Yr")
    
    
    Date = index(data)
    wi_df = data.frame(Date,data)
    
    
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Inflation Expectation (Treasury-Tips Spread)",
                                  width=1500,
                                  height=500,
                                  left=-100))
    return(x)
  } #return yearly spread [return Charts]
  
  getIndustrialP <-function(){
    Quandl.auth("yUVpcQioH6GRsiGhZtRS") #authenticate
    growth<-c("FRED/INDPRO")
    data<-get.Quandl(growth) #list
    data<-do.call(cbind,data)
    yoy<-data/mlag(data,12) - 1
    
    
    Date = index(yoy)
    wi_df = data.frame(Date,yoy)
    
    
    x<-gvisLineChart(data = wi_df, xvar = "Date", yvar = "",
                     options=list(title="Industrial Production",
                                  width=1500,
                                  height=500,
                                  left=-100))
    return(x)
  }
  ####################################################################
  #Plots
  ####################################################################
  output$view <- renderGvis({
    x<-getPerformance() #get Equity Line performance
    y<-getRolling() #get rolling performance
    z<-getMomentum() #get momentum
    c<-getTable() #get table
    vol<-getPercentVolatility()
    turb<-getTurbulence()
    er<-getEffRatio()
    temp<-gvisMerge(x,y)
    temp1<-gvisMerge(temp,z)
    temp2<-gvisMerge(temp1,vol)
    temp3<-gvisMerge(temp2,turb)
    temp4<-gvisMerge(temp3,er)
    gvisMerge(temp4,c)
  }) #Main
  
  output$view2 <- renderGvis({
    x<-getAssetClassReturn() #Performance
    agg<-x$agg
    eq<-x$eq
    com<-x$com
    govt<-x$govt
    corp<-x$corp
    fx<-x$fx
    
    t1<-gvisMerge(eq,com,horizontal=T)
    t2<-gvisMerge(govt,corp,horizontal=T)
    t3<-gvisMerge(t1,t2)
    t4<-gvisMerge(t3,fx)
    
    gvisMerge(agg,t4)
    
  }) #Secondary Asset Class Performance
  
  output$view3 <-renderGvis({
    gdp<-getGDP()
    inf<-getInflation()
    temp<-gvisMerge(gdp,inf)
    yc<-getYieldCurve()
    temp1<-gvisMerge(temp,yc)
    infexp<-getInflationExpectation()
    temp2<-gvisMerge(temp1,infexp)
    indp<-getIndustrialP()
    gvisMerge(temp2,indp)
    
  }) #Macro Tab
  
  
  
  output$cluster <-renderPlot({
    fit1<-getClusterChart(250)
    fit2<-getClusterChart(120)
    fit3<-getClusterChart(60)
    fit4<-getClusterChart(20)
    
    par(mfrow=c(2,2))
    clusplot(fit1$xy, fit1$cluster, color=TRUE, shade=TRUE, labels=3, lines=0, plotchar=F, 
             main = "1 Year Cluster", sub='')

    clusplot(fit2$xy, fit2$cluster, color=TRUE, shade=TRUE, labels=3, lines=0, plotchar=F, 
             main = "6 Month Cluster", sub='')
 
    clusplot(fit3$xy, fit3$cluster, color=TRUE, shade=TRUE, labels=3, lines=0, plotchar=F, 
             main = "3 Month Cluster", sub='')
    clusplot(fit4$xy, fit4$cluster, color=TRUE, shade=TRUE, labels=3, lines=0, plotchar=F, 
             main = "1 Month Cluster", sub='')
  }, height = 1000, width = 1000)
  
  
})








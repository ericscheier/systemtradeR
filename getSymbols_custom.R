getSymbols.custom <- function (Symbols, env, dir = "", return.class = "xts", extension = "csv", 
          col.names = c("Open", "High", "Low", "Close", "Volume"), account.currency="USD", ...) 
{
  importDefaults("getSymbols.custom")
  this.env <- environment()
  for (var in names(list(...))) {
    assign(var, list(...)[[var]], this.env)
  }
  default.return.class <- return.class
  default.dir <- dir
  default.extension <- extension
  if (!hasArg(verbose)) 
    verbose <- FALSE
  if (!hasArg(auto.assign)) 
    auto.assign <- TRUE
  for (i in 1:length(Symbols)) {
    return.class <- getSymbolLookup()[[Symbols[[i]]]]$return.class
    return.class <- ifelse(is.null(return.class), default.return.class, 
                           return.class)
    dir <- getSymbolLookup()[[Symbols[[i]]]]$dir
    dir <- ifelse(is.null(dir), default.dir, dir)
    extension <- getSymbolLookup()[[Symbols[[i]]]]$extension
    extension <- ifelse(is.null(extension), default.extension, 
                        extension)
    if (verbose) 
      cat("loading ", Symbols[[i]], ".....")
    # if (dir == "") {
    #   sym.file <- paste(Symbols[[i]], extension, sep = ".")
    # }
    # else {
    #   sym.file <- file.path(dir, paste(Symbols[[i]], extension, 
    #                                    sep = "."))
    # }
    # if (!file.exists(sym.file)) {
    #   cat("\nfile ", paste(Symbols[[i]], "csv", sep = "."), 
    #       " does not exist ", "in ", dir, "....skipping\n")
    #   next
    # }
    # fr <- read.csv(sym.file)
    
    fr <- getHourlyPairData(pair=Symbols[[i]], ohlc=TRUE, volume=TRUE)
    
    symbol <- pairToSymbol(pair=Symbols[[i]])
    currencies <- pairToCurrencies(Symbols[[i]])
    
    
    if (verbose) 
      cat("done.\n")
    asDateArgs <- list(x = as.character(fr[, 1]))
    if (hasArg("format")) 
      asDateArgs$format <- format
    if (!is.null(getSymbolLookup()[[Symbols[[i]]]]$format)) 
      asDateArgs$format <- getSymbolLookup()[[Symbols[[i]]]]$format
    # fr <- xts(fr[, -1], do.call("as.Date", asDateArgs), 
    #           src = "csv", updated = Sys.time())
    colnames(fr) <- paste(toupper(gsub("\\^", "", symbol)), #Symbols[[i]])), 
                          col.names, sep = ".")
    
    indexClass(fr) <- c("POSIXt", "POSIXct")
    # fr <- convert.time.series(fr = fr, return.class = return.class)
    Symbols[[i]] <- toupper(gsub("\\^", "", symbol)) #Symbols[[i]]))
    
    min.tick <- max(nchar(gsub("(.*\\.)|([0]*$)", "", as.character(OHLC(fr)))))
    currency(unlist(currencies))
    # currency(c("BTC", "BTS", "USD"), assign_i = FALSE)
    exchange_rate(symbol, currency = currencies$base, counter_currency = currencies$asset, tick_size = 10^-min.tick)
    
    s.ccy.str <- getInstrument(symbol)$currency
    
    p.ccy.str <- account.currency
    
    fr$Exchange.Rate <- 1
    
    # psummary = updated.portfolio$summary[date.subset]
    if (s.ccy.str != p.ccy.str) {
      # print("determining fx rate")
      dateRange <- paste0(min(index(fr)),"::",max(index(fr)))
      CcyMult <- NA
      port_currency <- try(getInstrument(p.ccy.str), silent = TRUE)
      if (inherits(port_currency, "try-error") | !is.instrument(port_currency)) {
        warning("Currency", p.ccy.str, " not found, using currency multiplier of 1")
        CcyMult <- 1
      }
      else {
        FXrate.str <- paste(p.ccy.str, s.ccy.str, sep = "")
        FXrate <- try(get(FXrate.str), silent = TRUE)
        invert = FALSE
        if (inherits(FXrate, "try-error")) {
          FXrate.str <- paste(s.ccy.str, p.ccy.str, 
                              sep = "")
          FXrate <- try(get(FXrate.str), silent = TRUE)
          if (inherits(FXrate, "try-error")) {
            warning("Exchange Rate", FXrate.str, " not found for symbol,',Symbol,' using currency multiplier of 1")
            CcyMult <- 1
          }
          else {
            invert = TRUE
          }
        }
      }
      if (is.na(CcyMult) && !is.na(FXrate)) {
        if (inherits(FXrate, "xts")) {
          if (ncol(FXrate) > 1) 
            CcyMult <- getPrice(FXrate[dateRange], ...)
          else CcyMult <- FXrate[dateRange]
          CcyMult <- na.locf(merge(CcyMult, index(fr)))
          CcyMult <- CcyMult[index(fr)]
        }
        else {
          CcyMult <- as.numeric(FXrate)
        }
      }
      else {
        CcyMult <- 1
      }
      if (isTRUE(invert)) {
        CcyMult <- 1/CcyMult
      }
      fr$Exchange.Rate <- as.numeric(CcyMult)
    }
    
    if (auto.assign) 
      assign(symbol, fr, env) #Symbols[[i]], fr, env)
    
  }
  
  if (auto.assign) 
    return(Symbols)
  return(fr)
}


# copied from https://github.com/gsee/qmao/blob/master/R/alignSymbols.R
alignSymbols <- function(Symbols, forecast.name=NULL, env=.GlobalEnv) {
  if (any(!is.character(Symbols))) 
    stop("Symbols must be vector of character strings.")
  ff <- try(Cl(get(Symbols[1], pos=env)))
  if (inherits(ff, 'try-error') || 
      (!inherits(ff,'xts') && !inherits(ff,'zoo'))) {
    stop('You must create an xts object for each symbol first.')
  }
  # add the symbol and an underscore to the column names of each xts so that
  # we can "unmerge" easier
  # colnames(ff) <- paste(Symbols[1], colnames(ff), sep="_") 
  colnames(ff) <- gsub(".Close","",colnames(ff))
  # symout <- Symbols[1]
  if (length(Symbols) > 1){
    
    ncols <- ncol(ff) # we'll make sure all Symbols ncols is same as 1st one
    
    for (sym in Symbols[-1]) {
      tmp.sym <- try(Cl(get(sym,pos=env)),silent=TRUE)
      if (!inherits(tmp.sym,'try-error') && 
          (inherits(tmp.sym,'xts') || inherits(tmp.sym,'zoo'))) {
        if (ncol(tmp.sym) != ncols) {
          stop("All Symbols must have the same number of columns.")
        }
        # colnames(tmp.sym) <- paste(sym, colnames(tmp.sym), sep="_")
        colnames(tmp.sym) <- gsub(".Close","",colnames(tmp.sym))
        ff <- merge(ff,tmp.sym,all=TRUE)
        # ff <- na.omit(ff)
        # symout <- c(symout, sym)
      }
    }
  }
  
  leading.nas <- countLeadingNAs(ff)
  ff <- ff[,names(sort(leading.nas))]
  
  applyAdjusted <- function(instrument.name, price.matrix, forecast.name){
    adjustedWeight(instrument.name=instrument.name,
                   forecast.name=forecast.name,
                   price.xts=price.matrix[,instrument.name],
                   num.pairs.xts = xts(rowSums(!is.na(na.locf(price.matrix))), index(price.matrix)))
  }
  
  adjusted.weights <- xts(rbind(sapply(names(ff), applyAdjusted, price.matrix=ff, forecast.name=forecast.name)) * !is.na(ff)
                          , order.by = index(ff))
  
  return.list <- list(ordered.symbols = colnames(ff),
                      init.date = min(index(ff)) - minutes(5),
                      adjusted.weights = adjusted.weights)
  
  return(return.list)
}
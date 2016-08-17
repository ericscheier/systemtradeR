getSymbols.custom <- function (Symbols, env, dir = "", return.class = "xts", extension = "csv", 
          col.names = c("Open", "High", "Low", "Close", "Volume"), ...) 
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
    
    split.pair <- unlist(strsplit(Symbols[[i]], "_"))
    base <- split.pair[1]
    asset <- split.pair[2]
    
    symbol <- paste0(asset,base)
    
    
    
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
    if (auto.assign) 
      assign(symbol, fr, env) #Symbols[[i]], fr, env)
    
    min.tick <- max(nchar(gsub("(.*\\.)|([0]*$)", "", as.character(OHLC(fr)))))
    currency(c(base, asset))
    exchange_rate(symbol, currency = base, counter_currency = asset, tick_size = 10^-min.tick)
    
  }
  
  if (auto.assign) 
    return(Symbols)
  return(fr)
}


# copied from https://github.com/gsee/qmao/blob/master/R/alignSymbols.R
alignSymbols <-
  function(Symbols, env=.GlobalEnv) {
    if (length(Symbols) < 2) 
      stop("Must provide at least 2 Symbols")
    if (any(!is.character(Symbols))) 
      stop("Symbols must be vector of character strings.")
    ff <- try(get(Symbols[1], pos=env))
    if (inherits(ff, 'try-error') || 
        (!inherits(ff,'xts') && !inherits(ff,'zoo'))) {
      stop('You must create an xts object for each symbol first.')
    }
    # add the symbol and an underscore to the column names of each xts so that
    # we can "unmerge" easier
    colnames(ff) <- paste(Symbols[1], colnames(ff), sep="_") 
    ncols <- ncol(ff) # we'll make sure all Symbols ncols is same as 1st one
    symout <- Symbols[1]
    for (sym in Symbols[-1]) {
      tmp.sym <- try(get(sym,pos=env),silent=TRUE)
      if (!inherits(tmp.sym,'try-error') && 
          (inherits(tmp.sym,'xts') || inherits(tmp.sym,'zoo'))) {
        if (ncol(tmp.sym) != ncols) {
          stop("All Symbols must have the same number of columns.")
        }
        colnames(tmp.sym) <- paste(sym, colnames(tmp.sym), sep="_")
        ff <- merge(ff,tmp.sym,all=FALSE)
        ff <- na.omit(ff)
        symout <- c(symout, sym)
      }
    }
    for (sym in symout) {
      tmpid <- paste(sym, "_", sep="")
      cols <- grep(tmpid, colnames(ff))
      tmpout <- ff[, cols]
      colnames(tmpout) <- sub(tmpid, "", colnames(tmpout))
      assign(sym, tmpout, pos=env)
    }
    symout
  }
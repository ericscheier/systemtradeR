pairToSymbol <- function(pair){
  split.pair <- unlist(strsplit(pair, "_"))
  base <- split.pair[1]
  asset <- split.pair[2]
  
  symbol <- paste0(asset,base)
  return(symbol)
}

pairToCurrencies <- function(pair){
  split.pair <- unlist(strsplit(pair, "_"))
  currencies <- list(asset=split.pair[2],
                     base=split.pair[1])
  return(currencies)
}

massInstall <- function(x, library.repos){
  print(paste0("Needing to install package: ",x))
  install.packages(x, repos=library.repos, dependencies=TRUE)
  # suppressMessages(
    library (eval(x), character.only = TRUE)
    # )
}

closeOfXts <- function(x){
  return(Cl(as.xts(x)))
}

rowSumXts <- function(results.matrix, name=NULL){
  row.summed.matrix <- xts(x=rowSums(results.matrix,na.rm=TRUE), order.by=index(results.matrix))
  names(row.summed.matrix) <- name
  return(row.summed.matrix)
}

removeLeadingZeros <- function(returns.xts){
  
  not.leading.zeros <- cumsum(!apply(returns.xts, 1, function(x) all(x==0)))>0
  adjusted.xts <- returns.xts[not.leading.zeros,]
  
  return(adjusted.xts)
}

replaceLeadingZeros <- function(returns.xts){
  
  columnReplace <- function(column){
    leading.zeros <- cumsum(abs(column))==0
    column[leading.zeros] <- NA
    return(column)
  }
  
  adjusted.xts <- apply(returns.xts, 2, columnReplace)
  
  return(as.xts(adjusted.xts))
}

countLeadingNAs <- function(returns.xts){
  
  columnCount <- function(column){
    leading.nas <- sum(cumsum(!is.na(column))==0)
    # column[leading.zeros] <- NA
    return(leading.nas)
  }
  
  resulting.count <- apply(returns.xts, 2, columnCount)
  
  return(resulting.count)
}

relativePath <- function(path){
  # path should have a slash in front of it
  path <- gsub("^/?", "/",path)
  relative.path <- paste0(getwd(), path)
}

actionNotify <- function(notification.content){
  if(system.config$live){
    print(notification.content)
    slackr_bot(notification.content)
    }
  if(!system.config$live){print(notification.content)}
}

changeFiles <- function(file){
  file.name <- file.path(path, file)
  existing.data <- read.csv(file.name, stringsAsFactors = FALSE, row.names="X")
  write.csv(existing.data, file=file.name, row.names=FALSE)
}

editDirectory <- function(){
  path <- NULL #"./data/raw/backups"
  infiles <- dir(path =path, pattern='\\.csv$')
  
  lapply(infiles , changeFiles)
  
}

plotWeights <- function(weights.name=NULL){
  start_t <- Sys.time()
  weights.var <- readRDS(relativePath(paste0("data/clean/",weights.name,".RDS")))
  plot.name <- paste0("figures/final/",weights.name,".pdf")
  png(plot.name)
  chart.StackedBar(weights.var, colorset=tol12qualitative #rainbow12equal
                   , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                   , main=weights.name)
  dev.off()
  end_t <- Sys.time()
  print(paste0("Weight plotting time: ",end_t - start_t))
}
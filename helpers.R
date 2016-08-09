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

plotWeights <- function(weights.var=NULL, weights.name=NULL){
  pdf.name <- paste0("figures/final/",weights.name,".pdf")
  pdf(pdf.name)
  chart.StackedBar(weights.var, colorset=tol12qualitative #rainbow12equal
                   , space=0, minor.ticks = FALSE, major.ticks = FALSE, border=NA
                   , main=weights.name)
  dev.off()
}
massInstall <- function(x, library.repos){
  install.packages(x, repos=library.repos)
  suppressMessages(library (x))
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
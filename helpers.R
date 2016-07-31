massInstall <- function(x, library.repos){
  print(paste0("Needing to install package: ",x))
  install.packages(x, repos=library.repos)
  # suppressMessages(
    library (eval(x), character.only = TRUE)
    # )
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
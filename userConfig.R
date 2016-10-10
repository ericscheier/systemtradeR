

if(inherits(try(user.config, silent=TRUE), "try-error")){user.config <- new.env(parent = emptyenv())}

user.config$account.created <- "2015-12-31 02:00:00"
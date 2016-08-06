libraries <- c("xts",
               "lubridate",
               "TTR",
               "PerformanceAnalytics",
               "PortfolioAnalytics",
               "DEoptim",
               "doParallel",
               "httr",
               "plyr",
               "digest",
               "jsonlite",
               "RCurl",
               "stringr",
               "slackr",
               "httr",
               "quantstrat",
               # "IKTrading",  
               "lattice",
               "doParallel"
               )

library.repos <- c("http://cran.us.r-project.org", "http://R-Forge.R-project.org")

library.loaded <- unlist(lapply(libraries, require, character.only = TRUE))

if(any(!library.loaded)){lapply(libraries[!library.loaded], massInstall, library.repos=library.repos)}


# install.packages("quantstrat", repos="http://R-Forge.R-project.org"",
# install_github("IlyaKipnis/IKTrading"", needs devtools
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
               "ROI",  
               "lattice"
               )

library.repos <- c("http://R-Forge.R-project.org", "http://cran.us.r-project.org")

library.loaded <- unlist(lapply(libraries, require, character.only = TRUE))

if(any(!library.loaded)){lapply(libraries[!library.loaded], massInstall, library.repos=library.repos)}


# install.packages("quantstrat", repos="http://R-Forge.R-project.org"",
# install_github("IlyaKipnis/IKTrading"", needs devtools
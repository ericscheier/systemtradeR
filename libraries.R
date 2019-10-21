libraries <- c("devtools",
               "xts",
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
               "lattice",
               "rgdax"
               )

library.repos <- c("http://cran.us.r-project.org", "http://R-Forge.R-project.org")

library.loaded <- unlist(lapply(libraries, require, character.only = TRUE))

if(any(!library.loaded)){lapply(libraries[!library.loaded], massInstall, library.repos=library.repos)}

# libxml2-dev
# libcurl4-openssl-dev
# libssl-dev

# install quantstrat
#install.packages("devtools") # if not installed
#install.packages("FinancialInstrument") #if not installed
#install.packages("PerformanceAnalytics") #if not installed

# next install blotter from GitHub
#devtools::install_github("braverock/blotter")
# next install quantstrat from GitHub
#devtools::install_github("braverock/quantstrat")

#devtools::install_github("IlyaKipnis/IKTrading")
# x <- 5
# source("systemConfig.R")

systemUpdate <- function(){
  mock.time <- as.POSIXct("1992-04-25 07:40:00 UTC")
  update.states <- data.frame(func.label=c("quarters","months","weeks","days","hours","minutes"),
                              unit=c( "months","months","weeks","days","hours","minutes"),
                             interval=c(3, 1, 1, 1, 1, 15.0),
                             last.updated=rep(mock.time, 6),
                             locked=rep(FALSE, 6))
  
  if(file.exists("update_states.RDS")){
    update.states <- readRDS("update_states.RDS")
  }
  
  for (i in 1:nrow(update.states)){
    current.time <- Sys.time()
    test.int <- as.interval(difftime(current.time, update.states[i,"last.updated"], units="mins"), start=update.states[i,"last.updated"])
    is.due <- (as.period(test.int) %/% do.call(as.character(update.states[i, "unit"]), list(1))) >= update.states[i,"interval"]
    is.locked <- update.states[i, "locked"]
    if(is.due && !is.locked){
      update.states[i, "locked"] <- TRUE
      saveRDS(update.states, "update_states.RDS")
      intervalFunc <- paste0(update.states[i, "func.label"], "Function")
      print(paste0("Running ",intervalFunc))
      func.successful <- try(do.call(intervalFunc, args=list()))
      if(!inherits(func.successful, "try-error")){update.states[i, "last.updated"] <- current.time}
      update.states[i, "locked"] <- FALSE
      saveRDS(update.states, "update_states.RDS")
    }
  }
}

testFunction <- function(){print("Test Successful")}

minutesFunction <- function(){
  # update & note account value
  print(recordAccountValue())
  # check in on open orders and adjust accordingly
  print(ldply(returnOpenOrders(), data.frame))
}

hoursFunction <- function(){
  # update pricing
  print(refreshPricing())
  # cancel open trades
  if(system.config$live){print(cancelAllOrders())}
  # update portfolio & make trades
  refreshPortfolio()
  print(tradesToMake())
  if(system.config$live){print(makeTrades())}
}

daysFunction <- function(){
  # volatilityTargetChecking()
  # reporting
  # recalculate forecast scalars?
  # recalculate forecast weights?
  print("Nothing in this function yet")
}

weeksFunction <- function(){
  # refreshPairs()
  print(refreshPricing())
  simulateSubsystems()
  rawInstrumentWeights()
  smoothedInstrumentWeights()
  # subsystem.returns <- readRDS(paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
  # charts.PerformanceSummary(subsystem.returns, main="Subsystem Backtested Performance")
  # charts.PerformanceSummary(na.omit(subsystem.returns), main="NA-Removed Subsystem Backtested Performance")
}

monthsFunction <- function(){
  print("Nothing in this function yet")
}

quartersFunction <- function(){
  # distributions
  print("Nothing in this function yet")
}
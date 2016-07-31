# x <- 5
# source("systemConfig.R")

systemUpdate <- function(is.live=system.config$live){
  system.config$live <- is.live
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
      running.alert <- paste0("Running ",intervalFunc)
      actionNotify(running.alert)
      func.successful <- try(do.call(intervalFunc, args=list()))
      actionNotify(func.successful)
      if(!inherits(func.successful, "try-error")){update.states[i, "last.updated"] <- current.time}
      update.states[i, "locked"] <- FALSE
      saveRDS(update.states, "update_states.RDS")
    }
  }
}

testFunction <- function(){return("Test Successful")}

minutesFunction <- function(){
  # update & note account value
  account.value <- recordAccountValue()
  # check in on open orders and adjust accordingly
  open.orders <- ldply(returnOpenOrders(), data.frame)
  return(list(account.value,
              open.orders))
}

hoursFunction <- function(){
  # update pricing
  refreshed.pricing <- refreshPricing()
  # cancel open trades
  canceling.orders <- NULL
  if(system.config$live){canceling.orders <- cancelAllOrders()}
  # update portfolio & make trades
  refreshed.portfolio <- refreshPortfolio()
  trades.to.make <- tradesToMake()
  trades.made <- NULL
  if(system.config$live){trades.made <- makeTrades()}
  return(list(refreshed.pricing,
              canceling.orders,
              refreshed.portfolio,
              trades.to.make,
              trades.made))
}

daysFunction <- function(){
  # volatilityTargetChecking()
  # reporting
  # recalculate forecast scalars?
  # recalculate forecast weights?
  return.temp <- "Nothing in this function yet"
  return(list(return.temp))
}

weeksFunction <- function(){
  # refreshPairs()
  refreshed.pricing <- refreshPricing()
  simulated.subsystems <- simulateSubsystems()
  raw.instrument.weights <- rawInstrumentWeights()
  smoothed.instrument.weights <- smoothedInstrumentWeights()
  # subsystem.returns <- readRDS(paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
  # charts.PerformanceSummary(subsystem.returns, main="Subsystem Backtested Performance")
  # charts.PerformanceSummary(na.omit(subsystem.returns), main="NA-Removed Subsystem Backtested Performance")
  return(list(refreshed.pricing,
              simulated.subsystems,
              raw.instrument.weights,
              smoothed.instrument.weights))
}

monthsFunction <- function(){
  return.temp <- "Nothing in this function yet"
  return(list(return.temp))
}

quartersFunction <- function(){
  # distributions
  return.temp <- "Nothing in this function yet"
  return(list(return.temp))
}
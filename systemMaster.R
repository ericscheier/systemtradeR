# x <- 5
mock.time <- as.POSIXct("1992-04-25 07:40:00 UTC")
temp.last.updated <- last.updated <- list(weeks=mock.time
                                          , days=mock.time
                                          , hours=mock.time
                                          , mins=mock.time)

if(file.exists("last_updated.RDS")){
  temp.last.updated <- last.updated <- readRDS("last_updated.RDS")
}

toggles <- list(weeks=FALSE
                , days=FALSE
                , hours=FALSE
                , mins=FALSE)


# while (x>4){
  current.time <- Sys.time()

  if(difftime(current.time, last.updated$mins, units="mins") >= 9.99){toggles$mins=TRUE}
  if(difftime(current.time, last.updated$hours, units="hours") >= 0.99){toggles$hours=TRUE}
#  if(difftime(current.time, last.updated$days, units="days") >= 0.99){toggles$days=TRUE}
#  if(difftime(current.time, last.updated$weeks, units="weeks") >= 0.99){toggles$weeks=TRUE}
  
  if(toggles$mins){temp.last.updated$mins <- current.time}
  if(toggles$hours){temp.last.updated$mins <- current.time}
  if(toggles$days){temp.last.updated$mins <- current.time}
  if(toggles$weeks){temp.last.updated$mins <- current.time}
  saveRDS(temp.last.updated, file="last_updated.RDS")
  
  if(any(unlist(toggles))){
    slackr_bot(print(current.time))
    slackr_bot(sapply(last.updated, timeDifferences, current.time=current.time))
  }
  
  if(toggles$mins){
    minutelyFunction <- function(){
      # update & note account value
      print(recordAccountValue())
      # check in on open orders and adjust accordingly
      print(ldply(returnOpenOrders(), data.frame))
    }
    minutes.successful <- try(slackr_bot(minutelyFunction()))
    if(!inherits(minutes.successful, "try-error")){last.updated$mins <- current.time}
  }
  
  if(toggles$hours){
    hourlyFunction <- function(){
      # update pricing
      print(refreshPricing())
      # cancel open trades
      print(cancelAllOrders())
      # update portfolio & make trades
      print(makeTrades())
    }
    hours.successful <- try(slackr_bot(hourlyFunction()))
    if(!inherits(hours.successful, "try-error")){last.updated$hours <- current.time}
  }
  
  if(toggles$days){
    # reporting
    # recalculate forecast scalars?
    # recalculate forecast weights?
    dailyFunction <- function(){
      volatilityTargetChecking()
    }
    # days.successful <- try(slackr_bot(dailyFunction()))
    # if(!inherits(days.successful, "try-error")){last.updated$days <- current.time}
  }
  
  if(toggles$weeks){
    # weekly simulate subsystem returns (daily when sped up, currently takes 1.5 hours)
    # weekly recalculate instrument weights (daily when sped up, currently takes 25-60 minutes)
    # need to find a way to deal with assets that haven't started trading yet (ETH & FCT)
    weeklyFunction <- function(){
    #  simulateSubsystems()
    #  rawInstrumentWeights()
    #  smoothedInstrumentWeights()
      # subsystem.returns <- readRDS(paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
      # charts.PerformanceSummary(subsystem.returns, main="Subsystem Backtested Performance")
      # charts.PerformanceSummary(na.omit(subsystem.returns), main="NA-Removed Subsystem Backtested Performance")
    }
    # weeks.successful <- try(slackr_bot(weeklyFunction()))
    # if(!inherits(weeks.successful, "try-error")){last.updated$weeks <- current.time}
  }
  saveRDS(last.updated, file="last_updated.RDS")

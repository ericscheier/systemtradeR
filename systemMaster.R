x <- 5
last.updated <- readRDS("last_updated.RDS")


# while (x>4){
  toggles <- list(weeks=FALSE
                  , days=FALSE
                  , hours=FALSE
                  , mins=FALSE)
  current.time <- Sys.time()
  slackr_bot(print(current.time))
  slackr_bot(sapply(last.updated, timeDifferences, current.time=current.time))
  if(difftime(current.time, last.updated$mins, units="mins") >= 10){toggles$mins=TRUE}
  if(difftime(current.time, last.updated$hours, units="hours") >= 1){toggles$hours=TRUE}
  if(difftime(current.time, last.updated$days, units="days") >= 1){toggles$days=TRUE}
  if(difftime(current.time, last.updated$weeks, units="weeks") >= 1){toggles$weeks=TRUE}
  
  print(toggles[toggles==1])
  
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
    dailyFunction <- function(){
      
    }
    days.successful <- try(dailyFunction())
    if(!inherits(days.successful, "try-error")){last.updated$days <- current.time}
  }
  
  if(toggles$weeks){
    # weekly simulate subsystem returns (daily when sped up, currently takes 1.5 hours)
    # source("simulateSubsystem.R")
    # weekly recalculate instrument weights (daily when sped up, currently takes 25-60 minutes)
    # need to find a way to deal with assets that haven't started trading yet (ETH & FCT)
    # smoothedInstrumentWeights(rawInstrumentWeights(volatility.target=volatility.target))
    weeklyFunction <- function(){
      
    }
    weeks.successful <- try(weeklyFunction())
    if(!inherits(weeks.successful, "try-error")){last.updated$weeks <- current.time}
  }
  saveRDS(last.updated, file="last_updated.RDS")
  Sys.sleep(60*7.5)
  source("systemConfig.R")
# tr}
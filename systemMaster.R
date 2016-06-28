

weekly <- FALSE
daily <- FALSE
hourly <- TRUE
five.minutes <- FALSE

if(weekly){
  # weekly simulate subsystem returns (daily when sped up, currently takes 1.5 hours)
  source("simulateSubsystem.R")
  # weekly recalculate instrument weights (daily when sped up, currently takes 25-60 minutes)
  # need to find a way to deal with assets that haven't started trading yet (ETH & FCT)
  smoothedInstrumentWeights(rawInstrumentWeights(volatility.target=volatility.target))
}

if(daily){
  # reporting
}

if(hourly){
  # update pricing
  refreshPricing()
  calculatePortfolio()
}

if(five.minutes){
  
}
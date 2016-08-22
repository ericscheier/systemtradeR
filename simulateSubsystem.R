simulateSubsystems <- function(){
  start.time <- Sys.time()
  portfolio.pairs <- system.config$portfolio.pairs
  
  results.matrix <- 
    foreach(pair=portfolio.pairs, .combine='merge') %dopar% {
      instrument.returns <- simulateBacktest(pair=pair)
      names(instrument.returns) <- pair
      return(instrument.returns)
    }
  
  results.matrix <- na.omit(results.matrix)
  instrument.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
  saveRDS(instrument.returns, file=relativePath("/data/clean/subsystem_returns.RDS"))
  
  execution.time <- round(difftime(Sys.time(), start.time, units="mins"),2)
  print(paste0("Finished simulating instrument returns in ",execution.time," mins."))
}

rawInstrumentWeights <- function(){
  
  subsystem.return.path <- "data/clean/subsystem_returns.RDS"
  raw.instrument.weights <- rawWeights(return.path=subsystem.return.path)
  saveRDS(raw.instrument.weights, relativePath("/data/clean/raw_instrument_weights.RDS"))
  
  plotWeights(weights.var=raw.instrument.weights, weights.name="raw_instrument_weights")
  # return(raw.instrument.weights)
}

smoothedInstrumentWeights <- function(){
  raw.instrument.weights.path <- "/data/clean/raw_instrument_weights.RDS"
  smoothed.instrument.weights <- smoothedWeights(raw.weights.path=raw.instrument.weights.path)
  
  saveRDS(smoothed.instrument.weights, relativePath("/data/clean/smoothed_instrument_weights.RDS"))
  
  plotWeights(weights.var=smoothed.instrument.weights, weights.name="smoothed_instrument_weights")
  
  return(smoothed.instrument.weights)
}

# simulateSubsystems <- function(){
#   # registerDoParallel()
#   start.time <- Sys.time()
#   portfolio.pairs <- system.config$portfolio.pairs
#   
#   
#   results.matrix <- xts(x=NA, order.by=floor_date(system.config$last.exchange.rate,unit="hour"))
#   
#   for(pair in portfolio.pairs){
#     simulation.results <- simulateSubsystem(pair=pair)
#     
#     results.matrix <- merge.xts(results.matrix, simulation.results)
#   }
#   
#   results.matrix$results.matrix <- NULL
#   colnames(results.matrix) <- portfolio.pairs
#   subsystem.returns <- Return.calculate(results.matrix)[2:nrow(results.matrix),]
#   
#   
#   saveRDS(subsystem.returns, file=paste0(getwd(), "/data/clean/subsystem_returns.RDS"))
#   execution.time <- round(difftime(Sys.time(), start.time, units="hours"),2)
#   print(paste0("Finished simulating subsystem returns in ",execution.time," hours."))
#   return(paste0("Finished simulating subsystem returns in ",execution.time," hours."))
# }
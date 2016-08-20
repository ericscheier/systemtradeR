
fullSystemBacktest <- function(){
  start_time <- Sys.time()
  
  pairs <- system.config$portfolio.pairs
  # pairs <- pairs[1:2]
  forecast.name <- "fullSystem"
  
  test.equity <- simulateBacktest(pairs=pairs, forecast.name=forecast.name)
  
  saveRDS(test.equity, file=relativePath("data/clean/fullSystem_backtest_account.RDS"))
  
  end_time <- Sys.time()
  print(end_time - start_time)
  return(test.equity)
}
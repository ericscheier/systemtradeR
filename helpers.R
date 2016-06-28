pcchance = function(x, lag=1){
  c(diff(x,lag), rep(NA,lag))/x
}
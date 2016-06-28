cancelAllOrders <- function(account="exchange"){
  open.orders <- returnOpenOrders()
  for(pair in names(open.orders)){
    orders <- open.orders[[pair]]
    for(order in orders){
      order.number <- order$orderNumber
      if (!is.null(order.number)){
        result <- cancelOrder(order.number=order.number)
        print(result)
        Sys.sleep(0.2)
      }
    }
  }
}

transactAtMid <- function(pair=NULL, action="buy", units=0){
  
  if(action=="buy"){
    
  }
  if(action="sell"){
    
  }
  
}
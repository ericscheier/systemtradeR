# Function to generate the Kraken API signature
generate_exchange_signature <- function(url_path, data, secret) {
  message <- paste0(data$nonce, paste0(names(data), data, collapse = ""))
  secret <- base64_enc(charToRaw(secret))
  hash <- sha256(charToRaw(paste0(url_path, message)))
  hmac <- base64_enc(hmac(charToRaw(secret), hash, "sha512"))
  return(hmac)
}

get_spot_position <- function(currency_pair = "all") {
  url <- "https://api.kraken.com"
  path <- "/0/private/TradeBalance"
  nonce <- as.character(as.numeric(Sys.time()) * 1000)
  
  # Prepare POST data
  postdata <- list(
    nonce = nonce,
    asset = "base"
  )
  
  # Retrieve API credentials from the keyring
  kraken_key <- keyring::key_get("kraken_api_key")
  kraken_secret <- keyring::key_get("kraken_api_secret")
  
  # Create the signature
  signature <- generate_kraken_signature(path, postdata, kraken_secret)
  
  # Make the API request
  response <- POST(
    url = paste0(url, path),
    add_headers(
      "API-Key" = kraken_key,
      "API-Sign" = signature
    ),
    body = postdata,
    encode = "form"
  )
  
  # Parse the response
  result <- fromJSON(content(response, as = "text"))
  
  if (length(result$error) > 0 && result$error != "") {
    stop(paste("Kraken API Error:", paste(result$error, collapse = ", ")))
  }
  
  return(result$result)
}

# Example usage
#result <- get_spot_position()
#print(result)

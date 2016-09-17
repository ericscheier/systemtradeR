import requests
import json
import pandas as pd
from pandas.io.json import json_normalize
import time
import datetime
import os


# ticker_url = https://www.bitmex.com/api/v1/instrument/activeAndIndices
# r_tickers = requests.get(ticker_url)
# all_tickers = r_tickers.json()
# unique_tickers = list(all_tickers.keys())

tickers = ["XBTUSD","ETHXBT","LTCXBT","LSKXBT","FCTXBT"]
# ticker = tickers[1]

for ticker in tickers:
    print('Evaluating '+ticker)
    
    start = datetime.datetime(2012,04,25) #"1992-04-25"
    end = datetime.datetime.now()
    
    max_count = 500    
    
    hours_between = round((end - start).total_seconds() / (60*60))
    
    quotes_list = []
    while(hours_between > 0):
        # temp_start = 
        # &startTime='+temp_start.strftime("%Y-%m-%d")+'
        url = 'https://www.bitmex.com/api/v1/quote/bucketed?binSize=1h&symbol='+ticker+'&count='+str(max_count)+'&reverse=false&endTime='+end.strftime("%Y-%m-%d")
        # url = 'https://www.bitmex.com/api/v1/quote/bucketed?binSize=1h&symbol=XBTUSD&count=500&reverse=true&endTime=2016-05-01'
        r = requests.get(url)
        data = json_normalize(r.json())
        quotes_list.append(data)
        
        end = end - datetime.timedelta(hours=max_count)
        hours_between = round((end - start).total_seconds() / (60*60))        
        
        if(len(data)<max_count):
            hours_between = 0
    
    quotes = pd.concat(quotes_list)
    quotes.to_csv(ticker+'_quotes_bitMEX.csv')
    
    middle = (quotes["askPrice"]+quotes["bidPrice"])/2
    time_stamp = pd.to_datetime(quotes["timestamp"])
    middles = pd.DataFrame(middle, columns=["PRICE"])
    middles.index = time_stamp
    middles.index.rename("DATETIME", inplace=True)
    
    
    middles.to_csv(ticker+'_price.csv')
    

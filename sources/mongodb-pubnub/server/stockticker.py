import sys

import threading
from Queue import Queue

import time
import datetime
import random
import json

from Pubnub import Pubnub
import pymongo
from pymongo import DESCENDING


'''
Global Data - Queue
'''
globalQueueRef = None


'''
Client Listener Thread
'''
class ClientListenerThread(threading.Thread):

	def __init__(self,server,port,queueRef,pnb):
		threading.Thread.__init__(self)
		self.mongoconn = pymongo.MongoClient(server,port)
		self.db = self.mongoconn.stockdb
		self.coll = self.db.stockcollection

		self.clientQueue = queueRef 
		self.pnb = pnb

	def run(self):
		
		try :
			while True :
				print "Before queue block"
				data = self.clientQueue.get()
				print "After queue block"
				print data

				req = json.loads(data)
				

				self.publishPriceHistory(req['name'],req['backtime'],req['channel'])

		except Exception as e:
			print "Failure in Client Request Handling"
			print e

	def publishPriceHistory(self,idxname,time,channel):

		broadcastDict = []

		timefrom = self.getLastUpdateTime(idxname)

		timefrom = timefrom - (time * 60)

		it = self.coll.find({'name': idxname , 'time' : { '$gte' : timefrom } })

		for item in it:

			broadcastDict.append({ "name"   : item['name'],
						      "value"  : item['value'],
						      "change" : item['change'],
						      "time"   : item['time']
						})

		broadcastData = json.dumps(broadcastDict)
		print 'Broadcasting Price History : ' + broadcastData
		self.pnb.publish(channel,broadcastData)


	def getLastUpdateTime(self,idxname):
		
		query = [{'$group': {'_id': '$name', 'maxValue': {'$max': '$time'}}}]

		result = self.coll.aggregate(query)

		for entry in result['result']:
			if (entry['_id'] == idxname):
				return entry['maxValue'] 
			
		return None

'''
Description - Main server loop

Data will be stored in the following JSON format

	{
		"name"   : "NASDAQ"  ,
		"value"  : "6345.25" ,
		"change" : "+13.45"  ,
		"time"   : 1412322567
	}

'''
def startStockPicker(server,port):

	global globalQueueRef

	#Step 1 - Initialize MongoDB & PubNub Connection
	mongoconn = pymongo.MongoClient(server,port)
	db        = mongoconn.stockdb
	coll      = db.stockcollection 

	#Setup index on time to fetch the latest update
	coll.create_index([('time',DESCENDING)])

	#YOUR PUBNUB KEYS - Replace the publish_key and subscriber_key below with your own keys
	pubnub = Pubnub(publish_key="<your publish key>",subscribe_key="<your subscribe key>")

	#Step 2 - Check and define the metadata ( index names )
	metaDataInit(coll)

	#Step 3 - Set the parameters , max periodicity , random range
	updateTime = 10 #Max ten seconds for every price update
	numOfItems = 4  #Four indices to manage

	random.seed()

	#Step 4 - Setup the Queue and ClientListener Thread
	clientQueue = Queue()
	clientListener = ClientListenerThread(server,port,clientQueue,pubnub)
	clientListener.start()

	globalQueueRef = clientQueue

	#Step 5 - Setup PubNub Subscription for client requests
	pubnub.subscribe("stockhistory", historyCallback,historyError)

	#Step 6 - Start the stock picking loop
	while True:

		#Step 6.1 - Wait for random time
		time.sleep(random.randint(1,updateTime))
		
		#Step 6.2 - Wake up and update the stock price for one of the index
		newPriceData = getUpdatedPrice(coll)

		#Step 6.3 - Update the new price in DB
		print "New Price Update " + str(newPriceData)
		coll.insert(newPriceData)

		#Step 6.4 - Publish over Pubnub , stockdata channel
		broadcastData = { 'name'   : newPriceData['name'],
						  'value'  : newPriceData['value'],
						  'change' : newPriceData['change'],
						  'time' : newPriceData['time'],

						}

		pubnub.publish('stockdata',json.dumps(broadcastData))

		



'''
Description - Populate the index names to track and initial database
'''
def metaDataInit(coll):
	global metadataDescr

	#Four major world indices to manage
	metadataDescr = ['NASDAQ','DOWJONES','FTSE','NIKKEI']
		
	#Provision an initial value for each index if not present in DB
	if(coll.find({'name' : "NASDAQ"}).count() == 0):
		stock = {'name':'NASDAQ' , 'value':4630.60 , 'change':'+6.06' , 'time' : 1}
		coll.insert(stock)

	if(coll.find({'name' : "DOWJONES"}).count() == 0):
		stock = {'name':'DOWJONES' , 'value':17630.60 , 'change':'-36.02' , 'time' : 1}
		coll.insert(stock)	

	if(coll.find({'name' : "FTSE"}).count() == 0):
		stock = {'name':'FTSE' , 'value':6637.92 , 'change':'-16.02' , 'time' : 1}
		coll.insert(stock)	

	if(coll.find({'name' : "NIKKEI"}).count() == 0):
		stock = {'name':'NIKKEI' , 'value':17336.12 , 'change':'-23.02' , 'time' : 1}
		coll.insert(stock)	


'''
Description - This function simulates the stock index price update
			  Gets the new price details for indices based on random
			  selection

Return      - Returns the JSON formatted index name, price , delta and time
'''
def getUpdatedPrice(coll):
	
	#Random select the index whose price is to be updated
	idx = random.sample(metadataDescr,1)

	#Randomly get a price increment in range of 1.0 to 10.0
	#It is assumed that price delta will always be in this range
	pricedelta = round(random.uniform(1.0,10.0),2)

	#Randomly get the direction of price change
	#Either positive or negative
	pricedir = random.randint(0,1)

	#Get the current price of index
	currprice = getCurrentPrice(coll,idx[0])

	#Calculate new price of index based on pricedelta and pricedir
	if(pricedir):
		newprice = round(currprice + pricedelta,2)
		pricedeltastr = '+'+str(pricedelta)
	else :
		newprice = round(currprice - pricedelta,2)
		pricedeltastr = '-'+str(pricedelta)

	print "New Price for " + idx[0] + " : " + str(newprice)
	#Get the current time of update
	updateTime = getCurrentTimeInSecs()

	#Return the new index price
	return {
			'name'     : idx[0] ,
			'value'    : newprice ,
			'change'   : pricedeltastr ,
			'time'     : updateTime     
		}

'''
Description - This function fetches the most recent price update of 
              an index idxname 

Returns -  Last updated price
'''
def getCurrentPrice(coll,idxname):
	
	query = [{'$group': {'_id': '$name', 'maxValue': {'$max': '$time'}}}]

	result = coll.aggregate(query)

	for entry in result['result']:
		if (entry['_id'] == idxname):
			it = coll.find({'name' : idxname , 'time' : entry['maxValue'] }).limit(1)
			val =  it.next()['value']
			print "Last Updated Price for " + idxname + " : " + str(val)
			return val
	return None




'''
Description - Get the current system time in unix timestamp format
'''
def getCurrentTimeInSecs():
	
	dtime = datetime.datetime.now()

	ans_time = time.mktime(dtime.timetuple())	

	return int(ans_time)

'''
PubNub Callback for inciming requests on global listening channel
'''
def historyCallback(message, channel):
	global globalQueueRef

	print "Received Historical Data Request :" + message
	globalQueueRef.put(message) # Read end in the CLientListenerThread


def historyError(message):

	print "Error in receiving Historical Data Request : " + message

if __name__ == '__main__':

	print sys.argv
	if (len(sys.argv) == 3):
		
		startStockPicker(sys.argv[1],int(sys.argv[2]))
	else:
		print "Error in arguments"

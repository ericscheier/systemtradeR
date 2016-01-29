mongodb-pubnub
==============

MongoDB Integration with PubNub Data Stream

#INTRODUCTION
This application demonstrates the use of MongoDB database with PubNub data stream. With the help of PubNub data stream SDKs we can stream the data fetched from MongoDB to remote users.

This application builds a simple stockticker for fetching and dislaying major stock indices from the world. The application has two components.The server simulates a stock market feed and implements the PubNub broadcast server. The client runs as a front end web application for displaying the price counters and historical price trends.

#PRECONDITION

1. You will need a working MongoDB setup to run this application. You can get a free MongoDB cloud account through mms.mongodb.com
2. You will need python2 installed on the server computer with pymongo and PubNub's Python SDK installed. Refer to the official docs of PyMongo and PubNub SDKs for installation instructions
3. You will need a PubNub sandbox account to publish and subscribe your data. You need to add your publish and subscribe key on the server and client program. Search for the string "YOUR PUBNUB KEYS" in the code to locate the line where you need to add the keys". For more details refer the PubNub SDK documention for Python and Javascript.


#SETUP

##Server Setup
Open a console or terminal on the server and run the server program as follows ( Assuming that you are in the server directory)
> python stockticker.py MongoDB_Server_IP_Address MongoDB_Server_Port_Number

Where , MongoDB_Server_IP_Address is the IP address of the running MongoDB server instance and MongoDB_Server_Port_Number is the port number of that instance.

Make sure that the MongoDB server is up and running and the IP address and Port is correct. If anyone of these parameters is not in order then the server program will spew lots of errors on the console and eventually halt.   

If all goes well then you should see the console spring into action with index prices getting generated and populated in MongoDB 



##Client Setup
Open the index.html file under client folder in your favourite web browser. With the server running, you should see the index prices getting updated every few seconds. This is the realtime feed of PubNub which is getting broadcasted by the server and displayed by client.

Apart from this the client can also see the price trends. Click on the 'Trend' button against each index counter and see what happens. Behind the scenes, the client application requests the server for the last 30 minute price updates which the server honors by fetching it from MongoDB and returning the bunch of data to the client. On receiving this data , cient renders it as a mini trend chart showing the price trend of the last 30 mins. To go back to the initial price display , click the button again (now labelled as 'Counter')


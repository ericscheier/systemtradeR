#trader.python customized by genBTC 
(trades on Mt. Gox, Bitfloor,BTC-E & Bitstamp).(Bitfloor has shut down) (hard coded for USD)

Please read this README, don't skim it.
Most instructions are included in the source code(as docstrings) or by typing "help command" . Python Instructions (and Windows instructions) are located at the bottom of this README
Another project of mine: GoxGUI: https://github.com/genbtc/goxgui

------------------------------------------
## Includes frameworks (libs) for Mt.Gox, Bitfloor, BTC-E, Bitstamp
## Individual clients for each exchange (not possible for universal client at this time)
## All scripts located in bin\
## API Framework located in lib\
## Simple Example files in example\


##Features
###Secure Authentication 
via password using 256-bit AES Encryption of your API-key and API-secret. (see Usage->Login with API-key/secret)
###Automatic Dynamic Streaming Updates 
via the websocket(Socket.IO) - Mt.Gox
###Buy and sell bitcoins. 
Of course... - (manually)
###Stop Loss Orders. (Mt Gox)
A Stop Loss Bot! info below.
###Limit Orders & Market orders. 
Just omit a price to place a market order. 

-----------------------
##Commands: 

####" " is the command name, but in the program you have to use lowercase.
- [X] Tab completion of commands, and command history

- [x] **"Buy"/"Sell" Simple** - X amount of BTC   (or in USD - add usd to the command line)

- [x] **"Buy"/"Sell" Spread** - X amount of BTC between price A and price B of equally volumed specified # of chunks (use with the word 'random' to randomize this a bit)

- [x] **"Orders"** - List your orders, How many, & the Average Price (TODO: upgrade to API 2)

- [x] **"Cancel"** - Cancel a single order (or a range (ie order #1-#20)) - sorted by price and numbered for convenience. no need to use the order_id UUID.

- [x] **"Cancelall"** - Cancel ALL orders at once.

CancelUnFunded

CancelHalfFunded

CancelBuys

CancelSells

- [x] **"Balance"** - Display account balance (of BTC and USD) and USD value of BTC+USD

- [x] **"Ticker"/"Ticker2"** - Display ticker (sell,buy,last,vol,vwap,high,low,avg)	"the time frame for high, low, vol, avg, vwap ... is sliding 24 hours"-mtgox.

        also **"Tickerfast"** to use the most accurate ticker if there is lag (but does not give 24hour high/low/vol/avg/vwap)

- [x] **"Updown"** - Log the ticker to a file; Rising/Falling Beep Tones Sequences on boundary threshhold change. (also can check logs later)

- [x] **"Spread"** - Display the high bid/low ask and spread

- [x] **"Lag"** - Show the current Mt.Gox Lag (trading lag)

- [x] **"Book"** - Print the order books out to howmany length you want (Display depth) (current order book of bids/asks) = printorderbook()

        Mt Gox book is automatically updated with the freshest possible data by websocket(Socket.IO)

        "bookfull" downloads a new full book at most once every 3 minutes from HTTP that is independent of the socketbook.

        "bookquick" downloads a new quick depth from HTTP (API 0) every time the command is run (can be blank during lag)

        "bookrefresh" causes the socketbook to download a new full depth and rewrite the socket order book

- [x] **"Bookgroup"** - Print the order book(socketbook) with prices grouped as specified (ie: every 1.00 etc, or 0.1 0.05) with cumulative amounts (ie: ClarkMoody)

- [x] **"Withdraw"** - Withdraw bitcoins to an address(needs withdraw API priveleges in your mt.gox API security settings. (Currently available on bitfloor,bitstamp and mt.gox)

- [x] **"Getaddress"** - Generate a new bitcoin deposit address


###Depth Functions
- [x] **"Obip"** - Calculate the "order book implied price", by finding the weighted average price of coins <width> BTC up and down from the spread.

- [x] **"Asks"** - Calculate the amount of bitcoins for sale at or under <pricetarget>.

- [x] **"Bids"** - Calculate the amount of bitcoin demanded at or over <pricetarget>.



###Depth Subfunctions ("depth ____")
- [x] **"depth price"** calculate the total price of the order and the average weighted price of each bitcoin = depthprice()

- [x] **"depth range"** calculate and print the total BTC between price A and B = depthsumrange()

        Match any order to the opposite site of the order book (ie: if buying find a seller or vice versa) - market order

        Given the amount of BTC and price range, check to see if it can be filled as a market order


###Fee Submenu ("Fees")
- [x] **"Getfee"** - Find out your current fee rate (Mt.Gox's commission)

- [x] **"Fee"** (On Bitstamp) - Calculate your current trade fee based on past 30 day history and find out how far you are to your next fee tier

- [x] **"Amount"** - Calculate how much fees will cost on X amount

- [x] **"Price"** - Calculate the price you need to break even on a buy or sell

- [x] **"Balance"** - Calculate how much fees will cost if you sold off your entire BTC Balance


###History 
- [x] **"btchistory"** or **"usdhistory"** - Prints out your entire trading history of BTC transactions or USD, write it to a file, and do a small analysis (fees, BTC/$in, BTC/$out), and able to run analysis on a specified range to determine the VWAP buy/sell price of the trades in that range

- [x] **"tradehist24h"** - Download the entire trading history of everyone on Mt Gox for the past 24 hours, and write it to a file. 

- [x] **"readtradehist24h"** - Analyze the above trading history file (High/low/vwap/total/amounts/times)


###Automatic Bot Functions
- [x] **"When"** - 1) When ask/bid/last price is < or > a set price, execute a command of your choosing

        2) When an Order ID is fulfilled, execute any command (maybe another order for example, for linked Orders)


- [x] **"Balancenotifier"** - check balance every 30 seconds and beeps everytime your balance is added to (fully functional, and nice for day trading)

- [x] **"Stopbot"** = a stop loss bot! Finally, you can set your position price, position amount, and % willing to accept on your position. ie: 5 BTC @ $149 * 98% and the bot will put a market order in IMMEDIATELY (every 2 seconds it checks if the lowest seller is below your target percentage price, and if it is, sends the order immediately)

        (stopbot is for only mtgox so far - it is the only one to support a true market order)

- [x] **"Sellwhileaway"** - checks your balance and sells X amount at Price A (in case you have to leave the house and you are waiting on bitcoins to confirm) 

        Also Sellwhileaway2 (both are works in progress)

- [x] **"Liquidbot"** - a bot on bitfloor to add liquidity to the market by surfing the spread To take advantage of Bitfloor's 0.1% provider bonus therefore won't incur any trading fees 



####Old Description:
FEATURES:

* Diversify your position into "chunks" of a specified volume between price A and B. WORKS GREAT!  #spread trade function including Chunk Trade spread logic & Confirmation#
        
        (todo: check market conditions, use VWAP to pick, select desired patience level or instant gratification)

* Print the order books out to X length

* For Market Orders:

        Checks exact price (total and per bitcoin) @ Market prices by checking opposite Order Book depth for a given volume and price range (lower to upper) and alerts you if cannot be filled immediately, and lets you place a limit order instead

* Bitcoin Functions:

        Calculate and print the total BTC between price A and B

        Match any order to the opposite site of the order book (ie: if buying find a seller) - market order given the amount of BTC and price range check to see if it can be filled as a market order calculate the total price of the order and the average weighted price of each bitcoin 



-------------------------------
##PYTHON ON WINDOWS INFORMATION


Are you new to python? It's easy once you know what to do: 

1) Download Python 2.7.3 for Windows from http://www.python.org/download/  

Direct Link: http://www.python.org/ftp/python/2.7.3/python-2.7.3.msi

(i'm not sure about the X86-64 version, just get the 32 bit one)

2) Install it (normal dir is C:\python27\)

3) Download setuptools for Windows from https://pypi.python.org/pypi/setuptools

Direct Link: https://pypi.python.org/packages/2.7/s/setuptools/setuptools-0.6c11.win32-py2.7.exe

4) Install it.

5) Open a windows command prompt (cmd.exe).

You'll need to install some additional modules (supporting programs)

####At this point you'll need a compiler. Visual Studio 2010/2009. A free alternative is MingW32.

If you have one, run the following:
```
    C:\python27\scripts\easy_install.exe python-cjson 
    C:\python27\scripts\easy_install.exe websocket-client
    C:\python27\scripts\easy_install.exe requests
    C:\python27\scripts\easy_install.exe pyreadline 
    c:\python27\scripts\easy_install.exe pycrypto   
```

#### Here is the location of MingW32: http://www.mingw.org/wiki/Getting_Started

http://sourceforge.net/projects/mingw/files/Installer/mingw-get-inst/mingw-get-inst-20120426/mingw-get-inst-20120426.exe/download

**Another alternative**, is to download these packages as binaries, from: http://www.lfd.uci.edu/~gohlke/pythonlibs/

http://www.voidspace.org.uk/python/modules.shtml#pycrypto

http://www.voidspace.org.uk/downloads/pycrypto26/pycrypto-2.6.win32-py2.7.exe

```
pyreadline-1.7.1.win32.exe
python-cjson-1.0.3x7.win32-py2.7.exe
pycrypto-2.6.win32-py2.7.exe
```

Some of the .exe filenames are listed above (try to google or something).

Why all this? (If you don't have a compiler, you will get a vcvarsall.bat error. Googling this error will tell you something about needing Visual Studio, or downloading MingW32 instead.)

6) Download this entire git repository as a ZIP file. 

Direct Link: https://github.com/genbtc/trader.python/archive/master.zip

7) Extract this entire zip file to C:\python27\ (make sure it creates trader.python as a subdirectory)

8) Set your PYTHONPATH environment variables:

Temporarily (this command window only):

```	set PYTHONPATH=%PYTHONPATH%;C:\Python27\trader.python\lib\```

Permanently (in the registry):

```	setx PYTHONPATH %PYTHONPATH%```

10) Now you should be ready to run the scripts you want.

Run the scripts in the following manner:

```   
    cd \python27\trader.python\bin\
    python.exe mtgox_client.py
```

Phew! You're done.

--------------------------------------------------
##TO BEGIN - Usage: -> Logging in with API/Secret.


Windows binaries are included! (for encrypt_api_key, bitfloor_client, and mtgox_client, bitstamp_client) - Do not move these, they rely on each other, and "keys\"

Create a new API key on each website. If using Bitfloor, use the API password you assigned on the website. It will be required to use your API key.

encrypt_apikey.py:  	You need to generate encrypted keys beforehand with this command. Sometimes the generation does not work (just re-run this script; sometimes takes 2-3 times until it is verified)- [x] 


* Use bitfloor as the site name for Bitfloor

* Use mtgox as the site name for Mt. Gox	

* Use btc-e as the site name for BTC-E

* Use bitstamp as the site name for Bitstamp

Where it says "Enter an encryption password: (This is the password required to 	execute trades)"

    -For bitfloor this is your passphrase that you entered on the website.

    -For mtgox you Create your own password, just be sure to remember it.

    -For btce you Create your own password, just be sure to remember it.

    -For bitstamp, there is no API Key or Secret. Use your user ID in place of "API Key" and Password in place of "API Secret" . You should provide an entirely different password to access the encrypted password. (to add a layer of security)



-------------------------------------
##LIST OF FILES
-------------------------------------

###bin\

- [x] **encrypt_api_key.py** - REQUIRED to use this suite, generates an encrypted API key file in keys\ with the site name (see above) encrypted with a password

- [x] **bitfloor_client.py** - Advanced Trading on Bitfloor!

- [x] **mtgox_client.py** - Advanced Trading on Mt Gox!

- [x] **bitstamp_client.py** - Advanced Trading on Bitstamp!


- [x] **mtgox_simple.py** - CLI prompt for simple trading on mt.gox (simple, Buy/Sell, Amount, Price on mtgox)

- [x] **mtgox_socketiobeta.py** - A BETA socketio client (relies on bin/goxapi.py from prof7bit) Connects to the websockets, outputs the streaming data (ticker/trade/depth/lag)

        Logs to bin/goxtool.ini . CURRENTLY SET TO ONLY SCROLL PRINT OUT THE TRADES (the rest can be useless for my human eyes)

        (Lines 808/809 disabled the other two, Line 814 commented out channel_subscribe(), channel_subscribe has some commented out lines)

- [x] **mtgox_websockets.py** - A SAMPLE program (no error handling), that scroll prints 3 websocket channels (Ticker,trade,depth)

- [x] **bitfloor_cancel_all** - 3 lines of code to cancel every order on bitfloor (very simple, passes the cancel order function to the framework lib/bitfloor.py)

- [x] **bitfloor_check_orders** - print out current orders on bitfloor (simple, just prints out open orders)

- [x] **bitfloor_mirror_mtgox** - mirror the mt.gox order book over to bitfloor (NOT WORKING FULLY)

- [x] **bitfloor_rand_latency** - Test the ordering and cancellation latency on bitfloor (fairly non-useful since bitfloor latency is usually very low (~3 seconds))

- [x] **bitfloor_single** - CLI prompt for simple trade execution on bitfloor (simple, Buy/Sell, Amount, Price on bitfloor) 

- [x] **btce_show_info** - uses the framework of lib/btce.py to make several queries , like price ticker, open orders, order book, transaction history, etc

- [x] **btcerates.py** - uses the btce framework to display a chart of exchange rates between all the currency pairs

- [x] **tradehistory.py** - Was used as a self sufficient program at once, now is called by mtgox_client (this is the trade history analyzer that the "readtradehist24" command runs)

- [x] **bcfeed_sync** (taken from ga-bitbot) on github - Downloads a 160MB text file from bitcoincharts of every trade that ever happened in mtgox history, then rewrites it into a 1 minute spaced CSV file thats about 20MB. Have not utilized the data from this directly. data/download_mtgoxUSD.csv=160MB data/bcfeed_mtgoxUSD_1min.csv=18MB

- [x] **bcbookie** (taken from ga-bitbot) on github - NOT USED directly.

- [x] **goxcli** (taken from Trasp/GoxCLI) on github - NOT USED directly. -goxcli.xml datafile for goxcli - NOT USED

- [x] **analyzebotlog** - analyze liquidbotlog.txt and write a "filled.txt" file of all completed orders<-- not really needed anymore since I have created a successlog.txt instead


###example\

- [x] **readbitfloorcsv** - Fee reports. 1) Download the CSV of your account history statement.(havent automated this part) 2) This program will go through the file, turn it into a properly formatted list of dictionaries, Scan it for all the fees, and print out the Fee Report. sample at http://pastebin.ca/2344564

- [x] **mtgox_lagalarm** - Reads the lag HTTP API and beeps when lag surpasses a certain threshold

- [x] **mtgox_tickeralarm** - Reads the ticker streaming websocket and beeps when the ticker crosses a threshhold

- [x] **add_cancel** - adds an order on bitfloor and immediately cancels it

- [x] **bitfloor_smallorder** - a stub to show you how to use the bitfloor api

- [x] **latency** - places and cancels orders on bitfloor to check the latency - not very useful since latency is usually below 300ms.



###lib\

- [x] **unlock_api_key.py** - Decrypts the encrypted API keys that we make from keys\

- [x] **mtgoxhmac.py** - Actual Mt.Gox Framework that should be used to make API calls (Uses combination of API2, API1, and API0 )

- [x] **bitstampapi.py** - Bitstamp Framework with all API calls

- [x] **bitfloorapi.py** - Bitfloor Framework with all API calls

- [x] **btceapi.py** - BTC-E Framework with all api calls (some HTTP error checking)

- [x] **book.py** -  will parse the json order book in standard form

- [x] **common.py** - Common trading functionality was merged in here for bitfloor_client.py and mtgox_client.py

- [x] **depthparser.py** - imported a portion of goxcli into this file for use in mtgox. 

- [x] **json_ascii.py** - json decode strings as ascii instead of unicode

- [x] **liquidbot.py**  		>	Both of these are taken from https://github.com/chrisacheson/liquidbot  (working on adding my own liquidbot to bitfloor)

- [x] **mtgox2.py** - an alternate Mt.gox framework

- [x] **goxapi** (taken from prof7bit's goxtool) on github - NOT USED directly. 

- [x] **websocket.py** (websocket-client-0.10.0) included so this package is not required.



###data\

- [x] **nonce_state_btce** - required for the btce framework to generate a nonce(Saving this to a file is useful, since if the nonce messes up you have to recreate the API key)

- [x] **mtgox_entiretrades.txt** - written when you call tradehist24 (downloads the 24 hour trading history of mtgox)

- [x] **mtgox_fulldepth.txt** - written when you call bookfull (downloads the HTTP API fulldepth - not relied on much)


###keys\

- [x] **{exchange}_key.txt and {exchange}_salt.txt**  - this is what is written by encrypt_apikey and what is used to unlock your API keys to access the trading console


### Programming Functions: (Common.py)

* **"floatify"** - turn a whole list or tuple into a float

* **"decimalify"** - turn a whole list or tuple into a decimal

* **"mean"** - get the mean of an entire list or tuple

* **"ppdict"** and **"pwdict"** - pretty print and pretty write a dict


--------------------------------
##NOT implemented
--------------------------------

- [ ] Abort commands with SIGINT (ctrl-c on - [x] nix) without exiting, f Mt. Gox is being slow (soon)

(doesn't exit when NOT busy but will exit if in the middle of a single transaction like a buy)

- [ ] Sequence multiple commands using semicolons

- [ ] Calculate profitable short/long prices from an initial price

- [ ] Asynchronus HTTP Implementation to pipeline web requests (using twisted.web)

- [ ] Modifying strategy.

- [ ] optional trade Wait time (default to instant gratification) 


-------------------------------
##ADDENDUM
-------------------------------
(The following solution is to enable persistent command history tab completion on windows with the "pyreadline" module)

This command only enables command history INSIDE the python interpreter(which is not what we want).
```
    copy "C:\Python27\Lib\site-packages\pyreadline\configuration\pyreadlineconfig.ini" %USERPROFILE%
    copy "C:\Python27\Lib\site-packages\pyreadline\configuration\startup.py" %USERPROFILE%\.pythonstartup
    set PYTHONSTARTUP=%USERPROFILE%\\.pythonstartup
    setx PYTHONSTARTUP %PYTHONSTARTUP%
```

To keep the program up to date, GIT is recommended. Once you have the repo set up locally: type:
```
    git stash
    git pull
    git apply pop
```
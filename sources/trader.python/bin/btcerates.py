import httplib
import urllib
import urllib2
import json
import hashlib
import hmac
import time
import os
if os.name == 'nt':
    import winsound


import unlock_api_key 



fullpath = os.path.dirname(os.path.realpath(__file__))
if os.name == 'nt':
    partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
    partialpath=os.path.join(fullpath + '/../data/')
BTC_api_key,BTC_api_secret,unused = unlock_api_key.unlock("btc-e") 

#you must have a nonce_state_btce file located in your ..\data\ directory with an integer number inside the file  
def nonce_generator():
    fd = open(os.path.join(partialpath + 'nonce_state_btce') ,'r')
    nonce = int(fd.read())
    fd.close()
    while (True):
        nonce = nonce+1
        fd = open(os.path.join(partialpath + 'nonce_state_btce'),'w')
        fd.write(str(nonce))
        fd.close()
        yield nonce

def btcepost(method) :
    nonce = nonce_generator()
 
    # method name and nonce go into the POST parameters
    params = {"method": method,
              "nonce": nonce.next()}
    params = urllib.urlencode(params)
 
    # Hash the params string to produce the Sign header value
    H = hmac.new(str(BTC_api_secret), digestmod=hashlib.sha512)
    H.update(params)
    sign = H.hexdigest()
 
    headers = {"Content-type": "application/x-www-form-urlencoded",
                       "Key":BTC_api_key,
                       "Sign":sign}
    while True:
        conn = httplib.HTTPSConnection("btc-e.com")
        conn.request("POST", "/tapi", params, headers)
        response = conn.getresponse()
        if response.status==200:
            break
        conn.close()
        print "*",
        time.sleep(1)
 
    a = json.load(response)
 
    conn.close()
    return a
 
 
 
def get_trades(pair):
    url='https://btc-e.com/api/2/'+pair+'/depth'
    req = urllib2.Request(url)
    opener = urllib2.build_opener()
    f = opener.open(req)
    x=f.read()
    y=json.loads(x)
 
    z=[ y['bids'][0], y['asks'][0]]
    return z
   
 
 
 
def ac(ret=0):
    k={}
    t={'btc':0, 'ltc':0, 'usd':0, 'rur':0, 'nmc':0}
    print 'BTC-E Accounter. v.0.6g'
    print '(C) Nov-2012 ob1kenobi (skype aldis.rigerts)'
    print "Modified 3-21-2013 genBTC"
    print
    print 'Connecting to BTC-E ... ',
   
    while True:
        try:
            x=btcepost("getInfo")
 
            time.sleep(0.2)
            y=btcepost("OrderList")
 
            time.sleep(0.2)
            z=btcepost("getInfo")
 
            if x['return']['funds'] != z['return']['funds']:
                time.sleep(0.2)
                continue
 
            xa=z['return']['funds']
 
            if y['success']!=0 or y['error']!='no orders':
                for order in y['return']:
                    o=y['return'][order]
                    if o['type'] == 'sell':
                        v=o['pair'][0:3]
                        am=o['amount']
                    elif o['type'] == 'buy':
                        v=o['pair'][4:7]
                        am=o['amount']*o['rate']
                    else:
                        print '*',
                        raise
 
                    x['return']['funds'][v] = x['return']['funds'][v]+am
 
            p='btc_usd'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
 
            p='btc_rur'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
           
            p='btc_eur'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
           
            p='ltc_btc'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
           
            p='ltc_usd'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
 
            p='ltc_rur'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
 
            p='nmc_btc'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
 
            p='usd_rur'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
           
            p='eur_usd'
            q=get_trades(p)
            k[p]=(q[0][0]+q[1][0])/2.
 
            xf=x['return']['funds']
            k['eur_ltc']=1./k['btc_eur']/k['ltc_btc']
            k['eur_rur']=(k['eur_usd']*k['usd_rur'] + k['btc_rur']/k['btc_eur'])/2.
            k['nmc_ltc']=k['nmc_btc']/k['ltc_btc']
            k['nmc_usd']=k['nmc_btc']*k['btc_usd']
            k['nmc_rur']=k['nmc_btc']*k['btc_rur']
            k['nmc_eur']=k['nmc_btc']*k['btc_eur']
 
           
            t['btc']=xf['btc']+xf['ltc']*k['ltc_btc']+xf['usd']/k['btc_usd']+xf['rur']/k['btc_rur']+xf['nmc']*k['nmc_btc']+xf['eur']/k['btc_eur']
            t['ltc']=xf['btc']/k['ltc_btc']+xf['ltc']+xf['usd']/k['ltc_usd']+xf['rur']/k['ltc_rur']+xf['nmc']*k['nmc_ltc']+xf['eur']*k['eur_ltc']
            t['usd']=xf['btc']*k['btc_usd']+xf['ltc']*k['ltc_usd']+xf['usd']+xf['rur']/k['usd_rur']+xf['nmc']*k['nmc_usd']+xf['eur']*k['eur_usd']
            t['rur']=xf['btc']*k['btc_rur']+xf['ltc']*k['ltc_rur']+xf['usd']*k['usd_rur']+xf['rur']+xf['nmc']*k['nmc_rur']+xf['eur']*k['eur_rur']
            t['nmc']=xf['btc']/k['nmc_btc']+xf['ltc']/k['nmc_ltc']+xf['usd']/k['nmc_usd']+xf['rur']/k['nmc_rur']+xf['nmc']+xf['eur']/k['nmc_eur']
            t['eur']=xf['btc']*k['btc_eur']+xf['ltc']/k['eur_ltc']+xf['usd']/k['eur_usd']+xf['rur']/k['eur_rur']+xf['nmc']*k['nmc_eur']+xf['eur']
           
           
            print
            print
            print 'Rates:'
            for kk in k:
                print '{0:7}  => {1:10.4f}  {2:10.4f}'.format(kk, k[kk], 1./k[kk])
 
            print
            print 'Funds:\t\tAvailable\tTotal\tConverted'
            for kk in xf:
                print '{0:3} =  {1:11.3f}  {2:11.3f}  {3:11.3f}'.format(kk, xa[kk], xf[kk], t[kk])
 
            if ret==0:
                return
            else:
                return xf
       
        except KeyboardInterrupt:
            print 'Canceled by user'
            raise KeyboardInterrupt
       
        except:
            print '.',
            time.sleep(1)
 
 
 
def ac_auto(x):
    tot=0
    while True:
        try:
            new_tot=ac(ret=1)
            print
            if new_tot!=tot:
                tot=new_tot
                if os.name == 'nt':
                    winsound.Beep(1000,300)
                    winsound.Beep(500,300)
                else:
                    print "\a\a"
            time.sleep(x)               
        except KeyboardInterrupt:
            print 'Canceled by user'
            return
        except:
            continue

if __name__ == "__main__":
    ac_auto(5)
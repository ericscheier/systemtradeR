import hmac
import hashlib
import base64
import urllib
import httplib
import time
import json
import json_ascii
import copy
import decimal
from decimal import Decimal as D
import os
import unlock_api_key


config = {
    "host": "api.bitfloor.com",
    "data_port": 443,
    "order_port": 443,
    "version": 1
    }

HTTPConn = httplib.HTTPSConnection

class Client(object):
    def __init__(self,encpassword=""):
        self._key,self._secret,self._passphrase = unlock_api_key.unlock("bitfloor",encpassword)
        self._product_id = 1    #the 1 means "product_ID" is USD (currently our only option anyway)
        self._inc = D('0.01')   # (the currency precision) TODO: get from bitfloor(can't yet)
        self.cPrec = D('0.01')
        self.bPrec = D('0.00001')

    def book(self, level=1):
        url = '/book/L{1}/{0}'.format(self._product_id, level)
        return self._send_get(url)

    def entirebook(self, level=2):  #not needed at all (made because did not understand that book(2) does this)
        url = '/book/L2/1'
        return self._send_get(url)

    def dayinfo(self):
        url = '/day-info/{0}'.format(self._product_id)
        return self._send_get(url)

    def ticker(self):
        url = '/ticker/{0}'.format(self._product_id)
        return self._send_get(url)

    def trades(self):
        url = '/history/{0}'.format(self._product_id)
        return self._send_get(url)

    def buy(self, **kwargs):
        return self.order_new(side=0, **kwargs)

    def sell(self, **kwargs):
        return self.order_new(side=1, **kwargs)

    def order_new(self, side, size, price):
        return self._send_post('/order/new', {
            'product_id': self._product_id,
            'side': side,
            'size': size,
            'price': price
        })

    def order_info(self,order_id):
        return self._send_post('/order/details', {
            'order_id': order_id
        })

    def orders(self):
        return self._send_post('/orders')

    def order_cancel(self, order_id):
        return self._send_post('/order/cancel', {
            'product_id': self._product_id,
            'order_id': order_id
        })

    def cancel_all(self):
        orders = self.orders()
        for order in orders:
            x = self.order_cancel(order['order_id'])
            print x
        if orders:
            print "All Orders have been Cancelled!!!!!"
        else:
            print "No Orders found!!"

    def accounts(self):
        return self._send_post('/accounts')

    def bitcoin_withdraw(self,address,amount):
        return self._send_post('/withdraw', {
            'currency': 'BTC',
            'amount': amount,
            'method': 'bitcoin',
            'destination':address
        })

    def _send_get(self, url, payload={}):
        try:
            body = urllib.urlencode(payload)
            conn = HTTPConn(config['host'], config['data_port'])
            conn.request("GET", url, body)
            resp = conn.getresponse()
            s = resp.read()
            conn.close()
            return json.loads(s, object_hook=json_ascii.decode_dict)
        except Exception as e:
            print e

    def _send_post(self, url, payload={}):
        try:
            payload = copy.copy(payload) # avoid modifying the original dict

            # add some stuff to the payload
            payload['nonce'] = int(time.time()*1e6)

            body = urllib.urlencode(payload)

            sig = hmac.new(base64.b64decode(self._secret), body, hashlib.sha512).digest()
            sig_b64 = base64.b64encode(sig)

            headers = {
                'bitfloor-key': self._key,
                'bitfloor-sign': sig_b64,
                'bitfloor-passphrase': self._passphrase,
                'bitfloor-version': config['version'],
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': len(body)
            }

            conn = HTTPConn(config['host'], config['order_port'])
            conn.request("POST", url, body, headers)
            resp = conn.getresponse()
            s = resp.read()
            conn.close()
            return json.loads(s, object_hook=json_ascii.decode_dict)
        except Exception as e:
            print e


    def floor_inc(self, n):
        return (D(str(n))/self._inc).quantize(D('1'), rounding=decimal.ROUND_DOWN)*self._inc

    def ceil_inc(self, n):
        return (D(str(n))/self._inc).quantize(D('1'), rounding=decimal.ROUND_UP)*self._inc

    def round_inc(self, n):
        return (D(str(n))/self._inc).quantize(D('1'))*self._inc    

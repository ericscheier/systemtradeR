"""
encrypt_api_key 
Copyright 2011 Brian Monkaba
VERSION 0.3 REVISED by genBTC 
"""
from Crypto.Cipher import AES
import hashlib
import json
import time
import random
import os
import getpass
import base64
import sys



def lock():
    print "\n\ngenbtc.trader API Key Encryptor v0.3"
    print "-" * 30
    print "\n\n"

    print "Enter the API KEY:"
    key = raw_input().strip()

    print "\nEnter the API SECRET KEY:"
    secret = raw_input().strip()

    print "Enter the site:"
    site = raw_input().strip()

    print "\n\nEnter an encryption password:"
    print "(This is the password required to execute trades)"
    password = getpass.getpass().strip()                #uses raw_input() but doesnt keep a history

    print "\nGenerating the random salt..."
    salt = os.urandom(32)                   #requires Python 2.4  = 32 bytes or 256 bits of randomness
    """salt = hashlib.sha512(pre_salt).digest()    #hashing does not add any new randomness """
    fullpath = os.path.dirname(os.path.realpath(__file__))
    if ".exe" in sys.argv[0]:
        partialpath=os.path.join(fullpath + '\\keys\\' + site)
    elif os.name == 'nt':
        partialpath=os.path.join(fullpath + '\\..\\keys\\' + site)
    else:
        partialpath=os.path.join(fullpath + '/../keys/' + site)
    f = open(os.path.join(partialpath + '_salt.txt'),'w')
    f.write(salt)
    f.close()

    print "Generating the password hash..."
    hash_pass = hashlib.sha512(password.encode("utf-8") + salt).digest()
    crypt_key = hash_pass[:32]
    crypt_ini = hash_pass[-16:]
       
    aes = AES.new(crypt_key, AES.MODE_OFB, crypt_ini)        #create the AES container
    plaintext = json.dumps({"key":key,"secret":secret})

    #new way to pad. Uses 32 block length for the cipher 256 bit AES
    #chr(32) happens to be spacebar... (padding with spaces)
    pad = lambda s: s + (32 - len(s) % 32) * chr(32)        # function to pad the password 
    paddedtext = pad(plaintext)

    ciphertext = aes.encrypt(paddedtext)                    #go ahead and encrypt it
    print "Length after encryption =",len(ciphertext)

    print "Generating the encrypted API KEY file located in: %r" % (partialpath)
    f = open(os.path.join(partialpath + '_key.txt'),'w')
    print "Writing encryption key to file..."
    f.write(ciphertext)
    f.close()

    print "\n\nAttempting to verify encrypted files..."
    f = open(os.path.join(partialpath + '_key.txt'),'r')
    filedata = f.read()
    f.close()
    f = open(os.path.join(partialpath + '_salt.txt'),'r')
    filesalt = f.read()
    f.close()

    typo=True
    while typo==True:
        print "\nRe-enter your password to confirm:"
        newpassword = getpass.getpass().strip()                    #Just to check for typos
        if newpassword == password:
            typo=False
        else:
            failed("Incorrect password!!!!")

    hash_pass = hashlib.sha512(password.encode("utf-8") + filesalt).digest()     #create the AES container    
    crypt_key = hash_pass[:32]
    crypt_ini = hash_pass[-16:]
    decryptor = AES.new(crypt_key, AES.MODE_OFB, crypt_ini)

    def failed (message):
        os.remove(os.path.join(partialpath + '_key.txt'))
        os.remove(os.path.join(partialpath + '_salt.txt'))
        print "Failed verification due to %r. Please re-run again." % (message)
        
    print "File Read Verification Length = ",len(filedata)
    if len(filedata)%16 == 0:
        try:
            filekeys = decryptor.decrypt(filedata)          #go ahead and decrypt the file
        except: 
            failed("Failed AES Decryption")
        try:
            data = json.loads(filekeys)                     #convert the string to a dict
        except:
            failed("Failed JSON Decoding")
        else:
            if data['key'] == key and data['secret'] == secret:
                print "\nPASSED Verification!!!!!!!!!!!!"
                print "\nDon't forget your password. This is what is REQUIRED to enable trading."
            else:
                failed("Failed API Key Verification")
    else:
        failed("Length was not 160. Make sure Length=160 or some multiple of 16.")

if __name__ == "__main__":
    lock()
#converts bitcoincharts csv download into the 
#1min format used by the genetic trade framework
from time import *
import urllib2
import sys
import datetime
import time
import io
import gzip
import os
__app_version__ = "0.03"

print """
Bitcoin Data Feed Synchronizer v%s

\tConverts the data into a weighted price 1min data feed format

Automaticaly downloads and processes the mtgox usd historic data from bitcoincharts. 
"""%(__app_version__)

link = """http://bitcoincharts.com/t/trades.csv?symbol=mtgoxUSD&start={START_TIME}"""
start_time = 0 		
auto_move_output = 1
begintiming = time.time()

fullpath = os.path.dirname(os.path.realpath(__file__))
if os.name == 'nt':
    partialpath=os.path.join(fullpath + '\\..\\data\\')
else:
    partialpath=os.path.join(fullpath + '/../data/')
    
try:
    for line in open(os.path.join(partialpath + 'download_mtgoxUSD.csv')):pass
    line = line.split(',')[0]
    line = line.split('.')[0]
    start_time = int(line) + 1
    incremental_update = 1
    print "The last time in the file was %s aka %s" % (start_time-1,datetime.datetime.fromtimestamp(start_time-1))
except:
    print "Incremental update not possible."
    pass
print "Downloading mtgox historic data..."
link = link.replace('{START_TIME}',str(start_time))
req = urllib2.Request(link)
req.add_header('Accept-encoding', 'gzip')
resp = urllib2.urlopen(req)
# Un-Gzip the response
if resp.info().get('Content-Encoding') == 'gzip':
    print "Used GZIP encoding for a fast download."
    buf = io.BytesIO(resp.read())
    resp = gzip.GzipFile(fileobj=buf)
data = resp.read()
f = open(os.path.join(partialpath + "download_mtgoxUSD.csv"),'a')
if data:
    f.write('\n')
    f.write(data)
f.close()

print "Download complete."

f = open(os.path.join(partialpath + "download_mtgoxUSD.csv"),'r')
d = f.readlines()
f.close()

print "Processing input..."
one_min = []
accum_r = []
#exception handling to address issue #11 - unhandled exception when download or input file has no data
try:
    last_t = d[0].split(',')[0]
except:
    print "No new data to process"
    sys.exit()

last_m = ctime(int(last_t)).split(':')[1]
for r in d:
    sr = r.replace('\n','').split(',')
    t,p,v = sr
    if (ctime(int(t)).split(':')[1] == last_m):
        accum_r.append(map(float,sr))
    else:
        tv = 0
        twp = 0
        for r in accum_r:
            #print r
            twp += (r[1] * r[2])
            tv += r[2]
        if tv > 0:
            wp = twp / tv
            one_min.append([last_t,wp,tv])
            #print last_t,wp,tv
        accum_r = [map(float,sr)]
    
    last_t = int(t)
    last_m = ctime(last_t).split(':')[1]

print "Writing output file..."
print "Updating the data directory directly...no need to manualy move the output file"

f = open(os.path.join(partialpath + "bcfeed_mtgoxUSD_1min.csv"),'w')

for t,p,v in one_min:
    f.write(",".join(map(str,[t,p,v])) + '\n')
f.close()
print "Done. The last time in the file was %s aka %s" % (t,datetime.datetime.fromtimestamp(t))
endtiming = time.time()
print "Began at: ",begintiming, " Ended at: ", endtiming, "Total Time: ", endtiming-begintiming    

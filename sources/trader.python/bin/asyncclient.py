from twisted.python import log
from twisted.internet import reactor
from twisted.internet.defer import Deferred, CancelledError
from twisted.internet.error import TimeoutError, AlreadyCalled
from twisted.internet.protocol import Protocol
from twisted.web.client import Agent, HTTPConnectionPool

class BeginningPrinter(Protocol):
    def __init__(self, finished):
        self.finished = finished
        self.remaining = 1024 * 10

    def dataReceived(self, bytes):
        if self.remaining:
            display = bytes[:self.remaining]
            log.msg('Some data received: %r' % (display,))
            self.remaining -= len(display)

    def connectionLost(self, reason):
        log.msg('Finished receiving body: %s %s' % (reason.type, reason.value))
        self.finished.callback(None)


def printBody(response):
    log.msg('got response: %s %s' % (response.code, response.phrase))
    finished = Deferred()
    response.deliverBody(BeginningPrinter(finished))
    return finished

def tryRequestUntilSuccess(agent, *a, **kw):
    d = Deferred()
    _retrying = object()

    def _requestErrback(failure):
        if failure.check(CancelledError, TimeoutError):
            log.err(failure, 'retrying after error requesting %r %r' % (a, kw))
            _makeRequest()
            return _retrying
        else:
            d.errback(failure)

    def _requestCallback(result):
        if result is not _retrying:
            d.callback(result)

    def _makeRequest():
        requestDeferred = agent.request(*a, **kw).addCallbacks(_requestCallback, _requestErrback)
        canceller = reactor.callLater(10, requestDeferred.cancel)
        def _cancelCancellation(result):
            try:
                canceller.cancel()
            except AlreadyCalled:
                pass
            return result
        requestDeferred.addBoth(_cancelCancellation)

    _makeRequest()
    return d

def main():
    pool = HTTPConnectionPool(reactor)
    agent = Agent(reactor, connectTimeout=10, pool=pool)

    d = tryRequestUntilSuccess(agent, 'GET', 'http://data.mtgox.com/api/0/data/ticker.php')
    d.addCallback(printBody)
    d.addErrback(log.err, 'error fetching ticker')
    d.addCallback(lambda ignored: reactor.stop())
    reactor.run()

if __name__ == "__main__":
    import sys
    log.startLogging(sys.stderr)
    main()
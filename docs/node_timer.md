# Timers#

## clearImmediate(immediateObject) ??? #
Stops an immediate from triggering.

## clearInterval(intervalObject)#
Stops an interval from triggering.

## clearTimeout(timeoutObject)#
Prevents a timeout from triggering.

## ref() ???#
If you had previously unref()d a timer you can call ref() to explicitly request the timer hold the program open. If the timer is already refd calling ref again will have no effect.

Returns the timer.

## setImmediate(callback[, arg][, ...])#
To schedule the "immediate" execution of callback after I/O events callbacks and before setTimeout and setInterval. Returns an immediateObject for possible use with clearImmediate(). Optionally you can also pass arguments to the callback.

Callbacks for immediates are queued in the order in which they were created. The entire callback queue is processed every event loop iteration. If you queue an immediate from inside an executing callback, that immediate won't fire until the next event loop iteration.

## setInterval(delay, callback[, arg][, ...])#
To schedule the repeated execution of callback every delay milliseconds. Returns a intervalObject for possible use with clearInterval(). Optionally you can also pass arguments to the callback.

To follow browser behavior, when using delays larger than 2147483647 milliseconds (approximately 25 days) or less than 1, Node.js will use 1 as the delay.

## setTimeout(delay, callback[, arg][, ...])#
To schedule execution of a one-time callback after delay milliseconds. Returns a timeoutObject for possible use with clearTimeout(). Optionally you can also pass arguments to the callback.

The callback will likely not be invoked in precisely delay milliseconds. Node.js makes no guarantees about the exact timing of when callbacks will fire, nor of their ordering. The callback will be called as close as possible to the time specified.

To follow browser behavior, when using delays larger than 2147483647 milliseconds (approximately 25 days) or less than 1, the timeout is executed immediately, as if the delay was set to 1.

## unref() ???#
The opaque value returned by `setTimeout` and `setInterval` also has the method timer.unref() which will allow you to create a timer that is active but if it is the only item left in the event loop, it won't keep the program running. If the timer is already unrefd calling unref again will have no effect.

In the case of setTimeout when you unref you create a separate timer that will wakeup the event loop, creating too many of these may adversely effect event loop performance -- use wisely.

Returns the timer.
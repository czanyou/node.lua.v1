--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local core  = require('core')
local timer = require('timer')

local Stream = require('stream/stream_core').Stream
local Error  = core.Error

---============================================================================
--- WriteRequest

local WriteReq = core.Object:extend()

function WriteReq:initialize(chunk, callback)
    self.chunk    = chunk
    self.callback = callback
end

---============================================================================
--- WritableState

local WritableState = core.Object:extend()

function WritableState:initialize(options, stream)
    options = options or { }

    --[[
  // object stream flag to indicate whether or not this stream
  // contains buffers or objects.
  --]]
    self.objectMode = not not options.objectMode

    if core.instanceof(stream, require('stream/stream_duplex').Duplex) then
        self.objectMode = self.objectMode or not not options.writableObjectMode
    end

    --[[
  // the point at which write() starts returning false
  // Note: 0 is a valid value, means that we always return false if
  // the entire buffer is not flushed immediately on write()
  --]]
    local hwm = options.highWaterMark
    local defaultHwm
    if self.objectMode then
        defaultHwm = 16
    else
        defaultHwm = 16 * 1024
    end
    self.highWaterMark = hwm or defaultHwm

    self.needDrain = false

    -- at the start of calling end()
    self.ending = false

    -- when end() has been called, and returned
    self.ended = false

    -- when 'finish' is emitted
    self.finished = false

    --[[
  // not an actual buffer we keep track of, but a measurement
  // of how much we're waiting to get pushed to some underlying
  // socket or file.
  --]]
    self.length = 0

    -- a flag to see when we're in the middle of a write.
    self.writing = false

    -- when true all writes will be buffered until .uncork() call
    self.corked = 0

    --[[
  // a flag to be able to tell if the onwrite cb is called immediately,
  // or on a later tick.  We set this to true at first, because any
  // actions that shouldn't happen until "later" should generally also
  // not happen before the first write call.
  --]]
    self.sync = true

    --[[
  // a flag to know if we're processing previously buffered items, which
  // may call the _write() callback in the same tick, so that we don't
  // end up in an overlapped onwrite situation.
  --]]
    self.bufferProcessing = false

    --[[
  // the callback that's passed to _write(chunk,cb)
  --]]
    self.onwrite = function(err)
        stream:_onWriteCompleted(err)
    end

    --[[
  // the callback that the user supplies to write(chunk,encoding,cb)
  --]]
    self.writecb = nil

    --[[
  // the amount that is being written when _write is called.
  --]]
    self.writelen = 0

    -- buffer
    self.buffer = { }

    --[[
  // number of pending user-supplied write callbacks
  // this must be 0 before 'finish' can be emitted
  --]]
    self.pendingcb = 0

    --[[
  // emit prefinish if the only thing we're waiting for is _write cbs
  // This is relevant for synchronous Transform streams
  --]]
    self.prefinished = false

    -- True if the error was already emitted and should not be thrown again
    self.errorEmitted = false
end

---============================================================================
--- Writable
--[[
    The Writable stream interface is an abstraction for a destination that you 
    are writing data to.
    
]]

local Writable = Stream:extend()

function Writable:initialize(options)
    --[[
  // Writable ctor is applied to Duplexes, though they're not
  // instanceof Writable, they're instanceof Readable.
  if (!(this instanceof Writable) && !(this instanceof Stream.Duplex))
    return new Writable(options)
  --]]

    self._writableState = WritableState:new(options, self)

    if (type(Stream.initialize) == 'function') then
        Stream.initialize(self)
    end
end

--[[
// Otherwise people can pipe Writable streams, which is just wrong.
--]]
function Writable:pipe()
    self:emit('error', Error:new('Cannot pipe. Not readable.'))
end

--[[

  返回 true, 表示还可以继续写数据, 返回 false 表示缓存队列已满, 
  最好等待 'drain' 事件再写.
]]
function Writable:write(chunk, callback)
    local state = self._writableState
    local ret = false

    if type(callback) ~= 'function' then
        callback = function() end
    end

    if state.ended then
        self:_writeAfterEnd(state, callback)

    elseif self:_isValidChunk(state, chunk, callback) then
        state.pendingcb = state.pendingcb + 1
        ret = self:_writeOrBuffer(state, chunk, callback)
    end

    return ret
end

function Writable:finish()
    self:_end()
end

--[[
    Forces buffering of all writes.
    Buffered data will be flushed either at .uncork() or at .end() call.
]]
function Writable:cork()
    local state = self._writableState

    state.corked = state.corked + 1
end

--[[
    Flush all data, buffered since .cork() call.
]]
function Writable:uncork()
    local state = self._writableState

    if state.corked ~= 0 then
        state.corked = state.corked - 1

        if not state.writing and
            state.corked == 0 and
            not state.finished and
            not state.bufferProcessing and
            #(state.buffer) ~= 0 then
            self:_flushBuffer(state)
        end
    end
end

function Writable:_decodeChunk(state, chunk)

    --[[
  if (!state.objectMode &&
      state.decodeStrings !== false &&
      util.isString(chunk)) {
    chunk = new Buffer(chunk)
  }
--]]
    return chunk
end

--[[
    Call this method when no more data will be written to the stream. If 
    supplied, the callback is attached as a listener on the finish event.

    @param chunk String | Buffer Optional data to write
    @param callback Function Optional callback for when the stream is finished
]]
function Writable:_end(chunk, callback)
    local state = self._writableState

    if type(chunk) == 'function' then
        callback = chunk
        chunk = nil
    end

    if chunk ~= nil then
        self:write(chunk)
    end

    --[[
    // .end() fully uncorks
    --]]
    if state.corked ~= 0 then
        state.corked = 1
        self:uncork()
    end

    --[[
    // ignore unnecessary end() calls.
    --]]
    if (not state.ending) and (not state.finished) then
        self:_endWritable(callback)
    end
end

function Writable:_endWritable(callback)
    local state = self._writableState

    state.ending = true
    self:_maybeFinish(state)
    if callback then
        if state.finished then
            timer.setImmediate(callback)
        else
            self:once('finish', callback)
        end
    end
    state.ended = true
    self:emit('end')
end

--[[
// if there's something in the buffer waiting, then process it
--]]
function Writable:_flushBuffer(state)
    state.bufferProcessing = true

    if self._writev and #(state.buffer) > 1 then
        --[[
    // Fast case, write everything using _writev()
    --]]
        local cbs = { }
        for c = 1, #(state.buffer) do
            table.insert(cbs, state.buffer[c].callback)
        end

        --[[
    // count the one we are adding, as well.
    // TODO(isaacs) clean this up
    --]]
        state.pendingcb = state.pendingcb + 1
        self:_onWrite(state, true, state.length, state.buffer, '', function(err)
            for i = 1, #(cbs) do
                state.pendingcb = state.pendingcb - 1
                cbs[i](err)
            end
        end )

        --[[
    // Clear buffer
    --]]
        state.buffer = { }
    else
        --[[
    // Slow case, write chunks one-by-one
    --]]
        local c = 1
        while c <= #(state.buffer) do
            local entry = state.buffer[c]
            local chunk = entry.chunk
            local cb = entry.callback
            local len
            if state.objectMode then
                len = 1
            else
                len = string.len(chunk)
            end

            self:_onWrite(state, false, len, chunk, cb)

            --[[
      // if we didn't call the onwrite immediately, then
      // it means that we need to wait until it does.
      // also, that means that the chunk and cb are currently
      // being processed, so move the buffer counter past them.
      --]]
            if state.writing then
                c = c + 1
                break
            end
            c = c + 1
        end

        if c <= #(state.buffer) then
            -- node.js: state.buffer = state.buffer.slice(c)
            for i = 1, c - 1 do
                table.remove(state.buffer, 1)
            end
        else
            state.buffer = { }
        end
    end

    state.bufferProcessing = false
end

--[[
// If we get something that is not a buffer, string, null, or undefined,
// and we're not in objectMode, then that's an error.
// Otherwise stream chunks are all considered to be of length=1, and the
// watermarks determine how many objects to keep in the buffer, rather than
// how many bytes or characters.
--]]
function Writable:_isValidChunk(state, chunk, callback)
    local valid = true
    if (chunk ~= nil) and (type(chunk) ~= 'string') and not state.objectMode then
        local err = Error:new('Invalid non-string/buffer chunk')
        self:emit('error', err)
        timer.setImmediate(function()
            callback(err)
        end )
        valid = false
    end
    return valid
end

function Writable:_onWrite(state, writev, len, chunk, callback)
    state.writelen = len
    state.writecb  = callback
    state.writing  = true
    state.sync     = true

    if writev then
        self:_writev(chunk, state.onwrite)
    else
        self:_write (chunk, state.onwrite)
    end

    state.sync     = false
end

function Writable:_onWriteAfter(state, finished, callback)
    if not finished then
        self:_onWriteDrain(state)
    end

    state.pendingcb = state.pendingcb - 1
    callback()

    self:_maybeFinish(state)
end

--[[
// Must force callback to be called on nextTick, so that we don't
// emit 'drain' before the write() consumer gets the 'false' return
// value, and has a chance to attach a 'drain' listener.
--]]
function Writable:_onWriteDrain(state)
    if (state.length == 0) and state.needDrain then
        state.needDrain = false
        self:emit('drain')
    end
end

function Writable:_onWriteError(state, error, callback)
    if state.sync then
        timer.setImmediate(function()
            state.pendingcb = state.pendingcb - 1
            callback(error)
        end )
    else
        state.pendingcb = state.pendingcb - 1
        callback(error)
    end

    state.errorEmitted = true
    self:emit('error', error)
end

function Writable:_onWriteCompleted(err)
    local state    = self._writableState
    local sync     = state.sync
    local callback = state.writecb

    state.length   = state.length - state.writelen
    state.writelen = 0
    state.writing  = false
    state.writecb  = nil    

    if err then
        self:_onWriteError(state, err, callback)
        return
    end

    --[[
    // Check if we're actually ready to finish, but don't emit yet
    --]]
    local finished = self:_needFinish(state)
    if (not finished)
        and (state.corked == 0) 
        and (not state.bufferProcessing) 
        and (#(state.buffer) ~= 0) then
        self:_flushBuffer(state)
    end

    if sync then
        timer.setImmediate(function()
            self:_onWriteAfter(state, finished, callback)
        end )
    else
        self:_onWriteAfter(state, finished, callback)
    end
end

function Writable:_maybeFinish()
    local state = self._writableState

    local need = self:_needFinish(state)
    if need then
        if not state.prefinished then
            state.prefinished = true
            self:emit('prefinish')
        end    

        if state.pendingcb == 0 then
            state.finished = true
            self:emit('finish')
        end
    end
    return need
end

function Writable:_needFinish(state)
    return state.ending 
        and (state.length == 0) 
        and (#(state.buffer) == 0) 
        and (not state.finished) 
        and (not state.writing)
end

function Writable:_write(chunk, callback)
    callback(Error:new('not implemented'))
end

Writable._writev = nil

function Writable:_writeAfterEnd(state, callback)
    local err = Error:new('write after end')
    --[[
    // TODO: defer error events consistently everywhere, not just the cb
    --]]
    self:emit('error', err)
    timer.setImmediate( function()
        callback(err)
    end )
end

--[[
// if we're already writing something, then just put this
// in the queue, and wait our turn.  Otherwise, call _write
// If we return false, then we need a drain event, so set that flag.
--]]
function Writable:_writeOrBuffer(state, chunk, callback)
    chunk = self:_decodeChunk(state, chunk)

    local len
    if state.objectMode then
        len = 1
    else
        len = string.len(chunk)
    end

    state.length = state.length + len

    local ret = state.length < state.highWaterMark
    -- we must ensure that previous needDrain will not be reset to false.
    if not ret then
        state.needDrain = true
    end

    if state.writing or (state.corked ~= 0) then
        table.insert(state.buffer, WriteReq:new(chunk, callback))
    else
        self:_onWrite(state, false, len, chunk, callback)
    end

    return ret
end

local exports = { }
exports.WriteReq      = WriteReq
exports.WritableState = WritableState
exports.Writable      = Writable
return exports;

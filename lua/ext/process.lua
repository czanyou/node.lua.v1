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

--[[
The process object is a global object and can be accessed from anywhere. It is 
an instance of EventEmitter.
--]]

local meta = { }
meta.name       = "luvit/process"
meta.version    = "1.1.1-7"
meta.license    = "Apache 2"
meta.homepage   = "https://github.com/luvit/luvit/blob/master/deps/process.lua"
meta.description = "Node-style global process table for luvit"
meta.tags       = { "luvit", "process" }

local exports = { meta = meta }

local env       = require('env')
local timer     = require('timer')
local utils     = require('utils')
local uv        = require('uv')
local pprint    = require('ext/print')
local hooks     = require('ext/hooks')

local Emitter   = require('core').Emitter
local Readable  = require('stream').Readable
local Writable  = require('stream').Writable

local lenv = { }
function lenv.get(key)
    return lenv[key]
end

setmetatable(lenv, {
    __pairs = function(table)
        local keys = env.keys()
        local index = 0
        return function(...)
            index = index + 1
            local name = keys[index]
            if name then
                return name, table[name]
            end
        end
    end,
    __index = function(table, key)
        return env.get(key)
    end,
    __newindex = function(table, key, value)
        if value then
            env.set(key, value, 1)
        else
            env.unset(key)
        end
    end
} )

local function process_nextTick(...)
    timer.setImmediate(...)
end

local function process_kill(pid, signal)
    uv.kill(pid, signal or 'sigterm')
end

local signalWraps = { }

local function process_on(self, _type, listener)
    if _type == "error" or _type == "exit" then
        Emitter.on(self, _type, listener)
    else
        if not signalWraps[_type] then
            local signal = uv.new_signal()
            signalWraps[_type] = signal
            uv.unref(signal)
            uv.signal_start(signal, _type, function() self:emit(_type) end)
        end
        Emitter.on(self, _type, listener)
    end
end

local function process_exit(self, code)
    local left = 2
    code = code or 0
    local function onFinish()
        left = left - 1
        if left > 0 then return end
        self:emit('exit', code)
        os.exit(code)
    end
    process.stdout:once('finish', onFinish)
    process.stdout:_end()
    process.stderr:once('finish', onFinish)
    process.stderr:_end()
end

local function removeListener(self, _type, listener)
    local signal = signalWraps[_type]
    if not signal then return end
    signal:stop()
    uv.close(signal)
    signalWraps[_type] = nil
    Emitter.removeListener(self, _type, listener)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local UvStreamWritable = Writable:extend()

function UvStreamWritable:initialize(handle)
    Writable.initialize(self)
    self.handle = handle
end

function UvStreamWritable:_write(data, callback)
    uv.write(self.handle, data, callback)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --


local UvStreamReadable = Readable:extend()
function UvStreamReadable:initialize(handle)
    Readable.initialize(self, { highWaterMark = 0 })
    self._readableState.reading = false
    self.reading = false
    self.handle  = handle
    self:on('pause', utils.bind(self._onPause, self))
end

function UvStreamReadable:_onPause()
    self._readableState.reading = false
    self.reading = false
    uv.read_stop(self.handle)
end

function UvStreamReadable:_read(n)
    local function onRead(err, data)
        if err then
            return self:emit('error', err)
        end
        self:push(data)
    end
    if not uv.is_active(self.handle) then
        self.reading = true
        uv.read_start(self.handle, onRead)
    end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local function globalProcess()
    local process = Emitter:new()
    process.argv        = arg
    process.exitCode    = 0
    process.nextTick    = process_nextTick
    process.env         = lenv
    process.cwd         = uv.cwd
    process.chdir       = uv.chdir
    process.exepath     = uv.exepath
    process.kill        = process_kill
    process.pid         = uv.getpid()
    process.on          = process_on
    process.exit        = process_exit
    process.stdin       = UvStreamReadable:new(pprint.stdin)
    process.stdout      = UvStreamWritable:new(pprint.stdout)
    process.stderr      = UvStreamWritable:new(pprint.stderr)

    process.removeListener = removeListener

    hooks:on('process.exit', utils.bind(process.emit, process, 'exit'))
    return process
end

exports.globalProcess = globalProcess
exports.argv        = arg
exports.chdir       = uv.chdir
exports.cwd         = uv.cwd
exports.env         = lenv
exports.exepath     = uv.exepath
exports.exitCode    = 0
exports.kill        = process_kill
exports.nextTick    = process_nextTick
exports.pid         = uv.getpid()

return exports
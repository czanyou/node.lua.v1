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

local env       = require('env')
local uv        = require('uv')
local Emitter   = require('core').Emitter

local process   = Emitter:new()
local exports   = process

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- env

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

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local function process_nextTick(...)
    local timer = require('timer')
    timer.setImmediate(...)
end

local function process_kill(pid, signal)
    uv.kill(pid, signal or 'sigterm')
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

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

    if (process.stdout) then
        process.stdout:once('finish', onFinish)
        process.stdout:_end()
        
    else 
        onFinish()
    end

    if (process.stderr) then
        process.stderr:once('finish', onFinish)
        process.stderr:_end()

    else 
        onFinish()
    end
end

local function process_remove_listener(self, _type, listener)
    local signal = signalWraps[_type]
    if not signal then return end
    signal:stop()
    uv.close(signal)
    signalWraps[_type] = nil

    Emitter.removeListener(self, _type, listener)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--[[
exports = { meta = exports }

local Emitter = require('core').Emitter
setmetatable(exports, Emitter.meta)
if exports.init then exports:init() end
]]

--
exports.argv        = arg or {}         -- 
exports.chdir       = uv.chdir          -- Changes the current working directory of the process or throws an exception if that fails.
exports.cwd         = uv.cwd            -- Returns the current working directory of the process.
exports.env         = lenv              -- An object containing the user environment. See environ(7).
exports.exepath     = uv.exepath        -- 
exports.exitCode    = 0                 -- 
exports.hrtime      = uv.hrtime         -- Returns the current high-resolution real time
exports.kill        = process_kill      -- Send a signal to a process. 
exports.nextTick    = process_nextTick  -- Once the current event loop turn runs to completion, call the callback function.
exports.now         = uv.now            -- 
exports.pid         = uv.getpid()       -- The PID of the process.
exports.uptime      = uv.uptime         -- Number of seconds Node.lua has been running.
exports.version     = nil               -- A compiled-in property that exposes NODE_VERSION.
exports.versions    = nil               -- A property exposing version strings of Node.lua and its dependencies.
-- 
process.exit        = process_exit
process.on          = process_on
process.removeListener = process_remove_listener

-- hooks:on('process.exit', utils.bind(process.emit, process, 'exit'))

return exports
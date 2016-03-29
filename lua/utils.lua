--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.

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
local meta = { }
meta.name       = "luvit/utils"
meta.version    = "1.0.0-4"
meta.license    = "Apache 2"
meta.homepage   = "https://github.com/luvit/luvit/blob/master/deps/utils.lua"
meta.description = "Wrapper around pretty-print with extra tools for luvit"
meta.tags       = { "luvit", "bind", "adapter" }

local exports = { meta = meta }

local Error  = require('core').Error
local Object = require('core').Object

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local pprint = require('ext/print')
for name, value in pairs(pprint) do
    exports[name] = value
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

--[[
    为回调函数绑定 self 
]]
local function bind(fn, self, ...)
    assert(fn, "fn is nil")
    local bindArgsLength = select("#", ...)

    -- Simple binding, just inserts self (or one arg or any kind)
    if bindArgsLength == 0 then
        return function(...)
            return fn(self, ...)
        end
    end

    -- More complex binding inserts arbitrary number of args into call.
    local bindArgs = { ... }
    return function(...)
        local argsLength = select("#", ...)
        local args = { ... }
        local arguments = { }
        for i = 1, bindArgsLength do
            arguments[i] = bindArgs[i]
        end

        for i = 1, argsLength do
            arguments[i + bindArgsLength] = args[i]
        end
        
        return fn(self, table.unpack(arguments, 1, bindArgsLength + argsLength))
    end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

--[[
    无操作处理器
]]
local function noop(err)
    if err then print("Unhandled callback error", err) end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

--[[
    适配器方法
    @param callback
    @param function
    @param args
]]
local function adapt(callback, func, ...)
    local nargs = select('#', ...)
    local args = { ... }
    -- No continuation defaults to noop callback
    if not callback then callback = noop end

    local t = type(callback)
    if t == 'function' then
        args[nargs + 1] = callback
        -- exports.pprint(args)
        return func(table.unpack(args))

    elseif t ~= 'thread' then
        error("Illegal continuation type " .. t)
    end

    local err, data, waiting
    args[nargs + 1] = function(e, ...)
        if waiting then
            if e then
                assert(coroutine.resume(callback, nil, e))
            else
                assert(coroutine.resume(callback, ...))
            end
        else
            err, data = e and Error:new(e), { ...}
            callback = nil
        end
    end

    func(table.unpack(args))
    if callback then
        waiting = true
        return coroutine.yield(callback)
    elseif err then
        return nil, err
    else
        return table.unpack(data)
    end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local function deep_equal(expected, actual, path)
    if expected == actual then
        return true
    end

    local prefix = path and (path .. ": ") or ""
    local expectedType = type(expected)
    local actualType = type(actual)
    if expectedType ~= actualType then
        return false, prefix .. "Expected type " .. expectedType .. " but found " .. actualType
    end

    if expectedType ~= "table" then
        return false, prefix .. "Expected " .. tostring(expected) .. " but found " .. tostring(actual)
    end

    local expectedLength = #expected
    local actualLength = #actual
    for key in pairs(expected) do
        if actual[key] == nil then
            return false, prefix .. "Missing table key " .. key
        end

        local newPath = path and (path .. '.' .. key) or key
        local same, message = deep_equal(expected[key], actual[key], newPath)
        if not same then
            return same, message
        end
    end

    if expectedLength ~= actualLength then
        return false, prefix .. "Expected table length " .. expectedLength .. " but found " .. actualLength
    end

    for key in pairs(actual) do
        if expected[key] == nil then
            return false, prefix .. "Unexpected table key " .. key
        end
    end
    return true
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local StringBuffer = Object:extend()
exports.StringBuffer = StringBuffer

function StringBuffer:initialize(text)
    self.list = {}
    if (text) then
        table.insert(self.list, text)
    end
end

function StringBuffer:append(value)
    if (value) then
        table.insert(self.list, value)
    end

    return self
end

function StringBuffer:toString()
    return table.concat(self.list)
end

exports.bind        = bind
exports.noop        = noop
exports.adapt       = adapt
exports.deep_equal  = deep_equal

return exports

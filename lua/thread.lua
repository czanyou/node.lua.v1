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

--- luvit thread management

local meta = { }
meta.name       = "luvit/thread"
meta.version    = "0.1.2"
meta.license    = "Apache 2"
meta.homepage   = "https://github.com/luvit/luvit/blob/master/deps/thread.lua"
meta.description = "thread module for luvit"
meta.tags       = { "luvit", "thread", "threadpool", "work" }

local exports = { meta = meta }

local uv = require('uv')
local Object = require('core').Object

---============================================================================
--- luvit thread

exports.start = function(thread_func, ...)
    local dumped = type(thread_func) == 'function'
        and string.dump(thread_func) or thread_func

        -- print('dumped:' .. dumped)

    local function thread_entry(dumped, ...)
        -- Run function with require injected
        local fn = load(dumped)
        fn(...)

        -- Start new event loop for thread.
        require('uv').run()
    end

    return uv.new_thread(thread_entry, dumped, ...)
end

exports.join = function(thread)
    return uv.thread_join(thread)
end

exports.equals = function(thread1, thread2)
    return uv.thread_equals(thread1, thread2)
end

exports.self = function()
    return uv.thread_self()
end

exports.sleep = uv.sleep

---============================================================================
--- luvit threadpool

local Worker = Object:extend()

function Worker:queue(...)
    uv.queue_work(self.handler, self.dumped, ...)
end

exports.work = function(thread_func, notify_entry)
    local worker = Worker:new()
    worker.dumped = type(thread_func) == 'function'
        and string.dump(thread_func) or thread_func

    local function thread_entry(dumped, ...)
        if not _G._uv_works then
            _G._uv_works = { }
        end

        -- try to find cached function entry
        local fn
        if not _G._uv_works[dumped] then
            fn = load(dumped)

            -- cache it
            _G._uv_works[dumped] = fn
        else
            fn = _G._uv_works[dumped]
        end
        -- Run function

        return fn(...)
    end

    worker.handler = uv.new_work(thread_entry, notify_entry)
    return worker
end

exports.queue = function(worker, ...)
    worker:queue(...)
end

return exports

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
meta.name        = "luvit/buffer"
meta.version     = "1.0.1-3"
meta.license     = "Apache 2"
meta.homepage    = "https://github.com/luvit/luvit/blob/master/deps/buffer.lua"
meta.description = "A mutable buffer using ffi for luvit."
meta.tags        = { "luvit", "buffer" }

local exports = { meta = meta }
local buffer = exports

local uv = require('uv')
local lutils = require('lutils')
local utils = require('utils')
local Object = require('core').Object

local function compliment8(value)
    return (value < 0x80) and value or (-0x100 + value)
end

local function compliment16(value)
    return (value < 0x8000) and value or (-0x10000 + value)
end

local function compliment32(value)
    return (value < 0x80000000) and value or (-0x100000000 + value)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Buffer 是一个直接处理二进制数据的类
-- @param size Number 分配一个新的大小是 size 的缓存区. 
-- @param str String 分配一个新的 buffer，其中包含着给定的 str 字符串
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local Buffer = Object:extend()
buffer.Buffer = Buffer

--[[
    1 <= position <= limit <= length
]]
function Buffer:initialize(param)
    if type(param) == "number" then
        self.length     = param
        self._position  = 1  -- 
        self._limit     = 1  -- 
        self.buffer     = lutils.new_buffer(param + 1)

    elseif type(param) == "string" then
        self.length     = #param
        self._position  = 1
        self._limit     = self.length + 1
        self.buffer     = lutils.new_buffer(self.length + 1)
        self.buffer:put_bytes(1, param, 1, #param)

    else
        error("Input must be a string or number")
    end
end

function Buffer.meta:__concat(other)
    return tostring(self) .. tostring(other)
end

function Buffer.meta:__index(key)
    if type(key) == "number" then
        if key < 1 or key > self.length then error("Index out of bounds") end

        local position = self._position + key - 1
        return self.buffer:get_byte(position)
    end
    return Buffer[key]
end

function Buffer.meta:__ipairs()
    local index = 1
    return function()
        if index <= self.length then
            index = index + 1
            return index, self.buffer.get_byte(index)
        end
    end
end

function Buffer.meta:__newindex(key, value)
    if type(key) == "number" then
        if key < 1 or key > self.length then error("Index out of bounds") end

        local position = self._position + key - 1
        self.buffer:put_byte(position, value)
        return
    end

    rawset(self, key, value)
end

function Buffer.meta:__tostring()
    return self.buffer:get_bytes(self._position, self._limit - self._position)
end

function Buffer:compress()
    if (self:isEmpty()) then
        return
    end

    local size = self._limit - self._position
    if (self._position > 1) and (size > 0) then
        self.buffer:move(1, self._position, size)

        self._position = 1
        self._limit = self._position + size
    end
end

function Buffer:concat(list, totalLength)
    -- TODO:
end

function Buffer:copy(targetBuffer, targetStart, sourceStart, sourceEnd)
    local count = sourceEnd - sourceStart + 1;
    return targetBuffer.buffer:copy(targetStart, self.buffer, sourceStart, count)
end

function Buffer:expand(size)
    if (size <= 0) then
        return 0

    elseif (self._limit + size > self.length + 1) then
        return 0
    end

    self:limit(self:limit() + size)
    return size
end

function Buffer:fill(value, startPos, endPos)
    if (endPos < startPos) then
        return 
    end

    local startPosition = self._position + startPos - 1
    return self.buffer:fill(value, startPosition, endPos - startPos + 1)
end

function Buffer:inspect()
    local parts = { }
    for i = 1, tonumber(self.length) do
        parts[i] = bit.tohex(self[i], 2)
    end
    return "<Buffer " .. table.concat(parts, " ") .. ">"
end

function Buffer:isEmpty()
    return self._position == self._limit
end

function Buffer:limit(limit)
    if (not limit) then
        return self._limit
    end

    if (limit >= 1 and limit <= self.length + 1) then
        self._limit = limit
    end
end

function Buffer:position(position)
    if (not position) then
        return self._position
    end

    if (position >= 1 and position <= self.length) then
        self._position = position
    end
end

function Buffer:put(key, value)
    local position = self._position + key
    return self.buffer:put_byte(position, value)
end

function Buffer:putBytes(offset, data)
    return self.buffer:put_bytes(self._position + offset - 1, data, 1, #data)
end

function Buffer:putBytes2(offset, data, startPos, endPos)
    return self.buffer:put_bytes(self._position + offset - 1, data, startPos, endPos - startPos + 1)
end

function Buffer:readInt8(offset)
    return compliment8(self[offset])
end

function Buffer:readInt16BE(offset)
    return compliment16(self:readUInt16BE(offset))
end

function Buffer:readInt16LE(offset)
    return compliment16(self:readUInt16LE(offset))
end

function Buffer:readInt32BE(offset)
    return compliment32(self:readUInt32BE(offset))
end

function Buffer:readInt32LE(offset)
    return compliment32(self:readUInt32LE(offset))
end

function Buffer:readUInt8(offset)
    return self[offset]
end

function Buffer:readUInt16BE(offset)
    return (self[offset] << 8) + self[offset + 1]
end

function Buffer:readUInt16LE(offset)
    return (self[offset + 1] << 8) + self[offset]
end

function Buffer:readUInt32BE(offset)
    return self[offset] * 0x1000000 +
    (self[offset + 1] << 16) +
    (self[offset + 2] << 8) +
    self[offset + 3]
end

function Buffer:readUInt32LE(offset)
    return self[offset + 3] * 0x1000000 +
    (self[offset + 2] << 16) +
    (self[offset + 1] << 8) +
    self[offset]
end

function Buffer:size()
    return self._limit - self._position
end

function Buffer:skip(size)
    if (size <= 0) then
        return 0

    elseif (self._position + size > self._limit) then
        return 0
    end

    self:position(self:position() + size)

    if (self._limit == self._position) then
        self._position = 1
        self._limit = 1
    end

    return size
end

function Buffer:slice(startPos, endPos)
    -- TODO: 
end

function Buffer:toString(i, j)
    local offset    = i and i or 1
    local position  = self._position + offset - 1
    local size      = j and (j - i + 1) or (self._limit - position)
    return self.buffer:get_bytes(position, size)
end

function Buffer:write(data, offset, length)
    local position = self._position
    return self.buffer:put_bytes(position, data, offset, length)
end

return exports

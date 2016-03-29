--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

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
This module provides utilities for dealing with query strings. It provides 
the following methods:


--]]
local meta = { }
meta.name       = "luvit/querystring"
meta.version    = "1.0.2"
meta.license    = "Apache 2"
meta.homepage   = "https://github.com/luvit/luvit/blob/master/deps/querystring.lua"
meta.description = "Node-style query-string codec for luvit"
meta.tags       = { "luvit", "url", "codec" }

local exports = { meta = meta }

--[[
The unescape function used by querystring.parse, provided so that it could be 
overridden if necessary.

It will try to use decodeURIComponent in the first place, but if that fails it 
falls back to a safer equivalent that doesn't throw on malformed URLs.
--]]
function exports.urldecode(str)
    str = str:gsub('+', ' ')
    str = str:gsub('%%(%x%x)', function(h)
        return string.char(tonumber(h, 16))
    end )
    str = str:gsub('\r\n', '\n')
    return str
end

--[[
The escape function used by querystring.stringify, provided so that it could be 
overridden if necessary.
--]]
function exports.urlencode(str)
    if str then
        str = str:gsub('\n', '\r\n')
        str = str:gsub('([^%w])', function(c)
            return string.format('%%%02X', string.byte(c))
        end )
    end
    return str
end

local function stringifyPrimitive(v)
    return tostring(v)
end

--[[
Serialize an object to a query string. Optionally override the default separator 
('&') and assignment ('=') characters.

Options object may contain encodeURIComponent property (querystring.escape by 
default), it can be used to encode string with non-utf8 encoding if necessary.
--]]
function exports.stringify(params, sep, eq)
    if not sep then sep = '&' end
    if not eq then eq = '=' end
    if type(params) == "table" then
        local fields = { }
        for key, value in pairs(params) do
            local keyString = exports.urlencode(stringifyPrimitive(key)) .. eq
            if type(value) == "table" then
                for _, v in ipairs(value) do
                    table.insert(fields, keyString .. exports.urlencode(stringifyPrimitive(v)))
                end
            else
                table.insert(fields, keyString .. exports.urlencode(stringifyPrimitive(value)))
            end
        end
        return table.concat(fields, sep)
    end
    return ''
end

--[[
Parse querystring into table. urldecode tokens

Deserialize a query string to an object. Optionally override the default 
separator ('&') and assignment ('=') characters.

Options object may contain maxKeys property (equal to 1000 by default), it'll 
be used to limit processed keys. Set it to 0 to remove key count limitation.

Options object may contain decodeURIComponent property (querystring.unescape 
by default), it can be used to decode a non-utf8 encoding string if necessary.
--]]
function exports.parse(str, sep, eq)
    if not sep then sep = '&' end
    if not eq then eq = '=' end
    local vars = { }
    str = tostring(str)
    for pair in str:gmatch('[^' .. sep .. ']+') do
        if not pair:find(eq) then
            vars[exports.urldecode(pair)] = ''
        else
            local key, value = pair:match('([^' .. eq .. ']*)' .. eq .. '(.*)')
            if key then
                key = exports.urldecode(key)
                value = exports.urldecode(value)
                local type = type(vars[key])
                if type == 'nil' then
                    vars[key] = value
                elseif type == 'table' then
                    table.insert(vars[key], value)
                else
                    vars[key] = { vars[key], value }
                end
            end
        end
    end
    return vars
end

return exports;
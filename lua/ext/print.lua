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
meta.name        = "luvit/pretty-print"
meta.version     = "1.0.4"
meta.homepage    = "https://github.com/luvit/luvit/blob/master/deps/pretty-print.lua"
meta.description = "A lua value pretty printer and colorizer for terminals."
meta.tags        = { "colors", "tty" }
meta.license     = "Apache 2"
meta.author      = { name = "Tim Caswell" }

local exports = { meta = meta }

local uv  = require('uv')
local env = require('env')

local prettyPrint, dump, strip, color, colorize, loadColors, printBuffer

local theme         = { }
local useColors     = false
local useStream     = false
local defaultTheme  = nil

local stdout, stdin, stderr, width

local quote, quote2, dquote, dquote2, obracket, cbracket, obrace, cbrace, comma, equals, controls

local themes = {
    -- nice color theme using 16 ansi colors
    [16] =
    {
        property = "0;37",
        -- white
        sep = "1;30",
        -- bright-black
        braces = "1;30",
        -- bright-black

        ["nil"] = "1;30",
        -- bright-black
        boolean = "0;33",
        -- yellow
        number = "1;33",
        -- bright-yellow
        string = "0;32",
        -- green
        quotes = "1;32",
        -- bright-green
        escape = "1;32",
        -- bright-green
        ["function"] = "0;35",
        -- purple
        thread = "1;35",
        -- bright-purple

        table = "1;34",
        -- bright blue
        userdata = "1;36",
        -- bright cyan
        cdata = "0;36",
        -- cyan

        err = "1;31",
        -- bright red
        success = "1;33;42",
        -- bright-yellow on green
        failure = "1;33;41",
        -- bright-yellow on red
        highlight = "1;36;44",-- bright-cyan on blue
    },
    -- nice color theme using ansi 256-mode colors
    [256] =
    {
        property = "38;5;253",
        braces = "38;5;247",
        sep = "38;5;240",

        ["nil"] = "38;5;244",
        boolean = "38;5;220",
        -- yellow-orange
        number = "38;5;202",
        -- orange
        string = "38;5;34",
        -- darker green
        quotes = "38;5;40",
        -- green
        escape = "38;5;46",
        -- bright green
        ["function"] = "38;5;129",
        -- purple
        thread = "38;5;199",
        -- pink

        table = "38;5;27",
        -- blue
        userdata = "38;5;39",
        -- blue2
        cdata = "38;5;69",
        -- teal

        err = "38;5;196",
        -- bright red
        success = "38;5;120;48;5;22",
        -- bright green on dark green
        failure = "38;5;215;48;5;52",
        -- bright red on dark red
        highlight = "38;5;45;48;5;236",-- bright teal on dark grey
    },
}

local special = {
    [7]  = 'a',
    [8]  = 'b',
    [9]  = 't',
    [10] = 'n',
    [11] = 'v',
    [12] = 'f',
    [13] = 'r'
}

local function stringEscape(c)
    return controls[string.byte(c, 1)]
end

function loadDefault()
    quote    = "'"
    quote2   = "'"
    dquote   = '"'
    dquote2  = '"'
    obrace   = "{"
    cbrace   = "}"
    obracket = "["
    cbracket = "]"
    comma    = ", "
    equals   = " = "
end

function loadColors(index)
    if index == nil then index = defaultTheme end

    -- Remove the old theme
    for key in pairs(theme) do
        theme[key] = nil
    end

    if index then
        local new = themes[index]
        if not new then error("Invalid theme index: " .. tostring(index)) end
        -- Add the new theme
        for key in pairs(new) do
            theme[key] = new[key]
        end
        useColors = true

    else
        useColors = false
    end

    quote    = colorize('quotes', "'", 'string')
    quote2   = colorize('quotes', "'")
    dquote   = colorize('quotes', '"', 'string')
    dquote2  = colorize('quotes', '"')
    obrace   = colorize('braces', '{ ')
    cbrace   = colorize('braces', '}')
    obracket = colorize('property', '[')
    cbracket = colorize('property', ']')
    comma    = colorize('sep', ', ')
    equals   = colorize('sep', ' = ')

    controls = { }

    for i = 0, 31 do
        local c = special[i]
        if not c then
            c = string.format("x%02x", i)
        end
        controls[i] = colorize('escape', '\\' .. c, 'string')
    end

    controls[39] = colorize('escape', "\\'", 'string')

    for i = 128, 255 do
        local c = string.format("x%02x", i)
        controls[i] = colorize('escape', '\\' .. c, 'string')
    end
end

function color(colorName)
    return '\27[' ..(theme[colorName] or '0') .. 'm'
end

function colorize(colorName, string, resetName)
    if (useColors) then
        return color(colorName) .. tostring(string) .. color(resetName)
    else
        return tostring(string)
    end 
end

function dump(value, recurse, nocolor)
    local seen   = { }
    local output = { }
    local offset = 0
    local stack  = { }

    local process_value

    local function recalcOffset(index)
        for i = index + 1, #output do
            local m = string.match(output[i], "\n([^\n]*)$")
            if m then
                offset = #(strip(m))
            else
                offset = offset + #(strip(output[i]))
            end
        end
    end

    local function write(text, length)
        if (not text) then return nil end

        if not length then length = #(strip(text)) end
        -- Create room for data by opening parent blocks
        -- Start at the root and go down.
        local i = 1
        while offset + length > width and stack[i] do
            local entry = stack[i]
            if not entry.opened then
                entry.opened = true
                table.insert(output, entry.index + 1, "\n" .. string.rep("  ", i))
                -- Recalculate the offset
                recalcOffset(entry.index)
                -- Bump the index of all deeper entries
                for j = i + 1, #stack do
                    stack[j].index = stack[j].index + 1
                end
            end
            i = i + 1
        end
        output[#output + 1] = text
        offset = offset + length
        if offset > width then
            return dump(stack)
        end
    end

    local function indent()
        stack[#stack + 1] = {
            index = #output,
            opened = false,
        }
    end

    local function unindent()
        stack[#stack] = nil
    end

    local function process_string(localValue)
        if string.match(localValue, "'") and not string.match(localValue, '"') then
            write(dquote .. string.gsub(localValue, '[%c\\\128-\255]', stringEscape) .. dquote2)
        else
            write(quote .. string.gsub(localValue, "[%c\\'\128-\255]", stringEscape) .. quote2)
        end
    end

    local function process_table(localValue)
        write(obrace)
        local i = 1
        -- Count the number of keys so we know when to stop adding commas
        local total = 0
        for _ in pairs(localValue) do total = total + 1 end

        -- keys
        local keys = {}
        for k,v in pairs(localValue) do
            table.insert(keys, k)
        end
        table.sort( keys, function(a, b) return tostring(a) < tostring(b) end)

        local nextIndex = 1
        for i = 1, #keys do
            local k = keys[i]
            local v = localValue[k]

            -- for k, v in pairs(localValue) do

            indent()
            if k == nextIndex then
                -- if the key matches the last numerical index + 1
                -- This is how lists print without keys
                nextIndex = k + 1
                process_value(v)

            else
                if type(k) == "string" and string.find(k, "^[%a_][%a%d_]*$") then
                    write(colorize("property", k) .. equals)
                else
                    write(obracket)
                    process_value(k)
                    write(cbracket .. equals)
                end

                if type(v) == "table" then
                    process_value(v)
                else
                    indent()
                    process_value(v)
                    unindent()
                end
            end

            if i < total then
                write(comma)
            else
                write(" ")
            end
            
            i = i + 1
            unindent()
        end
        write(cbrace)
    end

    function process_value(localValue)
        local typ = type(localValue)
        if typ == 'string' then
            process_string(localValue)

        elseif typ == 'table' and not seen[localValue] then
            if not recurse then seen[localValue] = true end
            process_table(localValue)

        else
            write(colorize(typ, tostring(localValue)))
        end
    end

    process_value(value)
    local s = table.concat(output, "")
    return nocolor and strip(s) or s
end

function prettyPrint(...)
    local n = select('#', ...)
    local arguments = { ...}

    for i = 1, n do
        arguments[i] = dump(arguments[i])
    end


    if (useStream) then
        uv.write(stdout, table.concat(arguments, "\t"))
        uv.write(stdout, "\n")

    else
        print(table.unpack(arguments))
    end
end

function printBuffer(text) 
    local list = {}
    for i = 1,#text do
        local ch = text:byte(i)
        table.insert(list, string.format("%02X ", ch, ch))

        if (i % 8 == 0) then
            table.insert(list, ' ')
        end

        if (i % 24 == 0) then
            table.insert(list, '\r\n')
        end
    end

    print(table.concat(list))
end

function strip(str)
    if (not str) then return nil end
    return str:gsub('\027%[[^m]*m', '')
end

if (useStream) then
    -- Print replacement that goes through libuv.  This is useful on windows
    -- to use libuv's code to translate ansi escape codes to windows API calls.

    function _G.print(...)
        local n = select('#', ...)
        local arguments = { ...}
        for i = 1, n do
            arguments[i] = tostring(arguments[i])
        end

        uv.write(stdout, table.concat(arguments, "\t") .. "\n")
    end

    -- stdin
    if uv.guess_handle(0) == 'tty' then
        stdin = assert(uv.new_tty(0, true))
    else
        stdin = uv.new_pipe(false)
        uv.pipe_open(stdin, 0)
    end

    -- strout
    if uv.guess_handle(1) == 'tty' then
        stdout = assert(uv.new_tty(1, false))
        width = uv.tty_get_winsize(stdout)
        if width == 0 then width = 80 end
        -- auto-detect when 16 color mode should be used
        local term = env.get("TERM")
        if term == 'xterm' or term == 'xterm-256color' then
            defaultTheme = 256
        else
            defaultTheme = 16
        end
    else
        stdout = uv.new_pipe(false)
        uv.pipe_open(stdout, 1)
        width = 80
    end

    -- stderr
    if uv.guess_handle(2) == 'tty' then
        stderr = assert(uv.new_tty(2, false))
    else
        stderr = uv.new_pipe(false)
        uv.pipe_open(stderr, 2)
    end

else 
    width = 80

    local g_print = _G.print
    local g_start = uv.uptime()

    function _G.print(...)
        local n = select('#', ...)
        local arguments = { ...}
        for i = 1, n do
            arguments[i] = tostring(arguments[i])
        end

        local now = math.floor((uv.uptime() - g_start) * 1000) / 1000
        g_print(now, table.unpack(arguments))
    end
    
    local term = env.get("TERM")
    if term == 'xterm' or term == 'xterm-256color' then
        defaultTheme = 256
    else
        --defaultTheme = 16
    end
end

loadColors()

exports.color       = color
exports.colorize    = colorize
exports.dump        = dump
exports.loadColors  = loadColors
exports.pprint      = prettyPrint
exports.prettyPrint = prettyPrint
exports.print       = print
exports.printBuffer = printBuffer
exports.stderr      = stderr
exports.stdin       = stdin
exports.stdout      = stdout
exports.strip       = strip
exports.theme       = theme

return exports

--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

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
local http  = require('http')
local url   = require('url')
local utils = require('utils')
local timer = require('timer')

local querystring   = require('querystring')
local ext           = require('ext/utils')

-- Simplified HTTP client
-- ======
--
-- 一个轻量级的易于使用的 HTTP 请求客户端
-- 

local meta = { }
meta.name        = "request"
meta.version     = "1.0.0"
meta.description = "Simplified HTTP client."
meta.tags        = { "request", "http", "client" }

local exports = { meta = meta }

local formatFloat = ext.formatFloat
local formatBytes = ext.formatBytes
local noop        = ext.noop

-------------------------------------------------------------------------------
-- local functions

local boundaryKey = "vision-34abcd234mlmnz365"

local function getFormData(files)
    local sb = StringBuffer:new()

    for key, file in pairs(files) do
        local filedata = file
        local filename = key
        if (type(file) == 'table') then
            filedata = file.data
            filename = file.name
        end

        sb:append('\r\n--'):append(boundaryKey):append('\r\n')
        sb:append('Content-Disposition: form-data')
        sb:append('; name="'):append(key):append('"')
        sb:append('; filename="'):append(filename):append('"')
        sb:append('\r\n')
        sb:append('Content-Type: application/octet-stream\r\n')
        sb:append('\r\n')
        sb:append(filedata)
    end

    -- end of stream
    sb:append('\r\n--'):append(boundaryKey):append('--')

    return sb:toString()
end


-------------------------------------------------------------------------------
-- exports

function exports.delete(urlString, options, callback)
    -- delete(url, callback)
    if (type(options) == 'function') then 
        callback = options; 
        options = nil; 
    end

    local headers = {}
    local args = { method  = 'DELETE', headers = headers }

    local request = exports.request(urlString, args, callback)
    request:done()
end


-- Download the system update package file
-- callback(err, percent, data)
function exports.download(urlString, options, callback)
    callback = callback or function() end

    --print('url', url)
    local request = http.get(urlString, function(response)
        
        local contentLength = tonumber(response.headers['Content-Length']) or 0
        print('Downloading package (' .. formatBytes(contentLength) .. ')...')

        local percent = 0
        local downloadLength = 0
        local data = {}
        local lastTime = timer.now()

        response:on('data', function(chunk)
            if (not chunk) then
                return
            end

            --pprint("ondata", {chunk=chunk})
            table.insert(data, chunk)
            downloadLength = downloadLength + #chunk

            -- thread.sleep(100)

            if (contentLength > 0) then
                percent = math.floor(downloadLength * 100 / contentLength)

                local now = timer.now()
                if ((now - lastTime) >= 500) or (contentLength == downloadLength) then
                    lastTime = now
                    callback(nil, percent)
                end
            end
        end)

        response:on('end', function()
            if (response.statusCode ~= 200) then
                --console.log(response)
                callback('Download failed: ' .. (response.statusMessage or ''))
                return
            end

            local content = table.concat(data)
            callback(nil, 200, content, response.statusCode)
        end)

        response:on('error', function(err)
            callback('Download failed: ' .. (err or ''))
        end)
    end)

    request:on('error', function(err) 
        callback('Download failed: ' .. (err or ''))
    end)
end

function exports.get(urlString, options, callback)
    -- get(url, callback)
    if (type(options) == 'function') then 
        callback = options; 
        options = nil; 
    end

    local headers = {}
    local args = { method  = 'GET', headers = headers }

    local request = exports.request(urlString, args, callback)
    request:done()
end

function exports.post(urlString, options, callback)
    local postData = nil
    local headers = {}

    if (options.form) then
        postData = querystring.stringify(options.form or {})
        headers['Content-Type'] = 'application/x-www-form-urlencoded'

    elseif (options.formData) then
        postData = options.formData

        local boundary = options.boundaryKey or boundaryKey
        headers['Content-Type'] = 'multipart/form-data; boundary=' .. boundary

    elseif (options.files) then
        postData = getFormData(options.files)

        local boundary = options.boundaryKey or boundaryKey
        headers['Content-Type'] = 'multipart/form-data; boundary=' .. boundary

    elseif (options.data) then
        postData = options.data
        headers['Content-Type'] = options.contentType or 'application/octet-stream'
    end

    local postLength = 0
    if (postData) then
        postLength = #postData
    end

    headers['Content-Length'] = postLength

    local args = { method  = 'POST', headers = headers }
    local request = exports.request(urlString, args, callback)
    
    if (postData) and (postLength > 0) then
        request:write(postData)
    end
    
    request:done()
end

function exports.put(urlString, options, callback)
    local postData = options.data

    local postLength = 0
    if (postData) then
        postLength = #postData
    end

    local headers = {}
    headers['Content-Type']   = 'application/octet-stream'
    headers['Content-Length'] = postLength

    local args = { method  = 'PUT', headers = headers }
    local request = exports.request(urlString, args, callback)
    
    if (postData) and (postLength > 0) then
        request:write(postData)
    end
    
    request:done()
end

--[[
options:
- host
- port
- path
--]]
function exports.request(urlString, options, callback)
    options = options or function() end
    -- url
    local urlObject = url.parse(urlString)
    if (urlObject) then
        options.host    = urlObject.host or '127.0.0.1'
        options.port    = urlObject.port or 80
        options.path    = urlObject.path or '/'
    end
    
    local request = nil

    local timeout = options.timeout or 1000 * 20
    local timeoutTimer = nil

    timeoutTimer = setTimeout(timeout, function()
        if (callback) then
            request:destroy()
            callback('Timeout')
        end
    end)

    -- recv
    local responseBody = {}
    request = http.request(options, function(response)
        response:on('data', function(data)
            responseBody[#responseBody + 1] = data
        end)

        response:on('end', function()
            local content = table.concat(responseBody)
            clearTimeout(timeoutTimer)

            if (callback) then
                callback(nil, response, content)
                request:destroy()
            end
        end)
    end)

    -- error
    request:on('error', function(error, ...)
        --console.log('error', error, ...)
        clearTimeout(timeoutTimer)

        if (callback) then
            callback(error)
        end
    end)

    --console.log('request')

    return request
end

function exports.upload(urlString, options, callback)
    if (type(callback) ~= 'function') then
        callback = function() end
    end

    local filename = options.filename
    local fileData = fs.readFileSync(filename)
    if (not fileData) then
        print('File not found: ' .. tostring(filename))
        callback('File not found: ')
        return
    end

    local files = {file = { name = (alias or name), data = fileData } }
    local args = { files = files }
    exports.post(urlString, args, function(err, response, body)
        if (err) then
            callback(err)
            return

        elseif (response.statusCode ~= 200) then
            callback(response.statusCode .. ': ' .. tostring(response.statusMessage))
            return
        end

        callback(body)
    end)
end

setmetatable( exports, {
    __call = function(self, ...) 
        return self.get(...)
    end
})

return exports

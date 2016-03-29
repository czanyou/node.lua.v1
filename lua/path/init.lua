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

--[[
This module contains utilities for handling and transforming file paths. Almost 
all these methods perform only string transformations. The file system is not 
consulted to check whether paths are valid.
--]]
local meta = { }
meta.name        = "luvit/path"
meta.version     = "1.0.0-3"
meta.license     = "Apache 2"
meta.homepage    = "https://github.com/luvit/luvit/blob/master/deps/path"
meta.description = "A port of node.js's path module for luvit."
meta.tags        = { "luvit", "path" }

local exports = { meta = meta }

local init = require('init')
local path_base = require('path/base')

local function setup_meta(ospath)
    local path = exports
    path._internal = ospath
    setmetatable(path, {
        __index = function(_, key)
            if type(path._internal[key]) == 'function' then
                return function(...)
                    return path._internal[key](path._internal, ...)
                end
            else
                return path._internal:_get(key)
            end
        end
    } )
    return path
end

--[[
Path
    path.basename(p[, ext])
    Return the last portion of a path. Similar to the Unix basename command.

    path.delimiter
    The platform-specific path delimiter, ; or ':'.

    path.dirname(p)
    Return the directory name of a path. Similar to the Unix dirname command.

    path.extname(p)
    Return the extension of the path, from the last '.' to end of string in the 
    last portion of the path. If there is no '.' in the last portion of the path 
    or the first character of it is '.', then it returns an empty string. Examples:

    path.format(pathObject)
    Returns a path string from an object, the opposite of path.parse above.

    path.isAbsolute(path)
    Determines whether path is an absolute path. An absolute path will always 
    resolve to the same location, regardless of the working directory.

    path.join([path1][, path2][, ...])
    Join all arguments together and normalize the resulting path.

    path.normalize(p)
    Normalize a string path, taking care of '..' and '.' parts.

    path.parse(pathString)
    Returns an object from a path string.

    path.relative(from, to)
    Solve the relative path from from to to.

    path.resolve([from ...], to)
    Resolves to to an absolute path.

    path.sep
    The platform-specific file separator. '\\' or '/'.

    path.posix
    Provide access to aforementioned path methods but always interact in a posix 
    compatible way.

    path.win32
    Provide access to aforementioned path methods but always interact in a win32 
    compatible way.
]]

exports.nt    = path_base.nt
exports.posix = path_base.posix

if os.type() == "win32" then
    return setup_meta(path_base.nt)
else
    return setup_meta(path_base.posix)
end

return exports;

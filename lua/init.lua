local uv = require('uv')

if (not _G.run_loop) then
    _G.run_loop = function() 
        uv.run()
        uv.loop_close()
    end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local miniz = require('miniz')

local function bundle_reader(filename)
    if (type(miniz.preload) ~= 'table') then
        miniz.preload = {}
    end

    local reader = miniz.preload[filename]
    if (reader) then
        return reader
    end

    reader = miniz.new_reader(filename)
    if (reader == nil) then
        return
    end

    miniz.preload[filename] = reader
    return reader
end

local function bundle_loader_load_module(filename, name)
    if (type(name) ~= 'string') then
        return

    elseif (type(filename) ~= 'string') then
        return
    end

    local reader = bundle_reader(filename)
    if (reader == nil) then
        return
    end

    local path =  'lib/' .. name .. '.lua'
    local index, err = reader:locate_file(path)
    if (not index) then
        path = 'lib/' .. name .. '/init.lua'
        index, err = reader:locate_file(path)
        if (not index) then
            return
        end
    end

    if (reader:is_directory(index)) then
        return
    end

    local data = reader:extract(index)
    if (not data) then
        return
    end

    return load(data)
end

local function bundle_loader_load(framework, module)
    local filename = package.searchpath(framework, package.cpath)
    if (not filename) then
        return nil
    end

    return bundle_loader_load_module(filename, module)
end

local function bundle_loader(name)
    if (type(name) ~= 'string') then
        return nil
    end

    local ret = bundle_loader_load('lnode', name)
    if (ret) then
        return ret
    end

    ret = bundle_loader_load('lnode_base', name)
    if (ret) then
        return ret
    end

    local index = name:find('/')
    if (index) then
        local framework = name:sub(1, index - 1)
        local module = name:sub(index + 1)
        return bundle_loader_load(framework, module)     
    end

    return nil
end

package.searchers[5] = bundle_loader

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- process

if (not _G.process) then
    _G.process = require("process");
end


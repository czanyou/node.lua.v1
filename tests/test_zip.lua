local init  = require('init')
local utils = require('utils')
local miniz = require('miniz')
local path  = require('path')
local uv    = require('uv')
local core  = require('core')

local bundle  = require('zlib')

--console.log(miniz)

function lua_zip_loader(filename, name)
    local reader = miniz.new_reader(filename)
    if (reader == nil) then
        return
    end

    local path = name .. ".lua"
    local index, err = reader:locate_file(path)
    if (not index) then

        path = name .. "/init.lua"
        local index, err = reader:locate_file(path)
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

function test_zip1()
	local pwd = process.cwd()
	--console.log(process)
	console.log('console.log(pwd)', pwd)

	local filename = path.join(pwd, "/tmp/tests.zip")
	console.log('filename', filename)

	local reader = miniz.new_reader(filename)
    if (not reader) then
        return
    end

	console.log('reader', reader)

	local binSize = reader:get_offset()
	console.log('binSize', binSize)

	local file_count = reader:get_num_files()
	console.log('file_count', file_count)

	local files = { }
	for i = 1, file_count do
	    local filename = reader:get_filename(i)
	    console.log('filename', filename)
	end

	local path = 'tmp/live/test.lua'
	local index, err = reader:locate_file(path)
	console.log('index', index, err)

	local data = reader:extract(index)
	console.log('data', #data)
	--console.log('data', data)

	local raw = reader:stat(index)
	console.log('raw', raw)

	local is_directory = reader:is_directory(index)
	console.log('is_directory', is_directory)
end

function test_zip2()
	local pwd = process.cwd()
	--console.log(process)
	console.log('console.log(pwd)', pwd)

	local filename = path.join(pwd, "/tmp/ch.bin")
	console.log('filename', filename)

	local reader = miniz.new_reader(filename)
    if (not reader) then
        return
    end
	console.log('reader', reader)

	local binSize = reader:get_offset()
	console.log('get_offset', binSize)

	local file_count = reader:get_num_files()
	console.log('file_count', file_count)

	local files = { }
	for i = 1, file_count do
	    local filename = reader:get_filename(i)
	    console.log('filename', filename)
	end

	local path = 'system/init/ipcam.sh'
	local index, err = reader:locate_file(path)
	console.log('index', index, err)
	if (index) then
		local data = reader:extract(index)
	end
	--console.log('data', data)
end

function test_zip_writer()
	print('TEST: test_zip_writer')
	local pwd = process.cwd()
	--console.log(process)
	--console.log('pwd', pwd)

    local basePath = path.join(pwd, "../../node.lua/node")
    console.log('basePath', basePath)

	local filename = path.join(pwd, "/tmp/node.zip")
	console.log('filename', filename)

    local builder = bundle.BundleBuilder:new(basePath, filename)
    --builder.libOnly = false
	builder:build()

	
end

test_zip1()
test_zip2()
test_zip_writer()



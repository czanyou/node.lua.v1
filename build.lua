#!/usr/bin/env lnode

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --  
-- 添加当前目录到运行环境

function use_current_path()
    local uv  = require('uv')
    local cwd = uv.cwd()
    
    local lib = ';'..cwd..'/lua/?.lua;'..cwd..'/lua/?/init.lua'
    package.path = package.path .. lib
    --print(package.path)

end

use_current_path()

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --  

local init   = require('init')
local utils  = require('utils')
local path   = require('path')
local bundle = require('ext/bundle')

local pprint = utils.pprint

-- 打包 node.lua 核心库
function build()
	local cwd = process.cwd()

    local buildPath = cwd
    print('build path: ' .. utils.colorize("quotes", buildPath))

	local filename = path.join(cwd, "bin/lnode.zip")
    local builder = bundle.BundleBuilder:new(buildPath, filename)
    builder:addLua("lua")
    builder:addBin("bin/lpm")
    builder:addBin("bin/main")
    builder:addFile("package.json")
    builder:addFile("README.md")
	builder:build()

	print('output: ' .. utils.colorize("quotes", filename))
end

build()
run_loop()

return true

#!/usr/bin/env lnode

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --  
-- 将 lua 目录下的所有 lua 等文件打包成 lnode.zip 的单一压缩包, 并包含 
-- package.json 等信息

local init   = require('init')
local utils  = require('utils')
local path   = require('path')
local bundle = require('ext/bundle')

local pprint = utils.pprint

-- 打包 node.lua 核心库
function buildPackage()
	local cwd = process.cwd()

    local buildPath = cwd
    print('Build path: ' .. utils.colorize("quotes", buildPath))

	local filename = path.join(cwd, "bin/lnode.zip")
    local builder = bundle.BundleBuilder:new(buildPath, filename)
    builder:addLua("lua")
    builder:addBin("bin/lpm")
    builder:addBin("bin/main")
    builder:addFile("package.json")
	builder:build()

	print('Output: ' .. utils.colorize("quotes", filename))
end

buildPackage()
run_loop()

return true

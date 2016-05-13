#!/usr/bin/env lnode

-- 
-- 安装 node.lua 运运环境，包括安装可执行文件到执行目录以及关联相关的 lua 模块目录

local uv     = require('uv')
local debug  = require('debug')
local lutils = require('lutils')

local cwd = uv.cwd()
print('------ Install Node.lua developer tools -------');
print('Current OS:        [' .. lutils.os_platform() .. ']')
print('Current Arch:      [' .. lutils.os_arch() .. ']')
print('Current Work Path: [' .. cwd .. ']')
print("Current Lua Path:  [" .. package.path .. "]")

local os_type = lutils.os_platform()

-- set env 
if (os_type == 'Windows') then
	-- 关联 lua core 环境
	local LUA_PATH = cwd .. '/lua/?.lua;' .. cwd .. '/lua/?/init.lua'
	package.path = LUA_PATH .. ';./?.lua;./?/init.lua';

	local init = require('init')
	local path = require('path')

	print("Current Lua Path: " .. package.path)

	-- Windows 下直接把当前开发目录添加到环境变量
	local root = path.dirname(cwd)
	local vision = path.join(root, '/vision.lua')
	LUA_PATH = LUA_PATH .. ';' .. vision .. '/lua/?.lua;' .. vision .. '/lua/?/init.lua'
	LUA_PATH = LUA_PATH .. ';./?.lua;./?/init.lua';
	LUA_PATH = LUA_PATH:gsub('/', '\\')
	print('')
	print('设置环境变量:')
	print('SET LUA_PATH=' .. LUA_PATH)

	local child = require('child_process')
	child.spawn('SETX', { 'LUA_PATH', '' .. LUA_PATH .. '' }, {})

elseif (os_type == 'Linux') then
	local init  = require('init')
	local path  = require('path')
	local child = require('child_process')
end

print('~~~~~~ Complete ~~~~~~');

run_loop()

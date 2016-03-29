local fs 	= require('fs')
local path 	= require('path')
local utils = require('utils')
local lnode = require('lnode')

local cwd = process.cwd()
local cwd = path.join(cwd, 'misc')
print(cwd)

-- bundle output
local basePath = path.join(cwd, 'tmp')
fs.unlinkSync(path.join(basePath, 'install'))
fs.unlinkSync(path.join(basePath, 'test.zip'))
fs.unlinkSync(path.join(basePath, 'test-pipe'))
fs.unlinkSync(basePath)

-- 
local basePath = path.join(cwd, 'bundle')
fs.unlinkSync(path.join(basePath, 'test1.lua'))
fs.unlinkSync(path.join(basePath, 'test2.lua'))
fs.unlinkSync(basePath)


utils.pprint(lnode)
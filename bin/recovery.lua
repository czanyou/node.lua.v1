local core   	= require('core')
local fs     	= require('fs')
local json   	= require('json')
local path   	= require('path')
local utils  	= require('utils')
local conf    	= require('ext/conf')
local app 		= require('app')
local upgrade 	= require('ext/upgrade')

local filename = '/usr/local/lnode/update/update.zip'
upgrade.install(filename, '/usr/local/lnode')


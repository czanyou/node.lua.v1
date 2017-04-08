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

local core      = require('core')
local fs        = require('fs')
local http      = require('http')
local json      = require('json')
local miniz     = require('miniz')
local path      = require('path')
local thread    = require('thread')
local timer     = require('timer')
local url       = require('url')
local utils     = require('utils')

local request  	= require('http/request')
local conf   	= require('ext/conf')
local ext   	= require('ext/utils')


--[[
Node.lua 系统更新程序
======

这个脚本用于自动在线更新 Node.lua SDK, 包含可执行主程序, 核心库, 以及核心应用等等

--]]

local exports = {}

local formatFloat 		= ext.formatFloat
local formatBytes 		= ext.formatBytes
local noop 		  		= ext.noop
local getSystemTarget 	= ext.getSystemTarget

function getRootPath()
	return conf.rootPath
end

function getRootURL()
	return require('app').rootURL
end

local function getCurrentAppInfo()
	local cwd = process.cwd()
	local filename = path.join(cwd, 'package.json')
	local filedata = fs.readFileSync(filename)
	return json.parse(filedata)
end

local function checkNotDevelopmentPath(rootPath)
	local filename1 = path.join(rootPath, 'lua/lnode')
	local filename2 = path.join(rootPath, 'app/build')
	local filename3 = path.join(rootPath, 'src')
	if (fs.existsSync(filename1) or fs.existsSync(filename2) or fs.existsSync(filename3)) then
		print('The "' .. rootPath .. '" is a development path.')
		print('You can not update the system in development mode.\n')
		return false
	end

	return true
end

-- Download the system update package file
-- callback(err, percent, data)
local function downloadFile(url, callback)
	request.download(url, {}, callback)
end

-- 检查是否有另一个进程正在更新系统
local function upgradeLock()
	local tmpdir = os.tmpdir or '/tmp'

	print("Try to lock upgrade...")

	local lockname = path.join(tmpdir, '/update.lock')
	local lockfd = fs.openSync(lockname, 'w+')
	local ret = fs.fileLock(lockfd, 'w')
	if (ret == -1) then
		print('The system update is already locked!')
		return nil
	end

	return lockfd
end

local function upgradeUnlock(lockfd)
	fs.fileLock(lockfd, 'u')
end

-------------------------------------------------------------------------------
-- BundleReader

local BundleReader = core.Emitter:extend()
exports.BundleReader = BundleReader

function BundleReader:initialize(basePath, files)
	self.basePath = basePath
	self.files    = files or {}
end


function BundleReader:locate_file(filename)
	for i = 1, #self.files do
		if (filename == self.files[i]) then
			return i
		end
	end
end

function BundleReader:extract(index)
	if (not self.files[index]) then
		return
	end

	local filename = path.join(self.basePath, self.files[index])

	--console.log(filename)
	return fs.readFileSync(filename)
end

function BundleReader:get_num_files()
	return #self.files
end

function BundleReader:get_filename(index)
	return self.files[index]
end

function BundleReader:stat(index)
	if (not self.files[index]) then
		return
	end

	local filename = path.join(self.basePath, self.files[index])
	local statInfo = fs.statSync(filename)
	statInfo.uncomp_size = statInfo.size
	return statInfo
end

function BundleReader:is_directory(index)
	local filename = self.files[index]
	if (not filename) then
		return
	end

	return filename:endsWith('/')
end

local function createBundleReader(filename)

	local listFiles 

	listFiles = function(list, basePath, filename)
		--print(filename)

		local info = fs.statSync(path.join(basePath, filename))
		if (info.type == 'directory') then
			list[#list + 1] = filename .. "/"

			local files = fs.readdirSync(path.join(basePath, filename))
			if (not files) then
				return
			end

			for _, file in ipairs(files) do
				listFiles(list, basePath, path.join(filename, file))
			end

		else

			list[#list + 1] = filename
		end
	end


	local info = fs.statSync(filename)
	if (not info) then
		return
	end

	if (info.type == 'directory') then
		local filedata = fs.readFileSync(path.join(filename, "package.json"))
		local packageInfo = json.parse(filedata)
		if (not packageInfo) then
			return
		end

		local files = fs.readdirSync(filename)
		if (not files) then
			return
		end

		local list = {}

		for _, file in ipairs(files) do
			listFiles(list, filename, file)
		end

		--console.log(list)
		return BundleReader:new(filename, list)

	else
		return miniz.new_reader(filename)
	end
end

-------------------------------------------------------------------------------
-- BundleUpdater

local BundleUpdater = core.Emitter:extend()
exports.BundleUpdater = BundleUpdater

function BundleUpdater:initialize(options)
	self.filename = options.filename
	self.rootPath = options.rootPath

end

-- Check whether the specified file need to updated
-- @param checkInfo 需要的信息如下:
--  - rootPath 目标路径
--  - reader 
--  - index 源文件索引
-- @return 0: not need update; other: need updated
-- 
function BundleUpdater:checkFile(index)
	local join   	= path.join
	local rootPath  = self.rootPath
	local reader   	= self.reader
	local filename  = reader:get_filename(index)
	if (filename == 'install.sh') then
		return 0 -- ignore `install.sh
	end

	local destname 	= join(rootPath, filename)
	local srcInfo   = reader:stat(index)

	if (reader:is_directory(index)) then
		fs.mkdirpSync(destname)
		return 0
	end
	--console.log(srcInfo)

	self.totalBytes = (self.totalBytes or 0) + srcInfo.uncomp_size
	self.total      = (self.total or 0) + 1

	-- check file size
	local destInfo 	= fs.statSync(destname)
	if (destInfo == nil) then
		return 1

	elseif (srcInfo.uncomp_size ~= destInfo.size) then 
		return 2
	end

	-- check file hash
	local srcData  = reader:extract(index)
	local destData = fs.readFileSync(destname)
	--local destHash = utils.md5(destData)
	--local srcHash  = utils.md5(srcData)
	--if (srcHash ~= destHash) then
	if (srcData ~= destData) then
		return 3
	end

	--console.log(filename, destname, srcInfo.uncomp_size, destInfo.size)

	return 0

end

-- Check for files that need to be updated
-- @param checkInfo
--  - reader 
--  - rootPath 目标路径
-- @return 
-- checkInfo 会被更新的值:
--  - list 需要更新的文件列表
--  - updated 需要更新的文件数
--  - total 总共检查的文件数
--  - totalBytes 总共占用的空间大小
function BundleUpdater:checkSystemFiles()
	local join    = path.join
	local reader  = self.reader

	local count = reader:get_num_files()
	for index = 1, count do
		self.index = index

		local ret = self:checkFile(index)
		--print('file', filename, ret)

		if (ret > 0) then
			self.updated = (self.updated or 0) + 1
			table.insert(self.list, index)
		end
	end
end

-- 检查系统存储空间
-- 主要是为了检查是否有足够的剩余空间用来更新固件
function BundleUpdater:checkStorage()
	-- check storage size
	local lutils = require('lutils')
	local statInfo = lutils.os_statfs(self.rootPath)
	if (not statInfo) then
		return
	end

	local totalSize = statInfo.blocks * statInfo.bsize
	local freeSize  = statInfo.bfree  * statInfo.bsize
	if (totalSize > 0) then
		local percent = math.floor(freeSize * 100 / totalSize)
		print(string.format('storage: %s/%s percent: %d%%', 
			formatBytes(freeSize), 
			formatBytes(totalSize), percent))
	end
end

-- Update the specified file
-- @param rootPath 目标目录
-- @param reader 文件源
-- @param index 文件索引
-- 
function BundleUpdater:updateFile(rootPath, reader, index)
	local join 	 	= path.join

	if (not rootPath) or (not rootPath) then
		return -6, 'invalid parameters' 
	end

	local filename = reader:get_filename(index)
	if (not filename) then
		return -5, 'invalid source file name: ' .. index 
	end	

	-- read source file data
	local fileData 	= reader:extract(index)
	if (not fileData) then
		return -3, 'invalid source file data: ' .. filename 
	end

	-- write to a temporary file and check it
	local tempname = join(rootPath, filename .. ".tmp")
	local dirname = path.dirname(tempname)
	fs.mkdirpSync(dirname)

	local ret, err = fs.writeFileSync(tempname, fileData)
	if (not ret) then
		return -4, err
	end

	local destInfo = fs.statSync(tempname)
	if (destInfo == nil) then
		return -1, 'not found: ' .. filename 

	elseif (destInfo.size ~= #fileData) then
		return -2, 'invalid file size: ' .. filename 
	end

	-- rename to dest file
	local destname = join(rootPath, filename)
	os.remove(destname)
	local destInfo = fs.statSync(destname)
	if (destInfo ~= nil) then
		return -1, 'failed to remove old file: ' .. filename 
	end

	os.rename(tempname, destname)

	print('Update file: ', filename)
	return 0
end

-- Update all Node.lua system files
-- 安装系统更新包
-- @param checkInfo 更新包
--  - reader 
--  - rootPath
-- @param files 要更新的文件列表, 保存的是文件在 reader 中的索引.
-- @param callback 更新完成后调用这个方法
-- @return 
-- checkInfo 会更新的属性:
--  - faileds 更新失败的文件数
function BundleUpdater:updateSystemFiles(files, callback)
	callback = callback or noop

	local rootPath = self.rootPath

	files = files or self.files or {}
	print('Upgrading system "' .. rootPath .. '" (total ' 
		.. #files .. ' files need to update).')

	--console.log(self)

	for _, index in ipairs(files) do
		local ret, err = self:updateFile(rootPath, self.reader, index)
		if (ret ~= 0) then
			print('ERROR.' .. index, err)
            self.faileds = (self.faileds or 0) + 1
		end
	end

	os.execute("chmod 777 " .. rootPath .. "/bin/*")

	callback(nil, self)
end

-- 安装系统更新包
-- @param checkInfo 更新包
--  - filename 
--  - rootPath
-- @param callback 更新完成后调用这个方法
-- @return
-- checkInfo 会更新的属性:
--  - list
--  - total
--  - updated
--  - totalBytes
--  - faileds
-- 
function BundleUpdater:upgradeSystemPackage(callback)
	callback = callback or noop

	local filename 	= self.filename
	if (not filename) or (filename == '') then
		callback("Upgrade error: invalid filename")
		return
	end
	--print('update file: ' .. tostring(filename))
	print('\nInstalling package (' .. filename .. ')')

	local reader = createBundleReader(filename)
	if (reader == nil) then
		callback("Upgrade error: bad package bundle file", filename)
		return
	end

    local filename = path.join('package.json')
	local index, err = reader:locate_file(filename)
    if (not index) then
		callback('Upgrade error: `package.json` not found!', filename)
        return
    end

    local filedata = reader:extract(index)
    if (not filedata) then
    	callback('Upgrade error: `package.json` not found!', filename)
    	return
    end

    local packageInfo = json.parse(filedata)
    if (not packageInfo) then
    	callback('Upgrade error: `package.json` is invalid JSON format', filedata)
    	return
    end

    -- 验证安装目标平台是否一致
    if (packageInfo.target) then
		local target = getSystemTarget()
		if (target ~= packageInfo.target) then
			callback('Upgrade error: Mismatched target: local is `' .. target .. 
				'`, but the update file is `' .. tostring(packageInfo.target) .. '`')
	    	return
		end

	elseif (packageInfo.name) then
		self.name     = packageInfo.name
		self.rootPath = path.join(self.rootPath, 'app', self.name)

	else
		callback("Upgrade error: bad package information file", filename)
		return
	end

	self.list 		= {}
	self.total 	 	= 0
    self.updated 	= 0
	self.totalBytes = 0
    self.faileds 	= 0
    self.version    = packageInfo.version
    self.target     = packageInfo.target
	self.reader	 	= reader

	self:checkSystemFiles(self)
	self:updateSystemFiles(self.list, callback)
end

function BundleUpdater:showUpgradeResult()
	if (self.faileds and self.faileds > 0) then
		print(string.format('Total (%d) error has occurred!', self.faileds))
	else
		print('\nFinished\n')
	end
end

-------------------------------------------------------------------------------
-- download

local function downloadSystemPackage(checkInfo, callback)
	callback = callback or noop

	local rootPath  = getRootPath()
	local basePath  = path.join(rootPath, 'update')
	fs.mkdirpSync(basePath)

	local filename = path.join(basePath, '/update.zip')

	-- 检查 SDK 更新包是否已下载
	local packageInfo = checkInfo.packageInfo
	--print(packageInfo.size, packageInfo.md5sum)
	if (packageInfo and packageInfo.size) then
		local filedata = fs.readFileSync(filename)
		if (filedata and #filedata == packageInfo.size) then
			local md5sum = utils.bin2hex(utils.md5(filedata))
			--print('md5sum', md5sum)

			if (md5sum == packageInfo.md5sum) then
				print("The update file is up-to-date!", filename)
				callback(nil, filename)
				return
			end
		end
	end

	-- 下载最新的 SDK 更新包
	downloadFile(checkInfo.url, function(err, percent, data, statusCode)
		if (err) then 
			print(err)
			callback(err)
			return 
		end

		if (percent <= 100) then
			print('Downloading package (' .. percent .. '%).')
		end

		if (percent ~= 200) then
			return
		end

		-- write to a temp file
		print('Done!')

		os.remove(filename)
		fs.writeFile(filename, data, function()
			callback(nil, filename)
		end)
	end)
end

local function downloadSystemInfo(callback, printInfo)
	if (not printInfo) then
		printInfo = function() end
	end

	-- URL
	local target 	= getSystemTarget()
	local rootURL 	= getRootURL()
	local baseURL 	= rootURL .. '/download/dist/' .. target
	local url 		= baseURL .. '/nodelua-' .. target .. '-sdk.json'

	printInfo("System type: " .. target)
	printInfo("Upgrade Server: " .. rootURL)	
	printInfo('URL: ' .. url)

	downloadFile(url, function(err, percent, data)
		if (err) then
			callback(err)
			return

		elseif (percent ~= 200) then
			return
		end

		local packageInfo = json.parse(data)
		if (not packageInfo) or (not packageInfo.version) then
			callback("Invalid package information")
			return
		end

		--console.log('latest version: ' .. tostring(packageInfo.version))
		local rootPath  = getRootPath()
		local basePath  = path.join(rootPath, 'update')
		fs.mkdirpSync(basePath)

		local filename 	= path.join(basePath, 'latest-sdk.json')
		local filedata  = fs.readFileSync(filename)
		if (filedata == data) then
			print("System information is up-to-date!")
			callback(nil, packageInfo)
			return
		end

		fs.writeFile(filename, data, function()
			print("System information saved to: " ..  filename)
			callback(nil, packageInfo)
		end)
	end)
end

-- download system update info and package files
local function downloadUpdateFiles(callback)
	printInfo = printInfo or function(...) print(...) end

	downloadSystemInfo(function(err, packageInfo)
		if (err) then 
			callback(err)
			return
		end

		-- System update filename
		if (not packageInfo) or (not packageInfo.filename) then
			callback("Bad package information format!")
			return
		end

		printInfo("Done.")

		-- System update URL
		local target 	= getSystemTarget()
		local rootURL 	= getRootURL()
		local baseURL 	= rootURL .. '/download/dist/' .. target
		local url 		= baseURL .. '/' .. packageInfo.filename
		printInfo('Package url: ' .. url)

		-- downloading
		local options = {}
		options.url 		= url
		options.packageInfo = packageInfo
		downloadSystemPackage(options, function(err, filename)
			printInfo("Done.")
			callback(err, filename, packageInfo)
		end)

	end, printInfo)
end

-------------------------------------------------------------------------------
-- exports

function exports.check()
	local target = getSystemTarget()
	print("System type:  " .. target)

	downloadSystemInfo(function(err, packageInfo)
		if (err) then 
			print(err)
			return
		end

		if (not packageInfo) or (not packageInfo.filename) then
			print("Bad package information format!")
			return
		end

		print('upgrade server:  ' .. tostring(getRootURL()))
		print('target:          ' .. tostring(packageInfo.target))
		print('description:     ' .. tostring(packageInfo.description))
		print('version:         ' .. tostring(packageInfo.version))
		print('mtime:           ' .. tostring(packageInfo.mtime))
		print('size:            ' .. tostring(packageInfo.size))
		print('md5sum:          ' .. tostring(packageInfo.md5sum))
		print('applications:    ' .. json.stringify(packageInfo.applications))
		print('Update file:     ' .. packageInfo.filename)

		print("Done.")
	end)
end

function exports.connect(hostname, password)
	-- TODO: connect
	if (not hostname) or (not password) then
		print('\nUsage: lpm connect <hostname> <password>')
		print('   or: lpm connect localhost\n')

	end

	local deploy = conf('deploy')
	if (deploy) then

		if (hostname) then
			deploy:set('hostname', hostname)
		end

		if (password) then
			deploy:set('password', password)
		end

		deploy:commit()

		print('Current settings:')
		print('')
		print('- hostname: ' .. (deploy:get('hostname') or '-'))
		print('- password: ' .. (deploy:get('password') or '-'))
		print('')
	end
end

function exports.deploy(hostname, password)
	print("\nUsage: lpm deploy <hostname> <password>\n")

	if (not hostname) then
		local deploy = conf('deploy')
		hostname = deploy:get('hostname')
		password = password or deploy:get('password')

		if (not hostname) then
			print("Need hostname!")
			return
		end
	end

	local request = require('http/request')

	print('Deploy device:  ' .. hostname)

	local url = 'http://' .. hostname .. ':9100/device'
	request(url, function(err, response, body)
		if (err) then print('Connect to server failed: ', err) return end

		local systemInfo = json.parse(body)
		if (not systemInfo) then
			print('invalid device info')
			return
		end

		--console.log(systemInfo)

		local device = systemInfo.device
		if (not systemInfo) then
			print('invalid device info')
			return
		end

		local target = device.target
		local version = device.version or ''
		if (not target) then
			print('invalid device target type')
			return
		end

		print('Deploy target:  ' .. target .. '@' .. version)

		local filename = path.join(process.cwd(), 'build', 'nodelua-' .. target .. '-sdk.zip');
		print('Deploy file:    ' .. filename)

		if (not fs.existsSync(filename)) then
			print('Deploy failed:  Update file not found, please build it firist!')
			return
		end

		local filedata = fs.readFileSync(filename)
		if (not filedata) then
			print('Deploy failed:  Invalid update file!')
			return
		end

		local options = {}
		options.data = filedata

		local url = 'http://' .. hostname .. ':9100/upgrade'
		print('Deploy url:     ' .. url)
		request.post(url, options, function(err, response, body)
			if (err) then print(err) return end

			local result = json.parse(body) or {}
			if (result.ret == 0) then
				print('Deploy finish!')
			else
				print('Deploy error: ' .. tostring(result.error))
			end
		end)
	end)
end

function exports.disconnect()
	local deploy = conf('deploy')
	if (deploy) then
		deploy:set('hostname', nil)
		deploy:set('password', nil)
		deploy:commit()

		print("Disconnected!")
	end
end

function exports.help()
	print(console.colorful[[

${braces}Node.lua packages upgrade tools${normal}

Usage:
  lpm connect [hostname] [password] ${braces}Connect a device with password${normal}
  lpm deploy [hostname] [password]  ${braces}Update all packages on the device${normal}
  lpm disconnect                    ${braces}Disconnect the current device${normal}
  lpm install [name]                ${braces}Install a application to the device${normal}
  lpm remove [name]                 ${braces}Remove a application on the device${normal}
  lpm scan [timeout]                ${braces}Scan devices${normal}
  lpm upgrade [name] [rootPath]     ${braces}Update all packages${normal}

upgrade: 
  ${braces}This command will update all the packages listed to the latest version
  If the package <name> is "all", all packages in the specified location
  (global or local) will be updated.${normal}

deploy:
  ${braces}Update all packages on the device to the latest version.${normal}

]])

end

function exports.remove(name)
	if (not name) or (name == '') then
		print([[
Usage: lpm remove [options] <name>

options:
  -g remove from global path
]])		
		return
	end

	local appPath = path.join(path.dirname(os.tmpname()), 'app')
	local filename = path.join(appPath, name) or ''
	if (fs.existsSync(filename)) then
		os.execute("rm -rf " .. filename)
		print("removed: '" .. filename  .. "'")
	else
		print("not exists: '" .. filename  .. "'")
	end

end

function exports.installApplication(name)
	local dest = nil
	if (name == '-g') then
		dest = 'global'
		name = nil
	end

	if (not name) then
		print([[
Usage: lpm install [options] <name>

options:
  -g install to global
]])
	end

	-- application name
	local package = require('ext/package')

	if (name) then
		package.pack(name)

	else
		local info  = getCurrentAppInfo()
		if (info) then
			name = info.name
			package.pack()
		end

		if (not name) or (name == '') then
			local filename = path.join(process.cwd(), 'packages.json') or ''
			print("Install: no such file, open '" .. filename .. "'")
			return
		end
	end

	-- update file
	local tmpdir = path.dirname(os.tmpname())
	local buildPath = path.join(tmpdir, 'packages')
	local filename = path.join(buildPath, "" .. name .. ".zip")
	print("Install: open '" .. filename .. "'")

	if (not fs.existsSync(filename)) then
		print('Install: no such application update file, please build it first!')
		return
	end

	-- hostname
	local deploy = conf('deploy')
	local hostname = deploy:get('hostname')
	password = password or deploy:get('password')

	-- install to localhost
	if (not hostname) or (hostname == '') or (hostname == 'localhost') then
		print('Install [' .. name .. '] to [localhost]')

		local tmpdir = path.dirname(os.tmpname())
		exports.installFile(filename, tmpdir)
		return
	end

	-- update file content
	local filedata = fs.readFileSync(filename)
	if (not filedata) then
		print('Install failed:  Invalid update file content!')
		return
	end

	-- post file
	print('Install [' .. name .. '] to [' .. hostname .. ']')

	local options = {data = filedata}

	local url = 'http://' .. hostname .. ':9100/install'
	if (dest) then
		url = url .. "?dest=" .. dest
	end

	print('Install url:    ' .. url)
	local request = require('http/request')
	request.post(url, options, function(err, response, body)
		if (err) then print(err) return end

		local result = json.parse(body) or {}
		if (result.ret == 0) then
			console.log(result.data)
			print('Install finish!')
		else
			print('Install error: ' .. tostring(result.error))
		end
	end)
end

function exports.install(filename, rootPath)
	return exports.upgradeFile(filename, rootPath, callback)
end

local function updateUpdateFile(filename)
	local rootPath  = getRootPath()
	local basePath  = path.join(rootPath, 'update')
	local destFile  = path.join(basePath, 'update.zip')

	if (filename == destFile) then
		return filename
	end

	local statInfo1  = fs.statSync(filename) or {}
	if (statInfo1.type == 'directory') then
		return filename
	end
	local sourceSize = statInfo1.size or 0

	local statInfo2  = fs.statSync(destFile) or {}
	local destSize   = statInfo2.size or 0

	if (sourceSize == destSize) then
		print("The update file is up-to-date!")
		return destFile
	end

	fs.mkdirpSync(basePath)

	local fileData = fs.readFileSync(filename)
	if (fileData) then
		fs.writeFileSync(destFile, fileData)
		print("Copy update.zip to " .. destFile)
		return destFile
	end

	return filename
end

-- 安装 SDK 更新包
-- @param filename 要安装的文件
-- @param rootPath 要安装的路径
function exports.upgradeFile(filename, rootPath, callback)
	filename = filename or '/tmp/update.zip'
	rootPath = rootPath or getRootPath()
	if (not checkNotDevelopmentPath(rootPath)) then
		if (callback) then callback('is development path') end
		return
	end

	local lockfd = upgradeLock()
	if (not lockfd) then
		if (callback) then callback('lock failed') end
		return
	end

	local destFile = updateUpdateFile(filename)

	local options = {}
	options.filename = destFile
	options.rootPath = rootPath

	local updater = BundleUpdater:new(options)
	updater:upgradeSystemPackage(function(err)
		upgradeUnlock(lockfd)

		if (callback) then
			callback(err)
			return
		end

		if (err) then print(err) end
		updater:showUpgradeResult()
	end)
end

-- 安装应用安装包
-- @param filename 要安装的文件
-- @param rootPath 要安装的路径
function exports.installFile(filename, rootPath, callback)
	callback = callback or function() end

	local options = {}
	options.filename   = filename or '/tmp/install.zip'
	options.rootPath   = rootPath or getRootPath()

	local updater = BundleUpdater:new(options)
	updater:upgradeSystemPackage(callback)
end

function exports.update(callback)
	local printInfo = function() end

	if (type(callback) ~= 'function') then
		callback = function(err, filename, packageInfo)
			packageInfo = packageInfo or {}

			--console.log(err, filename, packageInfo)
			if (err) then
				print('err: ', err)

			else
				print('latest version: ' .. tostring(packageInfo.version))
			end
		end
		printInfo = function(...) print("update", ...) end
	end

	downloadUpdateFiles(callback)
end

--[[
更新系统

--]]
function exports.upgrade(source, rootPath)
	rootPath = rootPath or getRootPath()
	if (not checkNotDevelopmentPath(rootPath)) then
		return
	end

	--console.log(source, rootPath)

	local lockfd = upgradeLock()
	if (not lockfd) then
		return
	end

	local onUpgrade = function(err, filename)
		if (err) then
			upgradeUnlock(lockfd)
			return
		end

		local options = {}
		options.filename 	= filename
		options.rootPath 	= rootPath

		local updater = BundleUpdater:new(options)
		updater:upgradeSystemPackage(function(err)
			if (err) then print(err) end

			upgradeUnlock(lockfd)
			updater:showUpgradeResult()
		end)
	end

	print("Upgrade path: " .. rootPath)

	if source and (source:startsWith("/")) then
		-- 从本地文件升级
		-- function(filename, rootPath)

		local destFile = updateUpdateFile(source)
		onUpgrade(nil, destFile)

	elseif (source == "system") then
		-- Upgrade form network
		downloadUpdateFiles(function(err, filename)
			onUpgrade(err, filename)
		end)

	else
		upgradeUnlock(lockfd)
		print("Unknow upgrade target: " .. (source or 'nil'))
	end
end

return exports
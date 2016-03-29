local core   = require('core')
local fs     = require('fs')
local http   = require('http')
local init   = require('init')
local json   = require('json')
local miniz  = require('miniz')
local path   = require('path')
local thread = require('thread')
local timer  = require('timer')
local url    = require('url')
local utils  = require('utils')
local uv     = require('uv')
local lutils = require('lutils')

local bundle = require('ext/bundle')
local conf   = require('ext/conf')

local pprint = utils.pprint

local function getPackageExtName()
	local type = os.type()

	if (type == 'win32') then
		return ".dll"
	else 
		return ".so"
	end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local exports = {}

local options = {}
options.BOARD 			= "ipc8266"
options.CACHE_PATH 		= "/tmp/cache"
options.EXT_NAME 		= getPackageExtName()
options.PACKAGE_JSON 	= "package.json"
options.PACKAGES_JSON 	= "packages.json"
options.ROOT_PATH 		= "/system/lib/lua/5.3/"
options.SOURCE_URL		= "http://127.0.0.1:8080/download/packages.json"
exports.options 		= options

--pprint(options.EXT_NAME)

function lpm_load_settings()
	local profile, err = conf.load("lpm.conf")
	if type(profile) ~= 'table' then
		return
	end

	options.conffile 	= profile.filename
	options.BOARD 		= profile:get("lpm.board")  or options.BOARD
	options.SOURCE_URL 	= profile:get("lpm.source") or options.SOURCE_URL
	options.ROOT_PATH   = profile:get("lpm.root")   or options.ROOT_PATH
	options.CACHE_PATH  = profile:get("lpm.cache")  or options.CACHE_PATH

	--utils.pprint(options)
end

lpm_load_settings()

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Lua Package Manager, 一个简单的包管理工具，用来实现 OTA 自动热更新
-- 

local PackageManager = core.Emitter:extend()
exports.PackageManager = PackageManager


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 
-- 
function PackageManager.copyFile(sourceFile, destFile)
	local destFd = fs.openSync(destFile, "w", 511)
    if (not destFd) then
        return false, destFile .. ' open failed!'
    end

    local offset = fs.statSync(sourceFile).size
    
    local srcFd = assert(fs.openSync(sourceFile, "r", 384)) -- 0600
    fs.sendfileSync(destFd, srcFd, 0, offset)
    fs.closeSync(srcFd)

    fs.closeSync(destFd)
    return true
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 初始化方法/构造函数
-- 
function PackageManager:initialize()
    self.board			= options.BOARD
    self.cachePath		= options.CACHE_PATH
    self.installPath   	= options.ROOT_PATH
    self.packages   	= {}
    self.sourceUrl     	= options.SOURCE_URL

	if (not fs.existsSync(self.cachePath)) then
		fs.mkdirpSync(self.cachePath)
	end
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 检查源列表信息
-- 
function PackageManager:_checkList(list)
	if (self.board ~= list.board) then
		self:_showError('_checkList: invalid board type: ' .. (list.board or ""))
		return false

	elseif (#list.packages < 1) then
		self:_showError('_checkList: empty packages list')
		return false
	end

	return true
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 检查指定的包
-- 
function PackageManager:_checkPackage(packageInfo, filename)
	local statInfo = fs.statSync(filename)
	if (not statInfo) then
		return true
	end

	-- pprint(statInfo.size)

	return true
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 检查是否可以更新
-- 
function PackageManager:_checkUpdate(packageInfo)
	local name = packageInfo.name
	--pprint(packageInfo)	

	print('- Check ' .. name .. ".")
	local oldInfo = self:_loadPackageInfo(name) or {}
	--pprint(oldInfo)

	local oldVersion = self:_getVersionCode(oldInfo.version)
	local newVersion = self:_getVersionCode(packageInfo.version)
	local oldname = name .. '@' .. (oldInfo.version or "0.0.0")
	if (oldVersion ~= newVersion) then
		local newname = "@" .. (packageInfo.version or '0.0.0')
		local data = utils.colorize("quotes", newname);
		print("  Package '" .. oldname .. "' available update: " .. data)
		return true
	else
		print("  Package '" .. oldname .. "' no updates available.")
	end

	return false
end

function PackageManager:_checkCachePackageInfo(packageInfo)
	if (type(packageInfo) ~= 'table') then
		return true
	end

	local filename = path.join(self.cachePath, packageInfo.name .. ".zip")
	local fileInfo = fs.statSync(filename)
	if (not fileInfo) then
		return false
	end

	local data = self:_readBundleFile(filename, "package.json")
	if (not data) then
		return false
	end

	local package = data and json.parse(data)
	if (type(package) ~= 'table') then
		return false
	end

	if (fileInfo.size ~= packageInfo.size) then
		print('  Package Size: ' .. fileInfo.size .. "/" .. packageInfo.size)
		return false

	elseif (package.version ~= packageInfo.version) then
		print('  Package Version: ' .. package.version .. "/" .. packageInfo.version)
		return false
	end	

	return true
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 下载指定的包
-- 
function PackageManager:_downloadPackage(packageInfo)
	if (self:_checkCachePackageInfo(packageInfo)) then
		self:_installPackage(packageInfo)
		return true
	end

	local filename = packageInfo.filename
	local packageUrl = url.resolve(self.sourceUrl, filename)
	print('  Package URL: ' .. packageUrl)

	local request = http.get(packageUrl, function(response)
		
		local contentLength = tonumber(response.headers['Content-Length'])
		print('  Start download: ', contentLength)

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
					print("  Downloading (" .. percent .. "%)  " .. downloadLength .. "/" .. contentLength .. ".")
				end
			end
		end)

		response:on('end', function()
			local content = table.concat(data)
			print("  Download done: ", response.statusCode, #content)
			--pprint("end", response.statusCode)
			self:_savePackage(packageInfo, content)

			self:_installPackage(packageInfo)
		end)

		response:on('error', function(err)
			self:_showError('  Download package failed: ' .. (err or ''))
		end)
	end)

	request:on('error', function(err) 
		self:_showError('  Download package failed: ' .. (err or ''))
	end)
end

function PackageManager:_getVersionCode(version)
	if (not version) then
		return 0
	end

	local tokens = version:split('.');
	if (#tokens < 3) then
		return 0
	end

	local value = (tokens[1] or 0) * 1000 * 10000 + (tokens[2]) * 10000 + (tokens[3])
	return math.floor(value)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 安装指定路径和名称的包
-- @param name String 
-- 
function PackageManager:_installPackage(packageInfo)
	if (not packageInfo) or (not packageInfo.name) then
		self:_showError('Bad package info!')
		return
	end

	-- install path
	print("- Install '" .. packageInfo.name .. "'.")
	if (not fs.existsSync(self.installPath)) then
		print(fs.mkdirpSync(self.installPath))
	end

	-- check source package
	local filename = path.join(self.cachePath, packageInfo.filename)
	if (not fs.existsSync(filename)) then
		self:_showError('  Package file not exists: ' .. filename)
		return

	elseif (not self:_checkPackage(packageInfo, filename)) then
		self:_showError('  Bad package file format: ' .. filename)
		return
	end

	-- copy package file
	local target = path.join(self.installPath, packageInfo.name .. options.EXT_NAME)
	local tmpfile = target .. ".tmp"

	PackageManager.copyFile(filename, tmpfile)
	if (not fs.existsSync(tmpfile)) then
		self:_showError('  Copy package file failed: ' .. filename)
		return
	end

	-- check package md5sum
	local fileData = fs.readFileSync(tmpfile)
	local md5sum = self:_toHexString(lutils.md5(fileData))
	if (md5sum ~= packageInfo.md5sum) then
		self:_showError('  MD5 sum check failed: ' .. md5sum)
		return
	end

	-- rename package file
	os.remove(target)
	os.rename(tmpfile, target)

	print("  Install '" .. packageInfo.name .. "' to " .. target)

	return 0
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--
function PackageManager:_loadPackageInfo(name)
	local filename = path.join(self.installPath, name .. options.EXT_NAME)
	local data = self:_readBundleFile(filename, "package.json")
	if (not data) then
		return nil
	end

	local package = data and json.parse(data)
	if (not package) then
		return nil
	end	

	--pprint(package)
	return package
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 读取本地的源列表文件
-- 
function PackageManager:_loadPackageList()
	local filename = path.join(self.cachePath, 'packages.json')
	local content = fs.readFileSync(filename)
	if (not content) then
		self:_showError('_loadPackageList: invalid list data: ' .. filename)
		return false
	end

	local json_data = json.parse(content)
	if (not json_data) then
		self:_showError('_loadPackageList: invalid json format.')
		return false
	end	

	if (not self:_checkList(json_data)) then
		self:_showError('_loadPackageList: invalid packages format.')
		return false
	end

	self.packages = json_data.packages
	return true
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 
-- 
function PackageManager:_readBundleFile(filename, path)
    if (type(path) ~= 'string') then
        return nil, "bad path"

    elseif (type(filename) ~= 'string') then
        return nil, "bad filename"
    end

    local reader = miniz.new_reader(filename)
    if (reader == nil) then
        return nil, "bad bundle file"
    end

    local index, err = reader:locate_file(path)
    if (not index) then
        return nil, 'not found'
    end

    if (reader:is_directory(index)) then
        return nil, "is directory"
    end

    local data = reader:extract(index)
    if (not data) then
        return nil, "extract failed"
    end

    return data
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 显示错误信息
-- 
function PackageManager:_showError(errorInfo)
	print('ERROR:', utils.colorize("err", errorInfo))

end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 保存指定的包到缓存目录
-- 
function PackageManager:_savePackage(packageInfo, content)
	local name = packageInfo.name

	local filename = path.join(self.cachePath, name .. ".zip")
	os.remove(filename)
	fs.writeFileSync(filename, content)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 保存指定的源数据到缓存目录
-- 
function PackageManager:_savePackageList(list_data)
	if (not list_data) then
		return nil, 'invalid packages list data'
	end

	local json_data = json.parse(list_data)
	if (not json_data) or (not json_data.packages) then
		return nil, 'invalid packages json format'
	end	

	if (not self:_checkList(json_data)) then
		return nil, 'invalid packages json list data'
	end

	self.packages = json_data.packages

	-- save to file
	local filename = path.join(self.cachePath, 'packages.json')
	fs.writeFileSync(filename, list_data)
	print("Save 'packages.json' to " .. utils.colorize("quotes", filename))

	return json_data
end

function PackageManager:_toHexString(text) 
    local list = {}
    for i = 1,#text do
        local ch = text:byte(i)
        table.insert(list, string.format("%02x", ch, ch))
    end

    return table.concat(list)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 更新源，从源服务器下载最新的包列表文件
-- 
function PackageManager:_updatePackageList(callback)
	local sourceUrl = self.sourceUrl;
	if (not sourceUrl) then
		self:_showError("Invalid srouce URL.")
		return
	end

	print('Start updating...')
	print('Source "' .. sourceUrl .. '"...')
	local request = http.get(sourceUrl, function(response)
		print('Connected, starting download...')
		--pprint('response', response)

		local data = {}

		response:on('data', function(chunk)
			table.insert(data, chunk)
		end)

		response:on('end', function()
			local content = table.concat(data)
			local data, err = self:_savePackageList(content)

			if (err) then
				self:_showError('update: ' .. err)
			else
				print("Update done (" .. #content .. ").")
			end

			if (callback) then
				callback(data, err)
			end
		end)
	end)

	request:on('error', function(...) 
		print('Update failed: ', ...)
	end)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

function PackageManager:build(buildPath)
	if (not buildPath) then
		self:_showError('Need build path!')
		return
	end

	if (not fs.existsSync(buildPath)) then
		self:_showError(buildPath .. ' not exists!')
		return
	end

	local files = fs.readdirSync(buildPath)
	if (not files) then
		self:_showError(buildPath .. ' readdir failed!')
		return
	end

	local list = {}
	local packages = {}
	list["board"] = options.BOARD
	list["packages"] = packages

	print("Start Build... ")
	for i = 1, #files do
		local file = files[i]

		if not file:endsWith(".zip") then
			print('skip ', file)
			goto continue
		end

		local filename 	= path.join(buildPath, file)
		local data 		= self:_readBundleFile(filename, "package.json")
		local package 	= data and json.parse(data)
		if (not package) then
			self:_showError('bad package.json file.')
			goto continue
		end

		if (not package.name) then
			self:_showError('bad package.json format.')
			goto continue
		end	

		local statInfo = fs.statSync(filename)
		if (not statInfo) then
			self:_showError('bad package file.')
			goto continue
		end	

		local fileData = fs.readFileSync(filename)
		local md5sum = lutils.md5(fileData)

		package['size'] 	= statInfo.size
		package['filename'] = package.name .. ".zip"
		package['md5sum']   = self:_toHexString(md5sum)

		print("build", utils.colorize("highlight", filename), package.size)
		table.insert(packages, package)

		::continue::
	end

	local list_data = json.stringify(list)
	local filename = path.join(buildPath, 'packages.json')
	fs.writeFileSync(filename, list_data)

	print('output: ' .. utils.colorize("quotes", filename))
	print("Done. ")	
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 检查所有包
-- 
function PackageManager:check()
	print("-----------------------------")
	print('npm conf:  ' .. tostring(options.conffile))
	print('npm board: ' .. self.board)
	print('npm root:  ' .. self.installPath)
	print('npm cache: ' .. self.cachePath)
	print('Start checking...')

	self:_updatePackageList(function(data, err)
		if (err) then
			print("Done.")
			return
		end

		if (not self:_loadPackageList()) then
			print("Done.")
			return 
		end

		for i = 1, #self.packages do
			local item = self.packages[i]
			self:_checkUpdate(item)
		end

		print("Done.")
	end)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 清除缓存数据等
-- 
function PackageManager:clean()
	if (not fs.existsSync(self.cachePath)) then
		self:_showError(self.cachePath .. ' not exists!')
		return
	end

	local files = fs.readdirSync(self.cachePath)
	if (not files) then
		return
	end

	print("Start clearing... ")
	for i = 1, #files do
		local file = files[i]
		if (not file:endsWith("packages.json")) then
			local filename = path.join(self.cachePath, file)
			os.remove(filename)

			print("  Remove: ", filename)
		end
	end

	print("Done. ")
end

function PackageManager:call(args)
	local command 	= args[1]
	local param 	= args[2]

	if (not command) or (command == 'help') then
		self:help(param)
		return
	end

	local func = self[command]
	if (type(func) == 'function') then
		local lockfile = path.join(self.cachePath, 'lpm.lock')
		local data = tostring(process.pid)
		fs.mkdirpSync(self.cachePath)
		if (fs.existsSync(lockfile)) then
			print("lpm is locked!")

		else 
			fs.writeFileSync(lockfile, data)
			local status, ret = pcall(func, self, param)
			run_loop()
			fs.unlinkSync(lockfile)
		end
		return ret
	end

	print("Unknown command: " .. command)
	self:help()
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 显示帮助信息
-- 
function PackageManager:help()
	local text = [[
Node.lua Package Manager 1.0.0

Usage: lpm <command>

where <command> is one of:
]] ..
utils.colorize("quotes", '    check, clean, help, install, list, remove, show, start, stop, update') ..
[[


- check             Check update information
- clean             Clean all cache data
- help              Get help on lpm
- install           Install all packages
- list              List all packages
- remove <package>  Remove a package
- show <package>    Show a package information
- start <package>   Start a package
- stop <package>    Stop a package
- update            Update all packages
]]
	print(text)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 安装所有已经下载的包
--
function PackageManager:install(param)
	if (not self:_loadPackageList()) then
		return 
	end

	print('Start install...')

	for i = 1, #self.packages do
		local item = self.packages[i]
		self:_installPackage(item)
	end

	print("Done.")
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 显示所有已安装的包的信息
-- 
function PackageManager:list()
	if (not fs.existsSync(self.installPath)) then
		self:_showError(self.installPath .. ' not exists!')
		return
	end

	local files = fs.readdirSync(self.installPath)
	if (not files) then
		return
	end

	print("Start list...")
	for i = 1, #files do
		local file = files[i]
		if (file:endsWith(options.EXT_NAME)) then
			--pprint('list', file)
			local filename = path.join(self.installPath, file)
			local name = path.basename(file, options.EXT_NAME)
			pprint('name', name)

			local oldInfo = self:_loadPackageInfo(name) or {}
			pprint(oldInfo)
		end
	end

	print("Done.")
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 删除指定的包
-- 
function PackageManager:remove()
	if (not fs.existsSync(self.installPath)) then
		self:_showError(self.installPath .. ' not exists!')
		return
	end

	local files = fs.readdirSync(self.installPath)
	if (not files) then
		return
	end

	print("Start remove...")
	for i = 1, #files do
		local file = files[i]
		if (file:endsWith(".package.json")) then
			pprint('remove', file)

			local filename = path.join(self.installPath, file)
			os.remove(filename)
		end
	end

	print("Done.")
end

function PackageManager:start(name)
	if (not name) then
		self:help()
		return
	end

	if (not self:_loadPackageList()) then
		return
	end

	package.cpath = package.cpath .. ';' .. self.installPath .. path.sep .. "?" .. options.EXT_NAME
	-- print(package.cpath)

	print("-----------------------------")
	print("Start package: " .. name)

	local packageInfo = nil

	for i = 1, #self.packages do
		local package = self.packages[i]
		-- print('- package: ' .. utils.colorize("quotes", package.name .. '@' .. package.version))

		if (package.name == name) then
			packageInfo = package
			break
		end
	end

	local filename = path.join(self.installPath, name .. options.EXT_NAME)
	local fileInfo = fs.statSync(filename)
	if (not fileInfo) then
		print('Package not exists! ', filename)
		return false
	end

	local data, err = self:_readBundleFile(filename, "bin/main")
	if (not data) then
		print('main not exists! ', err, filename)
		return false
	end

	if (data:startsWith('#')) then
		data = data:gsub('#!', '--')
	end

	local script, err = load(data, 'main')
	if (err) then
		print(err, data)
		return
	end

	script()
end

function PackageManager:stop(name)
	if (not name) then
		self:help()
		return
	end

	
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- 更新所有的包
-- 
function PackageManager:update()
	local sourceUrl = self.sourceUrl;
	if (not sourceUrl) then
		self:_showError("Invalid source URL.")
		return
	end

	self:_updatePackageList(function(data, err)
		if (err) then
			print("Done.")
			return
		end

		if (not self.packages or #self.packages < 1) then
			self:_loadPackageList()

			if (not self.packages) then
				return
			end
		end

		print('Start upgrading (' .. #self.packages .. ")...")

		for i = 1, #self.packages do
			local item = self.packages[i]

			print("Upgrade " .. item.name .. " ...")
			if (self:_checkUpdate(item)) then
				self:_downloadPackage(item)
			end
		end
	end)
end

return exports

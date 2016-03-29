local init  = require('init')
local core  = require('core')
local utils = require('utils')
local miniz = require('miniz')
local path  = require('path')
local fs    = require('fs')

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Node.lua 包读写类
-- Node.lua 包为标准的 ZIP 打包格式

local exports = {}

exports.name        = "node.lua/bundle"
exports.version     = "1.0.0-1"
exports.license     = "Apache 2"
exports.homepage    = ""
exports.description = "Utilities for node.lua bundle."
exports.tags        = { "node.lua", "bundle", "loader" }

exports = { meta = exports }


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Bundle 包生成器, 将零散的 lua 文件打包成统一的 bundle 包. 更方便文件的管理
--
-- @param basePath 要打包的目录
-- @param target 要生成的目标文件

local BundleBuilder = core.Emitter:extend()
exports.BundleBuilder = BundleBuilder

function BundleBuilder:initialize(basePath, target)
    self.basePath   = basePath
    self.target     = target
    self.libOnly    = true
    self.libPath    = "lua"
    self.bins       = {}
    self.files      = {}
end

function BundleBuilder:addLua(file)
    self.libPath = file
end

function BundleBuilder:addBin(file)
    table.insert(self.bins, file)
end

function BundleBuilder:addFile(file)
    table.insert(self.files, file)
end

function BundleBuilder:build()
    if ((not self.basePath) or (not self.target)) then
        return 'bad path or target'
    end

    -- start
    print(" start...")

    local filename = self.target
    local dirname = path.dirname(filename)
    if (not fs.existsSync(dirname)) then
        fs.mkdirpSync(dirname)
    end

    local fd = fs.openSync(filename, "w", 511)
    if (not fd) then
        return filename .. ' open failed!'
    end

    local writer = miniz.new_writer()
    if (not writer) then
        return -1
    end

    self.writer = writer

    -- just read the base file size
    local offset = 0
    if (not self.libOnly) then
        local source = process.exepath()
        offset = fs.statSync(source).size
        
        local fd2 = assert(fs.openSync(source, "r", 384)) -- 0600
        fs.sendfileSync(fd, fd2, 0, offset)
        fs.closeSync(fd2)
    end

    -- add lua files
    local pathname = path.join(self.basePath, self.libPath)
    if (fs.existsSync(pathname)) then
        self:copyLuaFolder(pathname, "")
    end
    
    -- add bin files
    self:copyBins()
    self:copyFiles()

    -- finish
    fs.writeSync(fd, offset, writer:finalize())
    fs.closeSync(fd)

    print(" done.")
    return 0
end

function BundleBuilder:copyBins()
    for i = 1, #self.bins do
        local file = self.bins[i]
        self:copyFile(file, "bin/"..path.basename(file))
    end
end

function BundleBuilder:copyFile(srcfile, destfile)
    local fullPath = path.join(self.basePath, srcfile)
    local filedata = fs.readFileSync(fullPath)
    local filename = destfile:gsub('\\', '/')

    if (not filedata) then
        return
    end

    if os.type() == "win32" then
        if (srcfile:endsWith(".lua")) then
            local script = load(filedata)
            if (script) then
                filedata = string.dump(script, true)
            end
        end
    end

    self.writer:add(filename, filedata, 9)
     print("  add file", utils.colorize("highlight", filename))
    
end

function BundleBuilder:copyFiles()
    for i = 1, #self.files do
        local file = self.files[i]
        self:copyFile(file, file)
    end
end

function BundleBuilder:copyLuaFile(basePath, subPath, name)
    local childPath = path.join(subPath, name)
    local fullPath  = path.join(basePath, childPath)
    
    local stat = self:getFileInfo(fullPath)
    if stat.type == "directory" then
        local dirname = childPath .. "/"
        dirname = "lib/"..dirname:gsub('\\', '/')
        print("  add dir", utils.colorize("success", dirname))

        self.writer:add(dirname, "")
        self:copyLuaFolder(basePath, childPath)

    elseif stat.type == "file" then
        if (name:endsWith('.lua')) then
            self:copyFile(self.libPath .. "/" ..childPath, "lib/"..childPath)
        else 
            return
        end
    end
end

function BundleBuilder:copyLuaFolder(basePath, subPath)
    local pathName = path.join(basePath, subPath)
    local files = fs.readdirSync(pathName)
    if (not files) then return end

    for i = 1, #files do
        local name = files[i]
        if (name:sub(1, 1) ~= ".") then
            self:copyLuaFile(basePath, subPath, name)
        end
    end
end

function BundleBuilder:getFileInfo(filename)
    local statInfo, err = fs.statSync(filename)
    if (not statInfo) then return nil, err end

    return {
        type    = string.lower(statInfo.type),
        size    = statInfo.size,
        mtime   = statInfo.mtime,
    }
end


exports.loadBundleFile = loadBundleFile

return exports

local path 	= require("path")
local fs   	= require("fs")
local core 	= require("core")
local utils = require("utils")

local pprint = utils.pprint

local exports = {}

exports.search_path = "/system/app"

local Profile = core.Emitter:extend()
exports.Profile = Profile

function Profile:initialize(filename)
	local data = fs.readFileSync(filename)
	self:_load(data)

	self.filename = filename

	if (not self.settings) then
		self.settings = {}
	end

	
end

function Profile:_load(text)
	if (type(text) ~= "string") then
		return
	end

	local env = {}
	local ret, err = load(text, "settings", "t", env)
	if (err) then
		pprint(ret, err)
	end

	local settings, err = pcall(ret)
	if (err) then
		pprint(settings, err)
	end

	self.settings = env.settings or {}
end

function Profile:save(text)
	local tempname = self.filename .. ".tmp"
	local data = "settings = " .. self:toString()

	os.remove(tempname)

	fs.writeFileSync(tempname, data)
	local info = fs.statSync(tempname)
	if info and (info.size == #data) then
		os.remove(self.filename)
		os.rename(tempname, self.filename)
	end
end

function Profile:get(key)
	if (type(key) ~= "string") then
		return
	end

	local tokens = key:split(".")
	--pprint(tokens)

	local settings = self.settings or {}

	local value = nil
	for i = 1, #tokens do
		if (type(settings) ~= 'table') then
			return
		end

		local token = tokens[i]
		value = settings[token]
		if (value == nil) then
			return
		end

		settings = value
	end
	return value
end

function Profile:set(key, value)
	if (type(key) ~= "string") then
		return
	end

	local tokens = key:split(".")
	--pprint(tokens)

	if (type(self.settings) ~= 'table') then
		self.settings = {}
	end

	local settings = self.settings
	for i = 1, #tokens do
		local token = tokens[i]

		if (i == #tokens) then
			settings[token] = value
			break
		end
		
		if (type(settings[token]) ~= 'table') then
			settings[token] = {}
		end

		settings = settings[token]
	end

	return 0
end

function Profile:_encodeValue(sb, value, indent)
	if (value == nil) then
		sb:append("nil")

	elseif (type(value) == 'string') then
		sb:append('"'):append(value):append('"')

	elseif (type(value) == 'number') then
		sb:append(value)

	elseif (type(value) == 'boolean') then
		if (value) then
			sb:append('true')
		else 
			sb:append('false')	
		end

	elseif (type(value) == 'table') then
		self:_encodeTable(sb, value, indent)	
	else
		sb:append("nil")
	end
end

function Profile:_encodeTable(sb, object, indent)
	if (not indent) then
		indent = ""
	end

	local nextIndent = indent .. "  "
	local sep = ""

	local keys = {}
	for k,v in pairs(object) do
		table.insert(keys, k)
	end
	table.sort( keys, function(a, b) return a < b end)

	sb:append("{\n")
	for i = 1, #keys do
		local k = keys[i]
		local v = object[k]

		sb:append(sep)
		sb:append(nextIndent)
		sb:append(k)
		sb:append(" = ")
		self:_encodeValue(sb, v, nextIndent)

		sep = ",\n"
	end

	if (#sep == 0) then
		sb:append("}\n")

	else
		sb:append("\n")
		sb:append(indent)
		sb:append("}")
	end
end

function Profile:toString()
	if (type(self.settings) == nil) then
		return
	end

	utils.pprint(self.settings)

	local sb = utils.StringBuffer:new()
	self:_encodeTable(sb, self.settings, "")
	return sb:toString()
end

exports.load = function(name)
	if (type(name) ~= 'string') then
		return nil, 'bad profile name'
	end

	local exepath = path.dirname(process.exepath())
	local basepaths = { exports.search_path, exepath }
	local conffile = nil

	--pprint(basepaths)

	for i = 1, #basepaths do
		local filename = path.join(basepaths[i], name)
		if (fs.existsSync(filename)) then
			conffile = filename
			break
		end
	end

	if (not conffile) then
		return nil, name .. ' not exists!'
	end

	return Profile:new(conffile)
end

return exports

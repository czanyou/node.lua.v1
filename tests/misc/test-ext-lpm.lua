local fs 	= require('fs')
local path 	= require('path')

local bundle = require('ext/bundle')
local lpm = require('ext/lpm')

return require('ext/tap')(function (test)

	test("Lua Package Manager Help", function (print, p, expect, uv)
		local lpm = lpm.PackageManager:new()
		lpm:help()
	end)

	test("Lua Package Manager Update", function (print, p, expect, uv)
		local lpm = lpm.PackageManager:new()
		lpm:update()
	end)

	test("Lua Package Manager List", function (print, p, expect, uv)
		local lpm = lpm.PackageManager:new()
		lpm:list()
	end)

	test("Lua Package Manager Install", function (print, p, expect, uv)
		local cwd = process.cwd()
		local lpm = lpm.PackageManager:new()
		lpm.installPath = path.join(cwd, "tmp/install")
		lpm.cachePath  = path.join(cwd, "uv")

		local info = {
			name = "test", 
			md5sum = "098f6bcd4621d373cade4e832627b4f6",
			filename = "README.md"
		}

		assert(lpm:_installPackage(info) ~= nil)
	end)	

end)

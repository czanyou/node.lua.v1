local fs 	= require('fs')
local path 	= require('path')
local utils = require("utils")

local bundle = require('ext/bundle')
local lpm 	 = require('ext/lpm')
local conf 	 = require('ext/conf')
local pprint = utils.pprint

local dns  = require('dns')


function main()



end

--main()
--run_loop()

return require('ext/tap')(function (test)

	test(" profile", function (print, p, expect, uv)
			local text = [[
		settings = {
			test = {
				name = "lucy"
			},
			video = {
				w = 100,
				a = true,
				b = false,
				h = 200
		}
		}

		]]

		local filename = "test.conf"
		local profile = conf.Profile:new(filename)
		profile:_load(text)
		profile:set("audio.channel", 2)
		profile:set("video.w", 400.3)
		profile:set("test.name", "gigi")
		profile.filename = "E:/test.conf"

		print(profile:get("test.name"));
		print(profile:get("video.w"));
		print(profile:get("video.h"));

		print(profile:toString())	

		profile:save()
	end)

	test("Load profile", function (print, p, expect, uv)
		local profile, err = conf.load("lpm.conf")
		if (err) then
			pprint(profile, err)
		end

		print("lpm.source", "[" .. profile:get("lpm.source") .. "]")
		print("lpm.root", "[" .. profile:get("lpm.root") .. "]")
		--print(profile:toString())
	end)

	test("Load profile", function (print, p, expect, uv)

	end)
end)


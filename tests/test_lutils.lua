local init  = require('init')
local utils = require('utils')
local miniz = require('miniz')
local path  = require('path')
local uv    = require('uv')
local core  = require('core')

local lutils  = require('lutils')
local bundle  = require('ext/bundle')
local test    = require('vision/utils/test')

local pprint = utils.pprint
local assert_true  = test.assert_true
local assert_equal = test.assert_equal
local assert_false = test.assert_false

function test_md5()
	local data = "888888"
	local hash = lutils.md5(data)
	--pprint(hash)

	utils.printBuffer(hash)
end

function test_hex()
	local data = "888888"
	local hash = lutils.hex_encode(data)
	pprint(hash)

	local raw = lutils.hex_decode(hash)
	pprint(raw)

	pprint(lutils.hex_decode(''))
	pprint(lutils.hex_encode(''))
end

function test_base64()
	local data = "888888"
	local hash = lutils.base64_encode(data)
	pprint(hash)

	local raw = lutils.base64_decode(hash)
	pprint(raw)

	pprint(lutils.base64_decode(''))
	pprint(lutils.base64_encode(''))
end

test_md5()
test_base64()
test_hex()

run_loop()
	
local ret, rng 	= pcall(require, 'lmbedtls.rng')
local utils 	= require('utils')
local lcrypto 	= require('tls/lcrypto')
local tap 		= require('ext/tap')

console.log(rng)

tap(function(test)
    test("test random", function()

		local rng_test = rng.new()
		console.log(rng_test)

		rng_test:set_resistance(true)
		rng_test:set_entropy_length(32)
		rng_test:set_reseed_interval(1000)
		rng_test:reseed("new seed")
		rng_test:update("seed")

		console.log(utils.bin2hex(rng_test:random(16)))
	end)

    test("test randomBytes", function()
		console.log(utils.bin2hex(lcrypto.randomBytes(16)))
	end)
end)
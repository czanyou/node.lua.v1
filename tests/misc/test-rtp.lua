local init = require('init')
local uv = require('uv')
local fs = require('fs')
local timer = require('timer')
local buffer = require('buffer')
local p = require('ext/print').prettyPrint

local path = '/tmp/video.rtp'

local info = fs.lstatSync(path)
-- p(info)

function processBuffer(data)
	local position, size, endSize

	position = 1
	endSize = position + #data
	while (true) do
		if ((position + 4) >= endSize) then
			break
		end

		local header = string.sub(data, position, position + 4)
		local code, channel, length = string.unpack('>BBI2', header)

		if (code ~= 36) then
			break
		end

		local packet = string.sub(data, position + 4, position + length + 4)

		-- p(position, code, channel, length + 4, #packet, #header)

		local head, payload, seq, timestamp, ssrc, nalu1, nalu2 = string.unpack('>BBI2I4I4BB', packet)

		if (payload == 96) then
			p(position, head, payload, seq, timestamp, ssrc, nalu1, nalu2)
		end

		position = position + length + 4;
	end
end

local stream = fs.createReadStream(path)

stream:on('data', function(data)
	p('data', #data)

	processBuffer(data)
end)

stream:on('end', function()
	p('end')
end)

print('ret', ret);
run_loop()
local uv = require('uv')

local counter = 0
local idle = uv.new_idle()
idle:start(function()
    counter = counter + 1
    if counter >= 10e5 then
        idle:stop()
    end
end)

print("Idling...")
uv.run('default')
uv.loop_close()
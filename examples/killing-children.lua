local p  = require('utils').pprint
local uv = require('uv')

local child, pid
child, pid = uv.spawn("sleep", {
  args = {"100"}
}, function (code, signal)
  p("EXIT", {code=code,signal=signal})
  uv.close(child)
end)

p{child=child, pid=pid}

-- uv.kill(pid, "SIGTERM")
uv.process_kill(child, "SIGTERM")

repeat
  print("\ntick.")
until uv.run('once') == 0

print("done")


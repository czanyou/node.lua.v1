local uv      = require('uv')
local utils   = require('utils')

local pprint    = utils.pprint
local colorize  = utils.colorize

-- test
_G.module       = {}
_G.module.dir   = uv.cwd()
_G.module.path  = uv.cwd()
_G.p            = pprint

-- protect
local function protect(...)
    local n = select('#', ...)
    local arguments = {...}
    for i = 1, n do
        arguments[i] = tostring(arguments[i])
    end

    local text = table.concat(arguments, "\t")
    text = "  " .. string.gsub(text, "\n", "\n  ")
    --print(text)

    return ...
end

local function pprotect(...)
    local n = select('#', ...)
    local arguments = { ... }

    for i = 1, n do
        arguments[i] = utils.dump(arguments[i])
    end

    return protect(table.concat(arguments, "\t"))
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local tests = {};

local function run()
    local passed = 0

    if #tests < 1 then
        error("!!! No tests specified!")
    end

    print(colorize("success", "### Test Suite with " .. #tests .. " Tests."))
    for i = 1, #tests do
        local test = tests[i]

        print(colorize("highlight", "#### Runing Test " .. i .. "/" .. #tests .. " '" .. test.name .. "':"))

        local cwd = uv.cwd()
        local pass, err = xpcall(function ()
            local expected = 0
            local function expect(fn, count)
                expected = expected + (count or 1)
                return function (...)
                    expected = expected - 1
                    local ret = fn(...)
                    collectgarbage()
                    return ret
                end
            end

            test.func(protect, pprotect, expect, uv)

            collectgarbage()
            uv.run()
            collectgarbage()

            if expected > 0 then
                error("Missing " .. expected .. " expected call" .. (expected == 1 and "" or "s"))

            elseif expected < 0 then
                error("Found " .. -expected .. " unexpected call" .. (expected == -1 and "" or "s"))
            end

            collectgarbage()

            if uv.cwd() ~= cwd then
                error("Test moved cwd from " .. cwd .. " to " .. uv.cwd())
            end

            collectgarbage()
        end, debug.traceback)

        -- Flush out any more opened handles
        uv.stop()
        uv.walk(function (handle)
            if handle == stdout then return end
            --if not uv.is_closing(handle) then uv.close(handle) end
        end)
        uv.run()
        uv.chdir(cwd)

        if pass then
            print("==== Finish '" .. test.name .. "'.")
            passed = passed + 1

        else
            protect(err)
            print("!!!! Failed '" .. test.name .. "'.")
        end
    end -- end for i = 1, #tests do

    -- failed count
    local failed = #tests - passed
    if failed == 0 then
        print("## All tests passed")
    else
        print("##" .. failed .. " failed test" .. (failed == 1 and "" or "s"))
    end

    -- Close all then handles, including stdout
    --uv.walk(uv.close)
    uv.run()
    os.exit(-failed)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local single = true
local prefix = nil

local function tap(suite)

    if type(suite) == "function" then
        -- Pass in suite directly for single mode
        suite(function (name, func) -- test function
            if prefix then
                name = prefix .. ' - ' .. name
            end

            tests[#tests + 1] = { name = name, func = func }
        end)
        prefix = nil

    elseif type(suite) == "string" then
        prefix = suite
        single = false

    else
        -- Or pass in false to collect several runs of tests
        -- And then pass in true in a later call to flush tests queue.
        single = suite
    end

    if single then run() end
end


--[[
-- Sample Usage

local passed, failed, total = tap(function (test)

  test("add 1 to 2", function(print)
    print("Adding 1 to 2")
    assert(1 + 2 == 3)
  end)

  test("close handle", function (print, p, expect, uv)
    local handle = uv.new_timer()
    uv.close(handle, expect(function (self)
      assert(self == handle)
    end))
  end)

  test("simulate failure", function ()
    error("Oopsie!")
  end)

end)
]]

return tap

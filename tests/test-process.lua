local spawn   = require('child_process').spawn
local pprint  = console.pprint
local process = require('process')

function main()

    local options = {
    	stdio = { nil, nil, nil },
    	detached = false,
     	env = { TEST1 = 1 }
    }

    child = spawn('ping', { '127.0.0.1' }, options)

    pprint('child', child.pid)

    child:on('exit', 		function(...) print(child.pid, 'exit', 			...) end)
    child:on('close', 		function(...) print(child.pid, 'close', 		...) end)
    child:on('error', 		function(...) print(child.pid, 'error', 		...) end)
    child:on('disconnect', 	function(...) print(child.pid, 'disconnect', 	...) end)

    setTimeout(1000, function()
    	child:sendMessage("test message", 1)
    	--child:close()
    end)
end

function main2()
	process:on('exit', function(...) print('exit', ...) end)

    local stdin  = process.stdin
    local stdout = process.stdout

    stdin:on('close', function(...) 
        print('close', ...)
    end)  

    stdin:on('data', function(...)
        pprint('data:', ...)
    end)    

    stdout:on('close', function(...) 
        print('close', ...)
    end)

    setTimeout(100, function()
        stdout:write('test1\n')
        stdin:removeListener('data')
    end)

    setTimeout(1000, function()
        stdout:write('test2\n')
        stdin:removeAllListeners('data')
    end)
end

function main3()
    process:on('exit', function(...) 
        _print('exit event', ...) 
    end)

    pprint(os.arch(), os.platform())

    pprint(arg)
end

function main4()
    process:on('exit', function(...) 
        _print('exit event', ...) 
    end)

    pprint(os.arch(), os.platform())

    process:exit(10086)

    process.exitCode = 10086
    return 10086
end

return main3()


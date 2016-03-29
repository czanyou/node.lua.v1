local uv = require('uv')

local ctx = uv.new_work(
    function(n) --work,in threadpool
        local uv = require('uv')
        local t = uv.thread_self()
        print('t', t);
        uv.sleep(500)
        return n*n, n 
    end, 
    function(r,n) print(string.format('%d => %d', n, r)) end    --after work, in loop thread
)
uv.queue_work(ctx, 2)
uv.queue_work(ctx, 4)
uv.queue_work(ctx, 6)
uv.queue_work(ctx, 8)
uv.queue_work(ctx, 10)

uv.run('default')
uv.loop_close()

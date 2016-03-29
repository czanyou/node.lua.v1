local uv = require('uv')

print('Now quitting.')
uv.run('default')
uv.loop_close()

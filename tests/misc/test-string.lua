local init = require('init')
local utils = require('utils')

local pprint = utils.pprint

local data = ' \tab cd ef gh 1234 56\r\n '

pprint(data:find('cd'))
pprint(data:find('12345'))

pprint(data:length())
pprint(data:split(' '))
pprint(data:split(','))
pprint(data:split())
pprint(data:trim())

pprint(data:startsWith(' \tab'))
pprint(data:startsWith(' \tabc'))
pprint(data:endsWith(' \tab'))
pprint(data:endsWith('\r\n '))


local data2 = ' \t  \r\n '
pprint(data2:trim())

local script = string.dump(pprint)
pprint(script)

-- lnode test-string.lua
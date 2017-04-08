# Log

## 2017/1/20

- Significant refactoring, all app directories removed .app suffix, vision.lua directory refactoring, removed the vision prefix.

## 2016/11/22

- Added support for naming management

## 2016/6/14

- Simplified Lua core library, delete some of the basic functions

## 2016/6/1

- Update the Lua package search path from '/system/app/lua' to '/system/node/lua'

## 2016/5/29

- Update Windows installation method
- Add a wrapper script under Windows

## 2016/4/29

- libuv updated to 1.9.0
- Add some API documentation
- Added support for the hi3516a
- Update the Lua package search path from '/system/lib/lua/5.3' and '/system/app/lua/5.3' to '/system/app/lua', and the lua directory of Node.lua to link To '/system/app/lua/lnode', so that the search is relatively simple
- Add the Lua directory in the current directory to the package search path
- Remove the samples directory, because many of the content is obsolete, to avoid misleading
- Fixed in the Linux 64-bit system compiler problems
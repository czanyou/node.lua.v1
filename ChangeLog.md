

# 2016/4/29

- libuv 更新到 1.9.0
- 添加部分 API 的文档
- 添加对 hi3516a 的支持
- 更新 system lua 搜索路径, 从 '/system/lib/lua/5.3' 和 '/system/app/lua/5.3' 统一为 '/system/app/lua', 并且 Node.lua 的 lua 目录改为链接到 '/system/app/lua/lnode', 这样使搜索相对更加简单
- 添加当前目录 lua 目录到搜索路径中
- 删除 samples 目录, 因为很多内容已过时, 避免误导
- 修正在 Linux 64 位系统下编译的问题

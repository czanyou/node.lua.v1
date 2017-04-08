# Node.lua 核心 C 语言模块

这里保存的是 Node.lua 的核心 C 语言模块, 包括 Lua 虚拟机本身, libuv, JSON, ZIP 以及其他核心库.

# 命令约定

- 如果是 C 到 Lua 的绑定库, 项目名都以 lua 为前缀 (如 luauv), 表示这个模块可直接被 lua 加载.
- 如果是普通 C 项目则按原名即可 (如 libuv)


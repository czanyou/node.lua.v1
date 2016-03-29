# Lua 嵌入式开发环境技术要求

> - 编写：成真
> - 版本：1.0

标签（空格分隔）： 详细设计

---

## Node.lua
Node.lua 是一整套基于 lua/libuv 的动态脚本运行平台, 主要目的是简化嵌入式的开发, 但是因为 lua/libuv 极其良好的可移植性, 这一平台同时也可以用于 windows/linux 甚至 iOS/Android 平台的服务端软件或 APP 开发

## 核心库

核心库工程子目录为 /main/node.lua

### 项目依赖
目录: /main/node.lua/deps

- PUC lua 5.3 以上
- libuv 1.7.5 以上
- miniz zip 压缩库


### libuv C 语言绑定

### 类 node.js Lua 核心库
目录: /main/node.lua/lua

### 其他 

## Vision 框架

Vision 框架工程子目录为 /main/vision.lua






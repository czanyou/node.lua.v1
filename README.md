# node.lua

> - 编写：成真
> - 版本：1.0

实现和 Node.js 同样功能的 Lua 开发环境

## 项目依赖

目录: /main/node.lua/deps

node.lua 主程序，由 C 语言实现, 主要包含了 lua, libuv, miniz 等核心库

- (lua) PUC lua 5.3.2 以上
- (libuv) libuv 1.9.0 以上
- (luajson) cjson
- (luazip) miniz zip 压缩库
- (luauv)
- (luautils) buffer, hex, http parser, md5 ...

依赖库下载地址：

- http://www.lua.org/ftp/
- https://github.com/libuv/libuv
- https://github.com/richgel999/miniz
- https://github.com/mpx/lua-cjson

注意: 因为 lua 5.3 和 luajit 2 差别较大, 暂时不提供对 luajit 2 的支持.

## libuv C 语言绑定

开源项目下载地址

    https://github.com/luvit/luv

主要是将 libuv 绑定到 lua.

在 lua 中可通过 require("uv") 调用

## 类 node.js Lua 核心库

目录: /main/node.lua/lua

node.lua 核心库，主要实现了和 node.js 相似的核心库，调用方法同样可以参考 node.js 的文档

## 文档 

目录: /main/node.lua/docs

## 其他 

其他目录定义:

- bin       目标执行文件输出目录
- build     cmake 构建临时目录
- deps      依赖的项目存放目录
- docs      文档存放目录
- examples  参考代码目录
- lua       Lua 核心库源代码目录
- src       C语言绑定源代码目录
- tests     测试用例目录

### 根目录文件

- build.lua     打包 lua 文件, 生成 lnode.zip
- CMakeLists.txt cmake 配置文件
- install.bat   Windows 下执行 install.lua 文件的批处理文件
- install.lua   运行环境安装脚本
- LICENSE       开源协议文件
- make.bat      Windows 下 cmake 批处理文件
- Makefile      Makefile
- package.json  lnode.zip 包元数据文件
- README.md     说明文件

### bin 目录文件

- lpm           Lua Package Manager 执行文件
- lpm.cmd       Windows 下执行 lpm 文件的批处理文件
- main          lnode.zip 主程序

## 构建

### 主程序

主要采用 cmake 构建和编译代码, 编译前需先安装 cmake 软件

生成文件: 
    bin/lnode (独立执行文件)

以及:
    bin/libluanode.so (模块文件)
    bin/lshell (依赖于 libluanode.so)

#### Windows 编译

先安装 cmake 和 visual studio, 然后运行 make.bat, 将成生成 build/win32 目录 

#### 交叉编译

交叉编译 hi3518，先安装 cmake 和 hi3518 工具链，然后运行 make hi3518, 将成生成 build/hi3518 目录 

其他平台交叉编译办法:

修改 CMakeLists.txt 下面位置代码, 添加新的平台类型和工具链名称

```
# 交叉编译选项, 通过 BOARD_TYPE 参数确定编译工具链
MESSAGE(STATUS "Build: BOARD_TYPE=${BOARD_TYPE}  ")
if (BOARD_TYPE STREQUAL hi3518)
  MESSAGE(STATUS "Build: use arm-hisiv100nptl-linux-gcc")
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")
else (BOARD_TYPE STREQUAL hi3518)
  
endif (BOARD_TYPE STREQUAL hi3518)
```

修改 Makefile, 参考 hi3518 添加其他平台编译命令

```
hi3518:
#   交叉编译
    cmake -H. -Bbuild/hi3518 -DBOARD_TYPE=hi3518
    cmake --build build/hi3518 --config Debug
```

其中 

- build/hi3518 表示中间文件和目标文件生成目录 
- BOARD_TYPE=hi3518 表示CMakeLists中配置的平台类型

如果未指定将默认采用开发机的编译环境和工具

### Lua 核心库

运行脚本: 
    build.lua

生成文件: 
    bin/lnode.zip

配置文件: 
    package.json

## 安装运行/调试环境

运行脚本: install.lua
注: windows 下运行 install.bat

上述脚本将复制上面生成的可执行文件到系统目录并添加需要的环境变量














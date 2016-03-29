#lpm

> - 编写：成真
> - 版本：1.0

## 目录

[TOC]

Lua Package Manager

## 功能

lpm 通过绑定一个源来实现包的在线更新和管理， 一个源包含一个 package 列表文件
以及多个 package 文件。它们放置在同一个目录，并通过标准的 HTTP 方式访问。

## lpm 源

### 参考目录结构:

```

/sources/ipc168/packages.json
/sources/ipc168/lnode.package
/sources/ipc168/vision.package

```

### packages.json 格式
Package 源列表格式为 JSON 格式， 示例如下：

```

{
  "board": "ipc8266",
  "arch": "x86",
  "packages": [
  {
    "depends": ["lnode"],
    "description": "Vision Framework",
    "filename": "vision.package",
    "md5sum": "bffc98e4121a62e576669a81f9849851",
    "name": "vision",
    "size": 102004,
    "tags": ["vision", "runtime"],
    "version": "1.0.0"
  }
  ]
}

```

- board     表示对应的硬件板， 只要相同的硬件板/模块才可以安装这些包.
- arch      表示对应的硬件体系
- packages  表示当前源包含的包列表，格式为对象数组，它们的详细信息如下：

### package.json 格式

- depends  表示这个包依赖的包，依赖的包必须在当前包安装前被安装, 格式为字符串数组
- description 表示这个包的简要描述
- filename 表示这个包的文件名
- md5sum   表示这个包文件的 MD5 hash 值，用来确定下载的文件是否被篡改
- name     表示这个包的名称，只能包含小写字母数字以及下划线
- size     表示这个包的文件的大小 
- tags     表示这个包的标签名称, 格式为字符串数组
- version  表示这个包的版本，格式为 a.b.c, a 表示主版本号，b 表示子版号，
    c 一般表示构建版本号

## lpm 方法

### build
只用于开发, 生成最新的源 packages.json

> lpm build

### check
检查是否有更新

> lpm check

### clean
清除缓存的文件

> lpm clean

### help
显示帮组信息

> lpm help

### install
安装指定名称的包

> lpm install [package]

### list
显示当前安装的所有包

> lpm list [package]

### remove
删除指定的包, 注意系统包不可以删除 (目前没有实现)

> lpm remove [package]

### start

运行指定的包的主程序

> lpm start [package]

### update
从源更新包列表, 即下载最新的 packages.json 文件, 并更新所有包

> lpm update

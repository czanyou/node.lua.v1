# Request

[TOC]

一个简单易用的 HTTP 客户端工具。

通过 `require('http/request')` 引入这个模块。

## callback

    callback(err, response, body)

这个客户端的相关方法的回调函数。

- err {String} 如果发生错误, 这个值将不为空
- response {HttpResponse Object} 相关的应答消息对象
  + statusCode {Number} 状态码
- body {String} 返回的消息体内容

## request

    request(urlString, [options], callback)

发起一个 GET 请求并返回请求结果

- urlString {String} HTTP URL 地址
- options {Object} 请求选项
  + host {String} 服务器主机地址
  + port {Number} 服务器端口
  + path {String} 文件路径
  + timeout {Number} 超时时间
  + method {String} 请求方法
  + headers {Array} 头字段
- callback {Function} 回调函数

示例:

```lua
request('http://test.com/', function(err, response, body)
    if (err) then
        print(err)
        return
    end

    print(response.statusCode, body)
end)

```

## request.delete

    request.delete(urlString, options, callback)

发起一个 DELETE 请求并返回请求结果

- urlString {String} URL
- options {Object} 请求选项
- callback {Function} 回调函数

## request.download

    request.download(urlString, options, callback)

下载文件

- urlString {String} URL
- options {Object} 请求选项
- callback {Function} 回调函数
- 

## request.get

    request.get(urlString, [options], callback)

发起一个 GET 请求并返回请求结果

- urlString {String} URL
- options {Object} 请求选项
- callback {Function} 回调函数


## request.post

    request.post(urlString, options, callback)

发起一个 POST 请求并返回请求结果

- urlString {String} URL
- options {Object} 请求选项
  + data {String} 二进制数据, 默认使用格式为 `application/octet-stream`
  + files {Object} 文件, 使用的格式为 `multipart/form-data`
  + form {Object} 表单, 使用的格式为 `pplication/x-www-form-urlencoded`
- callback {Function} 回调函数

POST 可以向服务器发送如下内容的数据

### data - 单个文件方式

这种方式适合上传单个文件等, 消息内容仅包含文件的内容.

### form - 表单方式

表单方式上传的是键值对参数, 以 URL 方式编码.

```json
{'key':'value', ... } 
```

会被编码成:

```json
key=value&foo=bar
```

示例:

```lua
-- 通过表单方式上传数据 
local options = { form = { foo = 'bar' }}
request.post('http://test.com/upload', options, function(err, response, body)
    print(response.statusCode, body)
end)
```

### files - 文件上传

文件上传一般采用这种方式, 参数格式如下:

```json
{
    'key': { 'name': name, 'data': data }
}
```

- key {Object} 代表一个字段或一个文件
  + name {String} 文件名
  + data {String} 文件二进制数据内容

示例:

```lua

-- 通过表单方式上传文件
local filename = 'test.txt'
local filedata = fs.readFileSync(filename) 
local options = { files = { file = { name = filename, data = filedata } } }
request.post('http://test.com/upload', options, function(err, response, body)
    print(response.statusCode, body)
end)

```

## request.put

    request.put(urlString, options, callback)

发起一个 PUT 请求并返回请求结果

- urlString {String} URL 
- options {Object} 请求选项, 请参考 request.post
- callback {Function} 回调函数

示例:

```lua
-- 直接上传文件  
local filename = 'test.txt'
local filedata = fs.readFileSync(filename) 
local options = { filename = filename, data = filedata }
request.put('http://test.com/upload', options, function(err, response, body)
    print(response.statusCode, body)
end)

```
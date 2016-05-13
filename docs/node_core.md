# Core

## 

## 事件 (Events)

Node里面的许多对象都会分发事件：一个net.Server对象会在每次有新连接时分发一个事件， 一个fs.readStream对象会在文件被打开的时候发出一个事件。 所有这些产生事件的对象都是 events.EventEmitter 的实例。 你可以通过require("events");来访问该模块

通常，事件名是驼峰命名 (camel-cased) 的字符串。不过也没有强制的要求，任何字符串都是可以使用的。

为了处理发出的事件，我们将函数 (Function) 关联到对象上。 我们把这些函数称为 监听器 (listeners)。 在监听函数中 this 指向当前监听函数所关联的 EventEmitter 对象。

## 类: events.EventEmitter#

通过 require('events').EventEmitter 获取 EventEmitter 类。

当 EventEmitter 实例遇到错误，通常的处理方法是产生一个 'error' 事件，node 对错误事件做特殊处理。 如果程序没有监听错误事件，程序会按照默认行为在打印出 栈追踪信息 (stack trace) 后退出。

EventEmitter 会在添加 listener 时触发 'newListener' 事件，删除 listener 时触发 'removeListener' 事件

### emitter.addListener(event, listener)#
### emitter.on(event, listener)#

添加一个 listener 至特定事件的 listener 数组尾部。

```
server:on('connection', function (stream) 
  print('someone connected!')
end);
```

返回 emitter，方便链式调用。

### emitter.once(event, listener)#

添加一个 一次性 listener，这个 listener 只会在下一次事件发生时被触发一次，触发完成后就被删除。

```
server:once('connection', function (stream) 
  print('Ah, we have our first user!')
end)
```

返回 emitter，方便链式调用。


### emitter.removeListener(event, listener)#

从一个事件的 listener 数组中删除一个 listener 注意：此操作会改变 listener 数组中在当前 listener 后的listener 的位置下标

```
local callback = function(stream) 
  print('someone connected!')
end

server:on('connection', callback)

-- ...

server:removeListener('connection', callback)
```

返回 emitter，方便链式调用。

### emitter.removeAllListeners([event])#

删除所有 listener，或者删除某些事件 (event) 的 listener

返回 emitter，方便链式调用。

### emitter.setMaxListeners(n)#

在默认情况下，EventEmitter 会在多于 10 个 listener 监听某个事件的时候出现警告，此限制在寻找内存泄露时非常有用。 显然，也不是所有的 Emitter 事件都要被限制在 10 个 listener 以下，在这种情况下可以使用这个函数来改变这个限制。设置0这样可以没有限制。

返回 emitter，方便链式调用。

### EventEmitter.defaultMaxListeners#

emitter.setMaxListeners(n) 设置每个 emitter 实例的最大监听数。 这个类属性为 所有 EventEmitter 实例设置最大监听数（对所有已创建的实例和今后创建的实例都将立即生效）。 使用时请注意。

请注意，emitter.setMaxListeners(n) 优先于 EventEmitter.defaultMaxListeners。

### emitter.listeners(event)#

返回指定事件的 listener 数组

```
server:on('connection', function (stream) 
  print('someone connected!')
end);

print(server:listeners('connection')); // [ [Function] ]
```

### emitter.emit(event, [arg1], [arg2], [...])#

使用提供的参数按顺序执行指定事件的 listener

若事件有 listeners 则返回 true 否则返回 false。

### 类方法: EventEmitter.listenerCount(emitter, event)#

返回指定事件的 listeners 个数

### 事件: 'newListener'#

- event {String} 事件名
- listener {Function} 事件处理函数

在添加 listener 时会发生该事件。 此时无法确定 listener 是否在 emitter.listeners(event) 返回的列表中。


### 事件: 'removeListener'#

- event {String} 事件名
- listener {Function} 事件处理函数

在移除 listener 时会发生该事件。 此时无法确定 listener 是否在 emitter.listeners(event) 返回的列表中。
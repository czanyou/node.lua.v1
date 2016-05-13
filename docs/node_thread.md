# 线程

Node.lua 支持多线程, 但是各个线程是属于不同的虚拟机, 变量不能相互访问, 但可以通过消息等相互通信.

## thead.start(thread_func, ...)

## thead.join(thread)

## thead.equals(thread1, thread2)

## thead.self

## thead.sleep

## thead.work(thread_func, notify_entry)

## thead.queue(worker, ...)

## 类 thead.Worker



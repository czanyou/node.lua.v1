LUV_TAG=$(shell git describe --tags)
LUABIN=build/local/lnode

.PHONY: clean all local build hi3518 hi3516c install uninstall test

all: local

help:
	@echo "local:     Build local release"
	@echo "hi3518:    Build hi3518 release"
	@echo "hi3516c:   Build hi3516c release"
	@echo "clean:     Clean all build files "	
	@echo "test: "	
	@echo "install:   Install lnode, node.lua and vision.lua "
	@echo "uninstall: Uninstall"		

local:
	cmake -H. -Bbuild/local
	cmake --build build/local --config Release

hi3518:
#   交叉编译
	cmake -H. -Bbuild/hi3518 -DBOARD_TYPE=hi3518
	cmake --build build/hi3518 --config Release

hi3516c:
#   交叉编译
	cmake -H. -Bbuild/hi3516c -DBOARD_TYPE=hi3516c
	cmake --build build/hi3516c --config Release

clean:
	rm -rf build bin/cache
	${LUABIN} tests/clean.lua

test:
	${LUABIN} tests/fs/run.lua
	${LUABIN} tests/http/run.lua
	${LUABIN} tests/uv/run.lua


install:
#   安装文件到当前系统
	sudo mkdir -p /usr/local/bin

	cp build/local/lnode bin/lnode
	sudo cp build/local/lnode /usr/local/bin
	sudo cp bin/lpm /usr/local/bin

	sudo chmod 777 /usr/local/bin/lnode
	sudo chmod 777 /usr/local/bin/lpm

	sudo lnode install.lua

uninstall:
#   从当前系统删除安装的文件
	sudo rm -rf /usr/local/bin/lnode
	sudo rm -rf /usr/local/bin/lpm
	sudo rm -rf /system/lib/lua/5.3
	sudo rm -rf /system/app/lua/5.3

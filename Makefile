LUV_TAG			?= $(shell git describe --tags)
LUABIN			?= build/local/lnode
PWD 			= $(shell pwd)

NODE_ROOTPATH   ?= /usr/local/lnode
LOCAL_BIN_PATH  ?= /usr/local/bin
NODE_BUILD 		?= ${PWD}/build/local

define cmake_build
	cmake -H. -Bbuild/$1 -DBOARD_TYPE=$1
	cmake --build build/$1 --config Release
endef

define make_link
	@sudo rm -rf $2
	@if [ -e $1 ]; then echo make link: $2; sudo ln -s $1 $2; fi;
endef

define make_bin_link
	$(call make_link,${NODE_BUILD}/$1.so,${NODE_ROOTPATH}/bin/$1.so)
endef

## ------------------------------------------------------------

.PHONY: clean all build install uninstall test local xcode hi3518 hi3516a mt7688

all: help

help:
	@echo ""
	@echo "node.lua is the core of the Node.lua."
	@echo ""
	@echo "Please select a make target:"
	@echo ""
	@echo "hi3516a    build for hi3516a"
	@echo "hi3518     build for hi3518"
	@echo "mt7688     build for mt7688"
	@echo "local      build for current system"
	@echo "xcode      generate a XCode project"
	@echo ""
	@echo "clean      clean all temporary build files"
	@echo "install    install files into ${NODE_ROOTPATH}"
	@echo "uninstall  remove all installed files"
	@echo ""


## ------------------------------------------------------------


hi3516a:
	$(call cmake_build,$@)

hi3518:
	$(call cmake_build,$@)

mt7688:
	$(call cmake_build,$@)

local:
	$(call cmake_build,$@)

build: local

xcode:
	cmake -H. -G Xcode -Bbuild/$@ -DBOARD_TYPE=$@


## ------------------------------------------------------------

clean:
	rm -rf build

test:
	${LUABIN} tests/fs/run.lua
	${LUABIN} tests/http/run.lua
	${LUABIN} tests/uv/run.lua

install: uninstall
	@echo 'Install the files into ${NODE_ROOTPATH}'

	@sudo mkdir -p ${LOCAL_BIN_PATH}
	sudo mkdir -p ${NODE_ROOTPATH}/bin
	sudo mkdir -p ${NODE_ROOTPATH}/conf	

	@sudo chmod 777 ${NODE_ROOTPATH}/conf

	@echo "make link: ${NODE_ROOTPATH}/lua"
	@sudo ln -s ${PWD}/lua ${NODE_ROOTPATH}/lua

	$(call make_link,${PWD}/build/local/lnode,${LOCAL_BIN_PATH}/lnode)
	$(call make_link,${PWD}/bin/lpm,${LOCAL_BIN_PATH}/lpm)

	$(call make_bin_link,lsqlite)
	$(call make_bin_link,lmbedtls)

	@sudo chmod 777 ${LOCAL_BIN_PATH}/*

	@echo 'Installing done.'
	@echo ''

uninstall:
	@echo 'Remove all installed files'
	sudo rm -rf ${LOCAL_BIN_PATH}/lnode
	sudo rm -rf ${LOCAL_BIN_PATH}/lpm
	sudo rm -rf ${NODE_ROOTPATH}/lua
	@echo 'Removing done.'
	@echo ''	
cmake_minimum_required(VERSION 2.8)

# Project Name
project (Node.lua C)

# Project Version Code
set(NODELUA_VERSION_MAJOR 0)
set(NODELUA_VERSION_MINOR 8)
set(NODELUA_VERSION_PATCH 15)

set(NODELUA_VERSION       ${NODELUA_VERSION_MAJOR}.${NODELUA_VERSION_MINOR}.${NODELUA_VERSION_PATCH})
add_definitions(-DNODELUA_VERSION_MAJOR=${NODELUA_VERSION_MAJOR})
add_definitions(-DNODELUA_VERSION_MINOR=${NODELUA_VERSION_MINOR})
add_definitions(-DNODELUA_VERSION_PATCH=${NODELUA_VERSION_PATCH})

message(STATUS "Build: NODELUA_VERSION=${NODELUA_VERSION}  ")

###############################################################################
# Build Options

set(CMAKE_MACOSX_RPATH 0)

# Development board type
if (NOT BOARD_TYPE)
  set(BOARD_TYPE local)
endif ()

# Build lnode execute
option(BUILD_MBED_TLS   "Build with MbedTLS" OFF)
option(BUILD_SQLITE     "Build with sqlite" OFF)

set(BUILD_LNODE_EXE     ON)
set(BUILD_SQLITE        ON)
set(WITH_SHARED_LUA     OFF)

# Linux
if ("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  set(LINUX ON)
endif ()

# Lua module build type (Shared|Static)
if (WIN32)
  set(WITH_SHARED_LUA ON)
endif ()

###############################################################################
# Cross compiler options
# determine the parameters of the compiler tool chain through BOARD_TYPE

# Meida.lua path
string(REPLACE "node.lua" "media.lua" "MEDIA_LUA_PATH" "${CMAKE_CURRENT_SOURCE_DIR}")

if (BOARD_TYPE STREQUAL hi3518)
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")

elseif (BOARD_TYPE STREQUAL hi3516a)
  # Must install 32bit c++ lib on 64bit linux:
  # sudo apt-get install lib32stdc++6 lib32z1 -y
  set(CMAKE_C_COMPILER "arm-hisiv300-linux-gcc")

elseif (BOARD_TYPE STREQUAL mt7688)
  set(CMAKE_C_COMPILER "mipsel-openwrt-linux-gcc")

elseif (BOARD_TYPE STREQUAL xcode)
  set(WITH_SHARED_LUA OFF)
  set(BUILD_LNODE_EXE OFF)
  message(STATUS "Build: xcode")
endif ()

###############################################################################

message(STATUS "Build: BOARD_TYPE=${BOARD_TYPE}")
message(STATUS "Build: WITH_SHARED_LUA=${WITH_SHARED_LUA}")
message(STATUS "Build: BUILD_LNODE_EXE=${BUILD_LNODE_EXE} ")
message(STATUS "Build: BUILD_MBED_TLS=${BUILD_MBED_TLS} ")
message(STATUS "Build: BUILD_SQLITE=${BUILD_SQLITE} ")
message(STATUS "Build: CC=${CMAKE_C_COMPILER}")

# Include directories
include_directories(deps/lua/src)

###############################################################################
# OS build options

if (WIN32)
  set(BUILD_MBED_TLS      ON)

  add_definitions("/wd4005" "/wd4244" "/wd4819" "/wd4996")

  # see `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_BUILD_AS_DLL -DLUA_LIB)

  #add_definitions(-DLUA_USE_NODE=1)
  add_definitions(-DNODE_LUA_ROOT="!")

  # replace /MD to /MT to avoid link msvcr*.dll
  set(CompilerFlags
    CMAKE_C_FLAGS
    CMAKE_C_FLAGS_DEBUG
    CMAKE_C_FLAGS_MINSIZEREL
    CMAKE_C_FLAGS_RELWITHDEBINFO
    CMAKE_C_FLAGS_RELEASE)
  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
  endforeach()

elseif (APPLE)
  # see `deps/lua/src/luaconf.h`
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)
  add_definitions(-DLUA_USE_LMEDIA -DLUA_USE_LSQLITE)

  set(BUILD_SQLITE ON)

  link_directories(${MEDIA_LUA_PATH}/build/local/)

  set(CMAKE_SHARED_MODULE_CREATE_C_FLAGS
    "${CMAKE_SHARED_MODULE_CREATE_C_FLAGS} -bundle -flat_namespace -undefined suppress"
  )

elseif (LINUX)

  # Add share object flags
  # Under 64bit Linux, you must add -fPIC option to compile a dynamic link library
  add_definitions("-fPIC")

  # Retain function names, etc., to facilitate dlopen or debugging
  add_definitions("-rdynamic")

  # see `deps/lua/src/luaconf.h`
  add_definitions(-DLUA_USE_POSIX -DLUA_USE_DLOPEN)  
  add_definitions(-DNODE_LUA_ROOT="/usr/local/lnode")

endif ()

###############################################################################
# Include submodules

include(deps/libuv.cmake)
include(deps/lua.cmake)
include(deps/luajson.cmake)
include(deps/luautils.cmake)
include(deps/luauv.cmake)
include(deps/luazip.cmake)

if (BUILD_SQLITE)
    include(libs/lsqlite.cmake)
endif ()

if (BUILD_MBED_TLS)
    include(libs/lmbedtls.cmake)
endif ()

###############################################################################
# lnode execute 

if (BUILD_LNODE_EXE) 
  add_executable(lnode src/main.c src/lnode.c)

  target_link_libraries(lualib luazip luajson luautils luauv uv)
  target_link_libraries(lnode lualib)

  if (APPLE)
    target_link_libraries(lnode lmedia lsqlite sml faad)

  elseif (LINUX)
    target_link_libraries(lnode dl m rt)

  endif ()
endif ()

###############################################################################
# Install:

file (WRITE build/version ${NODELUA_VERSION})

message(STATUS "Build: Init done")

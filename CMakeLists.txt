cmake_minimum_required(VERSION 2.8)

# LUV Project Name 项目名称
project (Node.lua C ASM)

# LUV Version Code 版本号
set(LUV_VERSION_MAJOR 1)
set(LUV_VERSION_MINOR 7)
set(LUV_VERSION_PATCH 1)
set(LUV_VERSION       ${LUV_VERSION_MAJOR}.${LUV_VERSION_MINOR}.${LUV_VERSION_PATCH})

###############################################################################
# Build Options

option(BUILD_MODULE      "Build as module"      ON)
option(BOARD_TYPE        "Board type"           local)
option(BUILD_SHARED_LIBS "Build shared library" OFF)
option(LUA_BUILD_TYPE    "Build type"           Static)
option(WITH_LUA_ENGINE   "Lua Engine type"      Lua)

###############################################################################
# Build Options

# LuaJIT/Lua Build
if (NOT WITH_LUA_ENGINE)
  set(WITH_LUA_ENGINE "Lua"
    CACHE STRING "Link to LuaJIT or PUC Lua" FORCE)
  set_property(CACHE WITH_LUA_ENGINE
    PROPERTY STRINGS  "Lua;LuaJIT")
endif ()

# lib build type
if (NOT BUILD_SHARED_LIBS)
  set(BUILD_SHARED_LIBS OFF)
endif ()

# BOARD_TYPE
if (NOT BOARD_TYPE)
  set(BOARD_TYPE local)
endif ()

# Lua build mode
if (NOT LUA_BUILD_TYPE)
  set(LUA_BUILD_TYPE "Static"
    CACHE STRING "Build Lua/LuaJIT as static, dynamic libary, or use system one" FORCE)
  set_property(CACHE LUA_BUILD_TYPE PROPERTY STRINGS  "Static;Dynamic;System")
endif ()

###############################################################################
# 交叉编译选项, 通过 BOARD_TYPE 参数确定编译工具链

MESSAGE(STATUS "Build: BOARD_TYPE=${BOARD_TYPE}  ")
if (BOARD_TYPE STREQUAL hi3518)
  MESSAGE(STATUS "Build: Use arm-hisiv100nptl-linux-gcc")
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")
  set(BUILD_SHARED_LIBS ON)

elseif (BOARD_TYPE STREQUAL hi3516c)
  MESSAGE(STATUS "Build: Use arm-hisiv100nptl-linux-gcc")
  set(CMAKE_C_COMPILER "arm-hisiv100nptl-linux-gcc")
  set(BUILD_SHARED_LIBS ON)

else ()
  MESSAGE(STATUS "Build: Use local gcc")
  if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
    set(BUILD_SHARED_LIBS ON)
  endif ()

endif ()

###############################################################################
# Lua 

# WITH_SHARED_LUA ON/OFF
if (LUA_BUILD_TYPE STREQUAL Static)
  set(WITH_SHARED_LUA OFF)
else ()
  set(WITH_SHARED_LUA ON)
endif ()

if (WIN32)
  set(WITH_SHARED_LUA ON)
else ()
  add_definitions(-DLUA_USE_POSIX)  
  add_definitions(-DLUA_USE_DLOPEN)
endif ()

###############################################################################
# 子模块

include(deps/libuv.cmake)
include(deps/luauv.cmake)
include(deps/luajson.cmake)
include(deps/luazip.cmake)
include(deps/luautils.cmake)
include(deps/lua.cmake)

# include directories
include_directories(deps/lua/src)

# link directories
link_directories(${CMAKE_CURRENT_SOURCE_DIR}/build)

###############################################################################
# 编译单独的执行文件, 只需单个文件就可以运行

# lnode
add_executable(lnode src/main.c src/lnode.c)
target_link_libraries(lnode luazip luajson luautils luauv lualib)


###############################################################################
# 编译相关的动态链接库和主执行文件, 方便某些平台动态库依赖比较复杂的情况下使用
# 主要功能全都封装在 luanode.so 文件中, 主执行文件只是个外壳

# lshell & luanode.so
if (BUILD_SHARED_LIBS)
  MESSAGE(STATUS "Build: BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}  ")

  add_library(luanode SHARED src/lnode.c)
  target_link_libraries(luanode luazip luajson luautils luauv lualib)

  add_executable(lshell src/main.c)
  target_link_libraries(lshell luanode)
endif()

###############################################################################
# APPLE

if(APPLE)
  set(CMAKE_SHARED_MODULE_CREATE_C_FLAGS
    "${CMAKE_SHARED_MODULE_CREATE_C_FLAGS} -flat_namespace -undefined suppress"
  )
endif()

###############################################################################
# luauv

if (WIN32)
  add_definitions(-DLUA_BUILD_AS_DLL -DLUA_LIB)
  target_link_libraries(luauv uv)

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
  
elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  target_link_libraries(luauv uv rt)

else()
  target_link_libraries(luauv uv)

endif()


MESSAGE(STATUS "Build: Init Done")

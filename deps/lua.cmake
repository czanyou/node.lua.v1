# Modfied from luajit.cmake
# Added LUAJIT_ADD_EXECUTABLE Ryan Phillips <ryan at trolocsis.com>
# This CMakeLists.txt has been first taken from LuaDist
# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# Debugged and (now seriously) modified by Ronan Collobert, for Torch7

#project(Lua53 C)

set(LUA_DIR ${CMAKE_CURRENT_LIST_DIR}/lua)

set(CMAKE_REQUIRED_INCLUDES
  ${LUA_DIR}
  ${LUA_DIR}/src
  ${CMAKE_CURRENT_BINARY_DIR}
)

# Ugly warnings
if(MSVC)
  add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif()

# Various includes
include(CheckLibraryExists)
include(CheckFunctionExists)
include(CheckCSourceCompiles)
include(CheckTypeSize)

CHECK_TYPE_SIZE("void*" SIZEOF_VOID_P)
if(SIZEOF_VOID_P EQUAL 8)
  add_definitions(-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE)
endif()

# libs
if(NOT WIN32)
  FIND_LIBRARY(DL_LIBRARY "dl")
  if(DL_LIBRARY)
    set(CMAKE_REQUIRED_LIBRARIES ${DL_LIBRARY})
    list(APPEND LIBS ${DL_LIBRARY})
  endif(DL_LIBRARY)
  CHECK_FUNCTION_EXISTS(dlopen LUA_USE_DLOPEN)
  if(NOT LUA_USE_DLOPEN)
    MESSAGE(FATAL_ERROR "Cannot compile a useful lua.
Function dlopen() seems not to be supported on your platform.
Apparently you are not on a Windows platform as well.
So lua has no way to deal with shared libraries!")
  endif(NOT LUA_USE_DLOPEN)
endif(NOT WIN32)

check_library_exists(m sin "" LUA_USE_LIBM)
if ( LUA_USE_LIBM )
  list ( APPEND LIBS m )
endif ()

## SOURCES
set(SRC_LUALIB
  ${LUA_DIR}/src/lbaselib.c
  ${LUA_DIR}/src/lcorolib.c
  ${LUA_DIR}/src/ldblib.c
  ${LUA_DIR}/src/liolib.c
  ${LUA_DIR}/src/lmathlib.c
  ${LUA_DIR}/src/loadlib.c
  ${LUA_DIR}/src/loslib.c
  ${LUA_DIR}/src/lstrlib.c
  ${LUA_DIR}/src/ltablib.c
  ${LUA_DIR}/src/lutf8lib.c)

set(SRC_LUACORE
  ${LUA_DIR}/src/lauxlib.c
  ${LUA_DIR}/src/lapi.c
  ${LUA_DIR}/src/lcode.c
  ${LUA_DIR}/src/lctype.c
  ${LUA_DIR}/src/ldebug.c
  ${LUA_DIR}/src/ldo.c
  ${LUA_DIR}/src/ldump.c
  ${LUA_DIR}/src/lfunc.c
  ${LUA_DIR}/src/lgc.c
  ${LUA_DIR}/src/linit.c
  ${LUA_DIR}/src/llex.c
  ${LUA_DIR}/src/lmem.c
  ${LUA_DIR}/src/lobject.c
  ${LUA_DIR}/src/lopcodes.c
  ${LUA_DIR}/src/lparser.c
  ${LUA_DIR}/src/lstate.c
  ${LUA_DIR}/src/lstring.c
  ${LUA_DIR}/src/ltable.c
  ${LUA_DIR}/src/ltm.c
  ${LUA_DIR}/src/lundump.c
  ${LUA_DIR}/src/lvm.c
  ${LUA_DIR}/src/lzio.c
  ${SRC_LUALIB})

## GENERATE

#MESSAGE(STATUS "Lua: WITH_AMALG=${WITH_AMALG}  ")
#MESSAGE(STATUS "Lua: SRC_LUACORE=${SRC_LUACORE}  ")
#MESSAGE(STATUS "Lua: DEPS=${DEPS}  ")

# liblua 运行库/静态库
if (WITH_SHARED_LUA)
  add_library(lualib SHARED ${SRC_LUACORE} ${DEPS} )

else ()
  add_library(lualib STATIC ${SRC_LUACORE} ${DEPS} )
  set_target_properties(lualib PROPERTIES PREFIX "lib" IMPORT_PREFIX "lib")
endif ()

# 生成 liblua53.a 静态库
target_link_libraries (lualib ${LIBS} )
set_target_properties (lualib PROPERTIES OUTPUT_NAME "lua53")

# lua 可执行文件
if (WITH_LUA_EXECUTE)
  if (WIN32)
    add_executable(lua ${LUA_DIR}/src/lua.c)
    target_link_libraries(lua lualib)
 
  else ()
    add_executable(lua ${LUA_DIR}/src/lua.c ${SRC_LUACORE} ${DEPS})
    target_link_libraries(lua ${LIBS})
    SET_TARGET_PROPERTIES(lua PROPERTIES ENABLE_EXPORTS ON)
  endif (WIN32)
endif ()

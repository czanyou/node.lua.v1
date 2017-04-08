cmake_minimum_required(VERSION 2.8)

# Source Code Updated: 2016/9/23
# https://github.com/mpx/lua-cjson

set(LUAJSONDIR ${CMAKE_CURRENT_LIST_DIR}/luajson)

include_directories(
  ${LUAJSONDIR}
)

set(SOURCES
  ${LUAJSONDIR}/lua_cjson.c
  ${LUAJSONDIR}/fpconv.c
  ${LUAJSONDIR}/strbuf.c
)

add_library(luajson STATIC ${SOURCES})


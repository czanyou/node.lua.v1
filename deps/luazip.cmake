cmake_minimum_required(VERSION 2.8)

# 
# https://github.com/richgel999/miniz

set(LUAZIPDIR ${CMAKE_CURRENT_LIST_DIR}/luazip)

include_directories(
  ${LUAZIPDIR}
)

set(SOURCES
  ${LUAZIPDIR}/lminiz.c
)

add_library(luazip STATIC ${SOURCES})

cmake_minimum_required(VERSION 2.8)

include(CheckTypeSize)

# Source Code Updated: 1.9.1
# https://github.com/luvit/luv

set(LUAUVDIR ${CMAKE_CURRENT_LIST_DIR}/luauv)

include_directories(
  ${LUAUVDIR}/include
  ${LUAUVDIR}
)

set(SOURCES
  ${LUAUVDIR}/luv.c
)

check_type_size("void*" SIZEOF_VOID_P)
if (SIZEOF_VOID_P EQUAL 8)
  add_definitions(-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE)
endif()

add_library(luauv STATIC ${SOURCES})
set_property(TARGET luauv PROPERTY VERSION ${NODELUA_VERSION} SOVERSION ${NODELUA_VERSION_MAJOR})


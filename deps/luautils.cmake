cmake_minimum_required(VERSION 2.8)

include(CheckTypeSize)

set(LUAUTILSDIR ${CMAKE_CURRENT_LIST_DIR}/luautils)

include_directories(
  ${LUAUTILSDIR}
)

set(SOURCES
  ${LUAUTILSDIR}/base64.c
  ${LUAUTILSDIR}/hex.c
  ${LUAUTILSDIR}/http_parser.c
  ${LUAUTILSDIR}/http_parser_lua.c
  ${LUAUTILSDIR}/lenv.c
  ${LUAUTILSDIR}/md5.c
  ${LUAUTILSDIR}/lutils.c
  ${LUAUTILSDIR}/message_lua.c

)

check_type_size("void*" SIZEOF_VOID_P)
if (SIZEOF_VOID_P EQUAL 8)
  add_definitions(-D_OS_BITS=64)
endif()

add_library(luautils STATIC ${SOURCES})

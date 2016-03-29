## Modifications
## Copyright 2014 The Luvit Authors. All Rights Reserved.

## Original Copyright
# Copyright (c) 2014 David Capello
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

include(CheckTypeSize)

cmake_minimum_required(VERSION 2.8.9)

set(LUAUTILSDIR ${CMAKE_CURRENT_LIST_DIR}/luautils)

include_directories(
  ${CMAKE_CURRENT_LIST_DIR}/libuv/include
  ${LUAUTILSDIR}
)

set(SOURCES
  ${LUAUTILSDIR}/base64.c	
  ${LUAUTILSDIR}/hex.c		
  ${LUAUTILSDIR}/lenv.c		
  ${LUAUTILSDIR}/md5.c	
  ${LUAUTILSDIR}/lutils.c
)

check_type_size("void*" SIZEOF_VOID_P)
if (SIZEOF_VOID_P EQUAL 8)
  add_definitions(-D_OS_BITS=64)
endif()

add_library(luautils STATIC ${SOURCES})

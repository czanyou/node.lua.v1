/*
 *  Copyright 2014 The Luvit Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
#include "lutils.h"
#include "buffer.c"
//#include "message.c"
#include "os.c"
#include "md5.h"

/**
 *  Hash function. Returns a hash for a given string.
 *  @param message: arbitrary binary string.
 *  @return  A 128-bit hash string.
 */
static int luv_md5(lua_State *L) {
  char buff[16];
  size_t l;
  const char *message = luaL_checklstring(L, 1, &l);
  md5(message, l, buff);
  lua_pushlstring(L, buff, 16L);
  return 1;
}

static int luv_base64_encode(lua_State *L) {
  char* buffer = NULL;
  int bufferSize = 0;
  size_t dataSize = 0;
  const char *data = luaL_checklstring(L, 1, &dataSize);

  int ret = 0;

  size_t output = 0;
  if (data && dataSize > 0) {
    bufferSize = dataSize * 2;
    buffer = malloc(bufferSize);

    int status = lutils_base64_encode(buffer, bufferSize, &output, data, dataSize);
    if (status != 0) {
      lua_pushnil(L);
      lua_pushinteger(L, status);
      ret = 2;

    } else {
      lua_pushlstring(L, buffer, output);
      ret = 1;
    }

    free(buffer);
    buffer = NULL;
  }

  return ret;
}

static int luv_base64_decode(lua_State *L) {
  char* buffer = NULL;
  int bufferSize = 0;
  size_t dataSize = 0;
  const char *data = luaL_checklstring(L, 1, &dataSize);

  int ret = 0;

  size_t output = 0;
  if (data && dataSize > 0) {
    bufferSize = dataSize * 2;
    buffer = malloc(bufferSize);

    int status = lutils_base64_decode(buffer, bufferSize, &output, data, dataSize);
    if (status != 0) {
      lua_pushnil(L);
      lua_pushinteger(L, status);
      ret = 2;

    } else {
      lua_pushlstring(L, buffer, output);
      ret = 1;
    }

    free(buffer);
    buffer = NULL;
  }

  return ret;
}

static int luv_hex16_decode(lua_State *L) {
  char* buffer = NULL;
  int bufferSize = 0;
  size_t dataSize = 0;
  const char *data = luaL_checklstring(L, 1, &dataSize);

  int ret = 0;

  if (data && dataSize > 0) {
    bufferSize = dataSize;
    buffer = malloc(bufferSize);

    int status = lutils_hex16_decode(buffer, bufferSize, data, dataSize);
    if (status < 0) {
      lua_pushnil(L);
      lua_pushinteger(L, status);
      ret = 2;

    } else {
      lua_pushlstring(L, buffer, status);
      ret = 1;
    }

    free(buffer);
    buffer = NULL;
  }

  return ret;
}

static int luv_hex16_encode(lua_State *L) {
  char* buffer = NULL;
  int bufferSize = 0;
  size_t dataSize = 0;
  const char *data = luaL_checklstring(L, 1, &dataSize);

  int ret = 0;

  if (data && dataSize > 0) {
    bufferSize = dataSize * 2 + 4;
    buffer = malloc(bufferSize);

    int status = lutils_hex16_encode(buffer, bufferSize, data, dataSize);
    if (status < 0) {
      lua_pushnil(L);
      lua_pushinteger(L, status);
      ret = 2;

    } else {
      lua_pushlstring(L, buffer, status);
      ret = 1;
    }

    free(buffer);
    buffer = NULL;
  }

  return ret;
}


static const luaL_Reg lutils_functions[] = {
 
  // buffer.c
  {"new_buffer",        luv_buffer_new },

  // message.c
  //{ "new_message_queue", luv_queue_channel_new },
  //{ "get_message_queue", luv_queue_channel_get },

  // os.c
  { "os_arch",          luv_os_arch },
  { "os_platform",      luv_os_platform },

  { "md5",              luv_md5 },
  { "base64_encode",    luv_base64_encode },
  { "base64_decode",    luv_base64_decode },
  { "hex_encode",       luv_hex16_encode },
  { "hex_decode",       luv_hex16_decode },   

  {NULL, NULL}
};

LUALIB_API int luaopen_lutils(lua_State *L) {

  luaL_newlib(L, lutils_functions);

  luv_buffer_init(L);
  //luv_queue_init(L);

  return 1;
}

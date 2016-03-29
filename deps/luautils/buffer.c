/*
 *  Copyright 2015 The Lnode Authors. All Rights Reserved.
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

#include "buffer.h"

static int luv_buffer_new(lua_State* L)
{
	size_t size = luaL_optinteger(L, 1, 128 * 1024);

	luv_ppp_buffer_t* buffer = NULL;
	buffer = lua_newuserdata(L, sizeof(*buffer));
	luaL_getmetatable(L, "uv_buffer");
	lua_setmetatable(L, -2);

	buffer->type 	 = LUV_BUFFER;
	buffer->data 	 = NULL;
	buffer->size 	 = 0;
	buffer->position = 1;
	buffer->limit 	 = 1;

	if (size > 0) {
		buffer->data = malloc(size);
		buffer->size = size;
	}

	return 1;
}

static luv_ppp_buffer_t* luv_buffer_check_buffer(lua_State* L, int index)
{
	luv_ppp_buffer_t* buffer = luaL_checkudata(L, index, "uv_buffer");
	return buffer;
}

static int luv_buffer_close(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer && buffer->data) {
		free(buffer->data);

		//printf("ppp_buffer_free: %d\r\n", buffer->size);

		buffer->data 	 = NULL;
		buffer->size 	 = 0;
		buffer->position = 1;
		buffer->limit 	 = 1;
		ret = 1;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_fill(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	while (buffer && buffer->data) {
		int data 	= luaL_checkinteger(L, 2);
		int offset 	= luaL_checkinteger(L, 3);
		int size 	= luaL_checkinteger(L, 4);

		int buffer_size = buffer->size;
		if (buffer_size <= 0) {
			ret = -1;
			break;

		} else if (size <= 0) {
			ret = -2;
			break;

		} else if (offset <= 0 || offset + size > buffer_size + 1) {
			ret = -3;
			break;
		}

		memset(buffer->data + offset - 1, data, size);
		ret = size;
		break;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_copy(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);

	do {
		if (buffer == NULL || buffer->data == NULL) {
			break;
		}

		luv_ppp_buffer_t* other = luv_buffer_check_buffer(L, 3);
		if (other == NULL || other->data == NULL) {
			break;
		}

		int offset = luaL_checkinteger(L, 2);
		int source = luaL_checkinteger(L, 4);
		int count  = luaL_checkinteger(L, 5);

		int buffer_size = buffer->size;
		int other_size  = other->size;

		if (offset <= 0 || offset > buffer_size) {
			break;

		} else if (source <= 0 || source > other_size) {
			break;

		} else if (count <= 0) {
			break;

		} else if (offset + count > buffer_size + 1) {
			break;

		} else if (source + count > other_size + 1) {
			break;			
		}		

		char* dest_buffer = buffer->data + offset - 1;
		char* src_buffer  = other->data  + source - 1;
		memcpy(dest_buffer, src_buffer, count);
		ret = 1;

	} while (0);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_get_byte(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer && buffer->data) {
		int offset = luaL_checkinteger(L, 2);

		if (offset > 0 && offset <= buffer->size) {
			char* data = buffer->data + offset - 1;
			ret = (unsigned char)(*data);
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}
static int luv_buffer_get_bytes(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer && buffer->data) {
		int offset = luaL_checkinteger(L, 2);
		int size   = luaL_checkinteger(L, 3);

		if (offset > 0 && size > 0 && offset + size <= buffer->size + 1) {
			lua_pushlstring(L, buffer->data + offset - 1, size);
			return 1;
		}
	}

	lua_pushnil(L);
	return 1;
}

static int luv_buffer_limit(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 1)) {
			int limit = luaL_checkinteger(L, 1);
			if (limit > 0 && limit <= buffer->size) {
				buffer->limit = limit;
			}
		}

		ret = buffer->limit;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_move(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	do {
		if (buffer == NULL ||  buffer->data == NULL) {
			break;
		}

		int offset = luaL_checkinteger(L, 2);
		int source = luaL_checkinteger(L, 3);
		int count  = luaL_checkinteger(L, 4);

		int buffer_size = buffer->size;
		if (offset <= 0 || offset > buffer_size) {
			break;

		} else if (source <= 0 || source > buffer_size) {
			break;

		} else if (count <= 0) {
			break;

		} else if (offset + count > buffer_size + 1) {
			break;

		} else if (source + count > buffer_size + 1) {
			break;			
		}

		char* dest_buffer = buffer->data + offset - 1;
		char* src_buffer  = buffer->data + source - 1;

		memmove(dest_buffer, src_buffer, count);
		ret = 1;

	} while (0);

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_position(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer) {
		if (lua_isnumber(L, 1)) {
			int position = luaL_checkinteger(L, 1);
			if (position > 0 && position <= buffer->size) {
				buffer->position = position;
			}
		}

		ret = buffer->position;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_put_byte(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer && buffer->data) {
		int offset = luaL_checkinteger(L, 2);
		int value  = luaL_checkinteger(L, 3);

		if (offset > 0 && offset <= buffer->size) {
			char* data = buffer->data + offset - 1;
			*data = (unsigned char)value;
			ret = 1;
		}
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_put_bytes(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	while (buffer && buffer->data) {
		size_t data_size = 0;
		int position = luaL_checkinteger(L, 2);
		char* data = (char*)luaL_checklstring(L, 3, &data_size);
		int offset = luaL_checkinteger(L, 4);
		int size = luaL_checkinteger(L, 5);

		int buffer_size = buffer->size;
		if (buffer_size <= 0) {
			ret = -1;
			break;

		} else if (size <= 0) {
			ret = -2;
			break;

		} else if (position <= 0 || position + size > buffer_size + 1) {
			ret = -3;
			break;

		} else if (data_size <= 0) {
			ret = -4;
			break;

		} else if (offset <= 0 || offset + size > data_size + 1) {
			ret = -5;
			break;
		}

		memcpy(buffer->data + position - 1, data + offset - 1, size);
		ret = size;

		break;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_size(lua_State* L)
{
	int ret = 0;
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer) {
		ret = buffer->size;
	}

	lua_pushinteger(L, ret);
	return 1;
}

static int luv_buffer_to_string(lua_State* L)
{
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
	if (buffer && buffer->data) {
		lua_pushlstring(L, buffer->data, buffer->size);
		return 1;
	}

	lua_pushnil(L);
	return 1;
}

static int luv_buffer_tostring(lua_State* L) {
	luv_ppp_buffer_t* buffer = luv_buffer_check_buffer(L, 1);
    lua_pushfstring(L, "uv_buffer_t: %p", buffer);
  	return 1;
}

static const luaL_Reg luv_buffer_functions[] = {
	{ "close",			luv_buffer_close },
	{ "copy",			luv_buffer_copy },
	{ "xcopy",			luv_buffer_copy },	
	{ "fill",			luv_buffer_fill },
	{ "get_byte",		luv_buffer_get_byte },
	{ "get_bytes",		luv_buffer_get_bytes },
	{ "limit",			luv_buffer_limit },	
	{ "move",			luv_buffer_move },
	{ "position",		luv_buffer_position },
	{ "put_byte",		luv_buffer_put_byte },
	{ "put_bytes",		luv_buffer_put_bytes },
	{ "size",			luv_buffer_size },
	{ "to_string",		luv_buffer_to_string },
	{ NULL, NULL }
};

static void luv_buffer_init(lua_State* L) {
	// buffer
	luaL_newmetatable(L, "uv_buffer");

	luaL_newlib(L, luv_buffer_functions);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, luv_buffer_close);
	lua_setfield(L, -2, "__gc");

	lua_pushcfunction(L, luv_buffer_tostring);
	lua_setfield(L, -2, "__tostring");	

	lua_pop(L, 1);
}


/*
 *  Copyright 2012 The Luvit Authors. All Rights Reserved.
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
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <string.h>
#include <stdlib.h>

#include "http_parser.h"

static const char* method_to_str(unsigned short m) {
  switch (m) {
    case HTTP_DELETE:     return "DELETE";
    case HTTP_GET:        return "GET";
    case HTTP_HEAD:       return "HEAD";
    case HTTP_POST:       return "POST";
    case HTTP_PUT:        return "PUT";
    case HTTP_CONNECT:    return "CONNECT";
    case HTTP_OPTIONS:    return "OPTIONS";
    case HTTP_TRACE:      return "TRACE";
    case HTTP_COPY:       return "COPY";
    case HTTP_LOCK:       return "LOCK";
    case HTTP_MKCOL:      return "MKCOL";
    case HTTP_MOVE:       return "MOVE";
    case HTTP_PROPFIND:   return "PROPFIND";
    case HTTP_PROPPATCH:  return "PROPPATCH";
    case HTTP_UNLOCK:     return "UNLOCK";
    case HTTP_REPORT:     return "REPORT";
    case HTTP_MKACTIVITY: return "MKACTIVITY";
    case HTTP_CHECKOUT:   return "CHECKOUT";
    case HTTP_MERGE:      return "MERGE";
    case HTTP_MSEARCH:    return "MSEARCH";
    case HTTP_NOTIFY:     return "NOTIFY";
    case HTTP_SUBSCRIBE:  return "SUBSCRIBE";
    case HTTP_UNSUBSCRIBE:return "UNSUBSCRIBE";
    default:              return "UNKNOWN_METHOD";
  }
}

/*****************************************************************************/

static struct http_parser_settings lhttp_parser_settings;

static int lhttp_parser_event(http_parser *p, const char* event, const char *at, size_t length) {
  lua_State *L = p->data;

  /* Put the environment of the userdata on the top of the stack */
  lua_getuservalue(L, 1);

  /* Get the  callback and put it on the stack */
  lua_getfield(L, -1, event);

  /* See if it's a function */
  if (lua_isfunction (L, -1) == 0) {
    lua_pop(L, 2);
    return 0;
  };

  if (at) {
    /* Push the string argument */
    lua_pushlstring(L, at, length);
    lua_call(L, 1, 1);

  } else {
    lua_call(L, 0, 1);
  }

  lua_pop(L, 2); /* pop returned value and the userdata env */
  return 0;
}

static int lhttp_parser_on_message_begin(http_parser *p) {
  return lhttp_parser_event(p, "message_begin", NULL, 0);
}

static int lhttp_parser_on_message_complete(http_parser *p) {
  return lhttp_parser_event(p, "message_complete", NULL, 0);
}

static int lhttp_parser_on_url(http_parser *p, const char *at, size_t length) {
  return lhttp_parser_event(p, "url", at, length);
}

static int lhttp_parser_on_header_field(http_parser *p, const char *at, size_t length) {
  return lhttp_parser_event(p, "header_field", at, length);
}

static int lhttp_parser_on_header_value(http_parser *p, const char *at, size_t length) {
  return lhttp_parser_event(p, "header_value", at, length); 
}

static int lhttp_parser_on_body(http_parser *p, const char *at, size_t length) {
  return lhttp_parser_event(p, "body", at, length); 
}

static int lhttp_parser_on_headers_complete(http_parser *p) {
  lua_State *L = p->data;

  /* Put the environment of the userdata on the top of the stack */
  lua_getuservalue(L, 1);

  /* Get the onHeadersComplete callback and put it on the stack */
  lua_getfield(L, -1, "headers_complete");

  /* See if it's a function */
  if (lua_isfunction (L, -1) == 0) {
    /* no function defined */
    lua_pop(L, 2);
    return 0;
  };

  /* Push a new table as the argument */
  lua_newtable (L);

  /* METHOD */
  if (p->type == HTTP_REQUEST || p->type == HTTP_BOTH) {
    lua_pushstring(L, method_to_str(p->method));
    lua_setfield(L, -2, "method");
  }

  /* STATUS */
  if (p->type == HTTP_RESPONSE || p->type == HTTP_BOTH) {
    lua_pushinteger(L, p->status_code);
    lua_setfield(L, -2, "status_code");
  }

  /* VERSION */
  lua_pushinteger(L, p->http_major);
  lua_setfield(L, -2, "version_major");

  lua_pushinteger(L, p->http_minor);
  lua_setfield(L, -2, "version_minor");

  lua_pushboolean(L, http_should_keep_alive(p));
  lua_setfield(L, -2, "should_keep_alive");

  lua_pushboolean(L, p->upgrade);
  lua_setfield(L, -2, "upgrade");

  lua_call(L, 1, 1);

  lua_pop(L, 2); /* pop returned value and the userdata env */
  return 0;
}

/******************************************************************************/

/* 
  Takes as arguments a string for type and a table for event callbacks 
  new(type, callbacks)
 */
static int lhttp_parser_new (lua_State *L) {

  const char *type = luaL_checkstring(L, 1);
  http_parser* parser;
  luaL_checktype(L, 2, LUA_TTABLE);

  parser = (http_parser*)lua_newuserdata(L, sizeof(http_parser));

  if (0 == strcmp(type, "request")) {
    http_parser_init(parser, HTTP_REQUEST);

  } else if (0 == strcmp(type, "response")) {
    http_parser_init(parser, HTTP_RESPONSE);

  } else if (0 == strcmp(type, "both")) {
    http_parser_init(parser, HTTP_BOTH);

  } else {
    return luaL_argerror(L, 1, "type must be 'both', 'request' or 'response'");
  }

  /* Store the current lua state in the parser's data */
  parser->data = L;

  /* Set the callback table as the userdata's environment */
  lua_pushvalue(L, 2);
  lua_setuservalue(L, -2);

  /* Set the type of the userdata as an lhttp_parser instance */
  luaL_getmetatable(L, "lhttp_parser");
  lua_setmetatable(L, -2);

  /* return the userdata */
  return 1;
}

static http_parser* lhttp_parser_check(lua_State *L, int index) {
  return (http_parser *)luaL_checkudata(L, 1, "lhttp_parser");
}

/* execute(parser, buffer, offset, length) */
static int lhttp_parser_execute(lua_State *L) {
  http_parser* parser = lhttp_parser_check(L, 1);
  size_t chunk_len = 0;

  luaL_checktype(L, 2, LUA_TSTRING);
  const char* chunk  = lua_tolstring(L, 2, &chunk_len);

  size_t offset = luaL_checkinteger(L, 3);
  size_t length = luaL_checkinteger(L, 4);

  luaL_argcheck(L, offset < chunk_len, 3, "Offset is out of bounds");
  luaL_argcheck(L, offset + length <= chunk_len, 4,  "Length extends beyond end of chunk");

  size_t nparsed = http_parser_execute(parser, &lhttp_parser_settings, chunk + offset, length);

  lua_pushnumber(L, nparsed);
  return 1;
}

/** finish(parser) */
static int lhttp_parser_finish(lua_State *L) {
  http_parser* parser = lhttp_parser_check(L, 1);

  int rv = http_parser_execute(parser, &lhttp_parser_settings, NULL, 0);
  if (rv != 0) {
    return luaL_error(L, http_errno_description(HTTP_PARSER_ERRNO(parser)));
  }

  return 0;
}

/** reset(parser, type) */
static int lhttp_parser_reset(lua_State *L) {
  http_parser* parser = lhttp_parser_check(L, 1);

  const char *type = luaL_checkstring(L, 2);

  if (0 == strcmp(type, "request")) {
    http_parser_init(parser, HTTP_REQUEST);

  } else if (0 == strcmp(type, "response")) {
    http_parser_init(parser, HTTP_RESPONSE);
    
  } else if (0 == strcmp(type, "both")) {
    http_parser_init(parser, HTTP_BOTH);

  } else {
    return luaL_argerror(L, 1, "type must be 'both', 'request' or 'response'");
  }

  return 0;
}

/** parse_url(buffer, is_connect) */
static int lhttp_parser_parse_url (lua_State *L) {
  size_t len;
  struct http_parser_url u;
  const char *url = luaL_checklstring(L, 1, &len);
  int is_connect = lua_tointeger(L, 2);
  if (http_parser_parse_url(url, len, is_connect, &u)) {
    luaL_error(L, "Error parsing url %s", url);
  }

  lua_newtable(L);
  if (u.field_set & (1 << UF_SCHEMA)) {
    lua_pushlstring(L, url + u.field_data[UF_SCHEMA].off, u.field_data[UF_SCHEMA].len);
    lua_setfield(L, -2, "schema");
  }

  if (u.field_set & (1 << UF_HOST)) {
    lua_pushlstring(L, url + u.field_data[UF_HOST].off, u.field_data[UF_HOST].len);
    lua_setfield(L, -2, "host");
  }

  if (u.field_set & (1 << UF_PORT)) {
    lua_pushlstring(L, url + u.field_data[UF_PORT].off, u.field_data[UF_PORT].len);
    lua_setfield(L, -2, "port_string");
    lua_pushnumber(L, u.port);
    lua_setfield(L, -2, "port");
  }

  if (u.field_set & (1 << UF_PATH)) {
    lua_pushlstring(L, url + u.field_data[UF_PATH].off, u.field_data[UF_PATH].len);
    lua_setfield(L, -2, "path");
  }

  if (u.field_set & (1 << UF_QUERY)) {
    lua_pushlstring(L, url + u.field_data[UF_QUERY].off, u.field_data[UF_QUERY].len);
    lua_setfield(L, -2, "query");
  }

  if (u.field_set & (1 << UF_FRAGMENT)) {
    lua_pushlstring(L, url + u.field_data[UF_FRAGMENT].off, u.field_data[UF_FRAGMENT].len);
    lua_setfield(L, -2, "fragment");
  }
  return 1;
}

/******************************************************************************/

static const luaL_Reg lhttp_parser_m[] = {
  {"execute",       lhttp_parser_execute},
  {"finish",        lhttp_parser_finish},
  {"reset",         lhttp_parser_reset},
  {NULL,            NULL}
};

static const luaL_Reg lhttp_parser_f[] = {
  {"new",           lhttp_parser_new},
  {"parse_url",     lhttp_parser_parse_url},
  {NULL,            NULL}
};

LUALIB_API int luaopen_lhttp_parser(lua_State *L) {

  /* This needs to be done sometime? */
  lhttp_parser_settings.on_message_begin    = lhttp_parser_on_message_begin;
  lhttp_parser_settings.on_url              = lhttp_parser_on_url;
  lhttp_parser_settings.on_header_field     = lhttp_parser_on_header_field;
  lhttp_parser_settings.on_header_value     = lhttp_parser_on_header_value;
  lhttp_parser_settings.on_headers_complete = lhttp_parser_on_headers_complete;
  lhttp_parser_settings.on_body             = lhttp_parser_on_body;
  lhttp_parser_settings.on_message_complete = lhttp_parser_on_message_complete;

  /* Create a metatable for the lhttp_parser userdata type */
  luaL_newmetatable(L, "lhttp_parser");
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_setfuncs(L, lhttp_parser_m, 0);

  /* Put our one function on it */
  luaL_newlib(L, lhttp_parser_f);

  /* Stick version info on the http_parser table */
  lua_pushnumber(L, HTTP_PARSER_VERSION_MAJOR);
  lua_setfield(L, -2, "VERSION_MAJOR");

  lua_pushnumber(L, HTTP_PARSER_VERSION_MINOR);
  lua_setfield(L, -2, "VERSION_MINOR");

  /* Return the new module */
  return 1;
}


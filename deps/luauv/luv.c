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

#include "luv.h"
#include "util.c"
#include "lhandle.c"
#include "lreq.c"
#include "loop.c"
#include "req.c"
#include "handle.c"
#include "timer.c"
#include "prepare.c"
#include "check.c"
#include "idle.c"
#include "async.c"
#include "poll.c"
#include "signal.c"
#include "process.c"
#include "stream.c"
#include "tcp.c"
#include "pipe.c"
#include "tty.c"
#include "udp.c"
#include "fs_event.c"
#include "fs_poll.c"
#include "fs.c"
#include "dns.c"
#include "thread.c"
#include "work.c"
#include "misc.c"
#include "constants.c"

static const luaL_Reg luv_functions[] = {
  // loop.c
  {"backend_fd",      luv_backend_fd},
  {"backend_timeout", luv_backend_timeout},
  {"loop_alive",      luv_loop_alive},
  {"loop_close",      luv_loop_close},
  {"now",             luv_now},
  {"run",             luv_run},
  {"stop",            luv_stop},
  {"update_time",     luv_update_time},
  {"walk",            luv_walk},

  // req.c
  {"cancel",          luv_cancel},

  // handle.c
  {"close",           luv_close},
  {"fileno",          luv_fileno},
  {"has_ref",         luv_has_ref},
  {"is_active",       luv_is_active},
  {"is_closing",      luv_is_closing},
  {"recv_buffer_size",luv_recv_buffer_size},
  {"ref",             luv_ref},
  {"send_buffer_size",luv_send_buffer_size},
  {"unref",           luv_unref},

  // timer.c
  {"new_timer",       luv_new_timer},
  {"timer_again",     luv_timer_again},
  {"timer_get_repeat",luv_timer_get_repeat},
  {"timer_set_repeat",luv_timer_set_repeat},
  {"timer_start",     luv_timer_start},
  {"timer_stop",      luv_timer_stop},

  // prepare.c
  {"new_prepare",     luv_new_prepare},
  {"prepare_start",   luv_prepare_start},
  {"prepare_stop",    luv_prepare_stop},

  // check.c
  {"new_check",       luv_new_check},
  {"check_start",     luv_check_start},
  {"check_stop",      luv_check_stop},

  // idle.c
  {"new_idle",        luv_new_idle},
  {"idle_start",      luv_idle_start},
  {"idle_stop",       luv_idle_stop},

  // async.c
  {"new_async",       luv_new_async},
  {"async_send",      luv_async_send},

  // poll.c
  {"new_poll",        luv_new_poll},
  {"new_socket_poll", luv_new_socket_poll},
  {"poll_start",      luv_poll_start},
  {"poll_stop",       luv_poll_stop},

  // signal.c
  {"new_signal",      luv_new_signal},
  {"signal_start",    luv_signal_start},
  {"signal_stop",     luv_signal_stop},

  // process.c
  {"disable_stdio_inheritance", luv_disable_stdio_inheritance},
  {"kill",            luv_kill},
  {"process_kill",    luv_process_kill},
  {"spawn",           luv_spawn},

  // stream.c
  {"accept",          luv_accept},
  {"is_readable",     luv_is_readable},
  {"is_writable",     luv_is_writable},
  {"listen",          luv_listen},
  {"read_start",      luv_read_start},
  {"read_stop",       luv_read_stop},
  {"shutdown",        luv_shutdown},
  {"stream_set_blocking", luv_stream_set_blocking},
  {"try_write",       luv_try_write},
  {"write",           luv_write},
  {"write2",          luv_write2},

  // tcp.c
  {"new_tcp",         luv_new_tcp},
  {"tcp_bind",        luv_tcp_bind},
  {"tcp_connect",     luv_tcp_connect},
  {"tcp_getpeername", luv_tcp_getpeername},
  {"tcp_getsockname", luv_tcp_getsockname},
  {"tcp_keepalive",   luv_tcp_keepalive},
  {"tcp_nodelay",     luv_tcp_nodelay},
  {"tcp_open",        luv_tcp_open},
  {"tcp_simultaneous_accepts", luv_tcp_simultaneous_accepts},
  {"tcp_write_queue_size", luv_write_queue_size},

  // pipe.c
  {"new_pipe",        luv_new_pipe},
  {"pipe_bind",       luv_pipe_bind},
  {"pipe_connect",    luv_pipe_connect},
  {"pipe_getpeername",luv_pipe_getpeername},
  {"pipe_getsockname",luv_pipe_getsockname},
  {"pipe_open",       luv_pipe_open},
  {"pipe_pending_count", luv_pipe_pending_count},
  {"pipe_pending_instances", luv_pipe_pending_instances},
  {"pipe_pending_type", luv_pipe_pending_type},

  // tty.c
  {"new_tty",         luv_new_tty},
  {"tty_get_winsize", luv_tty_get_winsize},
  {"tty_reset_mode",  luv_tty_reset_mode},
  {"tty_set_mode",    luv_tty_set_mode},

  // udp.c
  {"new_udp",         luv_new_udp},
  {"udp_bind",        luv_udp_bind},
  {"udp_getsockname", luv_udp_getsockname},
  {"udp_open",        luv_udp_open},
  {"udp_recv_start",  luv_udp_recv_start},
  {"udp_recv_stop",   luv_udp_recv_stop},
  {"udp_send",        luv_udp_send},
  {"udp_set_ttl",     luv_udp_set_ttl},
  {"udp_try_send",    luv_udp_try_send},

  {"udp_set_broadcast",           luv_udp_set_broadcast},
  {"udp_set_membership",          luv_udp_set_membership},
  {"udp_set_multicast_interface", luv_udp_set_multicast_interface},
  {"udp_set_multicast_loop",      luv_udp_set_multicast_loop},
  {"udp_set_multicast_ttl",       luv_udp_set_multicast_ttl},

  // fs_event.c
  {"new_fs_event",    luv_new_fs_event},
  {"fs_event_getpath",luv_fs_event_getpath},
  {"fs_event_start",  luv_fs_event_start},
  {"fs_event_stop",   luv_fs_event_stop},

  // fs_poll.c
  {"new_fs_poll",     luv_new_fs_poll},
  {"fs_poll_getpath", luv_fs_poll_getpath},
  {"fs_poll_start",   luv_fs_poll_start},
  {"fs_poll_stop",    luv_fs_poll_stop},

  // fs.c
  {"fs_access",     luv_fs_access},
  {"fs_chmod",      luv_fs_chmod},
  {"fs_chown",      luv_fs_chown},
  {"fs_close",      luv_fs_close},
  {"fs_fchmod",     luv_fs_fchmod},
  {"fs_fchown",     luv_fs_fchown},
  {"fs_fdatasync",  luv_fs_fdatasync},
  {"fs_fstat",      luv_fs_fstat},
  {"fs_fsync",      luv_fs_fsync},
  {"fs_ftruncate",  luv_fs_ftruncate},
  {"fs_futime",     luv_fs_futime},
  {"fs_link",       luv_fs_link},
  {"fs_lstat",      luv_fs_lstat},
  {"fs_mkdir",      luv_fs_mkdir},
  {"fs_mkdtemp",    luv_fs_mkdtemp},
  {"fs_open",       luv_fs_open},
  {"fs_read",       luv_fs_read},
  {"fs_readlink",   luv_fs_readlink},
  {"fs_realpath",   luv_fs_realpath},  
  {"fs_rename",     luv_fs_rename},
  {"fs_rmdir",      luv_fs_rmdir},
  {"fs_scandir",    luv_fs_scandir},
  {"fs_scandir_next", luv_fs_scandir_next},
  {"fs_sendfile",   luv_fs_sendfile},
  {"fs_stat",       luv_fs_stat},
  {"fs_symlink",    luv_fs_symlink},
  {"fs_unlink",     luv_fs_unlink},
  {"fs_utime",      luv_fs_utime},
  {"fs_write",      luv_fs_write},

  // dns.c
  {"getaddrinfo",   luv_getaddrinfo},
  {"getnameinfo",   luv_getnameinfo},

  // misc.c
  {"chdir",         luv_chdir},
  {"cpu_info",      luv_cpu_info},
  {"cwd",           luv_cwd},
  {"exepath",       luv_exepath},
  {"getpid",        luv_getpid},
  {"os_homedir",    luv_os_homedir},

  {"get_free_memory",   luv_get_free_memory},
  {"get_process_title", luv_get_process_title},
  {"get_total_memory",  luv_get_total_memory},

#ifndef _WIN32
  {"getgid",        luv_getgid},
  {"getuid",        luv_getuid},
  {"setgid",        luv_setgid},
  {"setuid",        luv_setuid},
#endif

  {"getrusage",     luv_getrusage},
  {"guess_handle",  luv_guess_handle},
  {"hrtime",        luv_hrtime},
  {"loadavg",       luv_loadavg},
  {"uptime",        luv_uptime},
  {"version",       luv_version},
  {"version_string",luv_version_string},

  {"interface_addresses", luv_interface_addresses},
  {"resident_set_memory", luv_resident_set_memory},
  {"set_process_title",   luv_set_process_title},

  // thread.c
  {"new_thread",    luv_new_thread},
  {"sleep",         luv_thread_sleep},
  {"thread_equal",  luv_thread_equal},
  {"thread_join",   luv_thread_join},
  {"thread_self",   luv_thread_self},

  // work.c
  {"new_work",      luv_new_work},
  {"queue_work",    luv_queue_work},

  {NULL, NULL}
};

static const luaL_Reg luv_handle_methods[] = {
  // handle.c
  {"close",           luv_close},
  {"fileno",          luv_fileno},
  {"has_ref",         luv_has_ref},
  {"is_active",       luv_is_active},
  {"is_closing",      luv_is_closing},
  {"recv_buffer_size",luv_recv_buffer_size},
  {"ref",             luv_ref},
  {"send_buffer_size",luv_send_buffer_size},
  {"unref",           luv_unref},
  {NULL, NULL}
};

static const luaL_Reg luv_async_methods[] = {
  {"send",    luv_async_send},
  {NULL, NULL}
};

static const luaL_Reg luv_check_methods[] = {
  {"start",   luv_check_start},
  {"stop",    luv_check_stop},
  {NULL, NULL}
};

static const luaL_Reg luv_fs_event_methods[] = {
  {"start",   luv_fs_event_start},
  {"stop",    luv_fs_event_stop},
  {"getpath", luv_fs_event_getpath},
  {NULL, NULL}
};

static const luaL_Reg luv_fs_poll_methods[] = {
  {"start",   luv_fs_poll_start},
  {"stop",    luv_fs_poll_stop},
  {"getpath", luv_fs_poll_getpath},
  {NULL, NULL}
};

static const luaL_Reg luv_idle_methods[] = {
  {"start",   luv_idle_start},
  {"stop",    luv_idle_stop},
  {NULL, NULL}
};

static const luaL_Reg luv_stream_methods[] = {
  {"accept",      luv_accept},
  {"is_readable", luv_is_readable},
  {"is_writable", luv_is_writable},
  {"listen",      luv_listen},
  {"read_start",  luv_read_start},
  {"read_stop",   luv_read_stop},
  {"set_blocking",luv_stream_set_blocking},
  {"shutdown",    luv_shutdown},
  {"try_write",   luv_try_write},
  {"write",       luv_write},
  {"write2",      luv_write2},
  {NULL, NULL}
};

static const luaL_Reg luv_pipe_methods[] = {
  {"bind",        luv_pipe_bind},
  {"connect",     luv_pipe_connect},
  {"getpeername", luv_pipe_getpeername},
  {"getsockname", luv_pipe_getsockname},
  {"open",        luv_pipe_open},
  {"pending_count", luv_pipe_pending_count},
  {"pending_instances", luv_pipe_pending_instances},
  {"pending_type", luv_pipe_pending_type},
  {NULL, NULL}
};

static const luaL_Reg luv_poll_methods[] = {
  {"start",   luv_poll_start},
  {"stop",    luv_poll_stop},
  {NULL, NULL}
};

static const luaL_Reg luv_prepare_methods[] = {
  {"start",   luv_prepare_start},
  {"stop",    luv_prepare_stop},
  {NULL, NULL}
};

static const luaL_Reg luv_process_methods[] = {
  {"kill",    luv_process_kill},
  {NULL, NULL}
};

static const luaL_Reg luv_tcp_methods[] = {
  {"bind",        luv_tcp_bind},
  {"connect",     luv_tcp_connect},
  {"getpeername", luv_tcp_getpeername},
  {"getsockname", luv_tcp_getsockname},
  {"keepalive",   luv_tcp_keepalive},
  {"nodelay",     luv_tcp_nodelay},
  {"open",        luv_tcp_open},
  {"simultaneous_accepts", luv_tcp_simultaneous_accepts},
  {"write_queue_size", luv_write_queue_size},
  {NULL, NULL}
};

static const luaL_Reg luv_timer_methods[] = {
  {"again",       luv_timer_again},
  {"get_repeat",  luv_timer_get_repeat},
  {"set_repeat",  luv_timer_set_repeat},
  {"start",       luv_timer_start},
  {"stop",        luv_timer_stop},
  {NULL, NULL}
};

static const luaL_Reg luv_tty_methods[] = {
  {"set_mode",    luv_tty_set_mode},
  {"get_winsize", luv_tty_get_winsize},
  {NULL, NULL}
};

static const luaL_Reg luv_udp_methods[] = {
  {"bind",          luv_udp_bind},
  {"open",          luv_udp_open},
  {"recv_start",    luv_udp_recv_start},
  {"recv_stop",     luv_udp_recv_stop},  
  {"send",          luv_udp_send},
  {"set_broadcast", luv_udp_set_broadcast},
  {"set_ttl",       luv_udp_set_ttl},
  {"try_send",      luv_udp_try_send},

  {"bindgetsockname",         luv_udp_getsockname},
  {"set_membership",          luv_udp_set_membership},
  {"set_multicast_interface", luv_udp_set_multicast_interface},
  {"set_multicast_loop",      luv_udp_set_multicast_loop},
  {"set_multicast_ttl",       luv_udp_set_multicast_ttl},
  {NULL, NULL}
};

static const luaL_Reg luv_signal_methods[] = {
  {"start",   luv_signal_start},
  {"stop",    luv_signal_stop},
  {NULL, NULL}
};

static void luv_handle_init(lua_State* L) {

  lua_newtable(L);
#define XX(uc, lc)                             \
    luaL_newmetatable (L, "uv_"#lc);           \
    lua_pushcfunction(L, luv_handle_tostring); \
    lua_setfield(L, -2, "__tostring");         \
    lua_pushcfunction(L, luv_handle_gc);       \
    lua_setfield(L, -2, "__gc");               \
    luaL_newlib(L, luv_##lc##_methods);        \
    luaL_setfuncs(L, luv_handle_methods, 0);   \
    lua_setfield(L, -2, "__index");            \
    lua_pushboolean(L, 1);                     \
    lua_rawset(L, -3);

  UV_HANDLE_TYPE_MAP(XX)
#undef XX
  lua_setfield(L, LUA_REGISTRYINDEX, "uv_handle");

  lua_newtable(L);

  luaL_getmetatable(L, "uv_pipe");
  lua_getfield(L, -1, "__index");
  luaL_setfuncs(L, luv_stream_methods, 0);
  lua_pop(L, 1);
  lua_pushboolean(L, 1);
  lua_rawset(L, -3);

  luaL_getmetatable(L, "uv_tcp");
  lua_getfield(L, -1, "__index");
  luaL_setfuncs(L, luv_stream_methods, 0);
  lua_pop(L, 1);
  lua_pushboolean(L, 1);
  lua_rawset(L, -3);

  luaL_getmetatable(L, "uv_tty");
  lua_getfield(L, -1, "__index");
  luaL_setfuncs(L, luv_stream_methods, 0);
  lua_pop(L, 1);
  lua_pushboolean(L, 1);
  lua_rawset(L, -3);

  lua_setfield(L, LUA_REGISTRYINDEX, "uv_stream");
}

LUALIB_API lua_State* luv_state(uv_loop_t* loop) {
  return loop->data;
}

// TODO: find out if storing this somehow in an upvalue is faster
LUALIB_API uv_loop_t* luv_loop(lua_State* L) {
  uv_loop_t* loop;
  lua_pushstring(L, "uv_loop");
  lua_rawget(L, LUA_REGISTRYINDEX);
  loop = lua_touserdata(L, -1);
  lua_pop(L, 1);
  return loop;
}

static void walk_cb(uv_handle_t *handle, void *arg)
{
  if (!uv_is_closing(handle)) {
    uv_close(handle, luv_close_cb);
  }
}

static int loop_gc(lua_State *L) {
  uv_loop_t* loop = luv_loop(L);
  // Call uv_close on every active handle
  uv_walk(loop, walk_cb, NULL);
  // Run the event loop until all handles are successfully closed
  while (uv_loop_close(loop)) {
    uv_run(loop, UV_RUN_DEFAULT);
  }
  return 0;
}

LUALIB_API int luaopen_luv (lua_State *L) {

  uv_loop_t* loop;
  int ret;

  // Setup the uv_loop meta table for a proper __gc
  luaL_newmetatable(L, "uv_loop.meta");
  lua_pushstring(L, "__gc");
  lua_pushcfunction(L, loop_gc);
  lua_settable(L, -3);

  loop = lua_newuserdata(L, sizeof(*loop));
  ret = uv_loop_init(loop);
  if (ret < 0) {
    return luaL_error(L, "%s: %s\n", uv_err_name(ret), uv_strerror(ret));
  }
  // setup the metatable for __gc
  luaL_getmetatable(L, "uv_loop.meta");
  lua_setmetatable(L, -2);
  // Tell the state how to find the loop.
  lua_pushstring(L, "uv_loop");
  lua_insert(L, -2);
  lua_rawset(L, LUA_REGISTRYINDEX);
  lua_pop(L, 1);

  // Tell the loop how to find the state.
  loop->data = L;

  luv_req_init(L);
  luv_handle_init(L);
  luv_thread_init(L);
  luv_work_init(L);

  luaL_newlib(L, luv_functions);
  luv_constants(L);
  lua_setfield(L, -2, "constants");

  return 1;
}

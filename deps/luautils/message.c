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
#include "luv.h"

#include "lthreadpool.h"

//////////////////////////////////////////////////////////////////////////
// message queue

typedef struct luv_msg_s
{
	luv_thread_arg_t arg;
	struct luv_msg_s* next;
} luv_msg_t;

/** 
 * 
 * 代表一个消息队列。
 */
typedef struct luv_queue_s
{
	char* name;
	luv_msg_t* msg_head;
	luv_msg_t* msg_tail;
	int limit;
	int count;
	uv_mutex_t lock;
	uv_cond_t send_sig;
	uv_cond_t recv_sig;
	struct luv_queue_s* prev;
	struct luv_queue_s* next;
	int refs;
	int bucket;
	uv_async_t async;
	int async_cb;       /* ref, run in main, call when async message received, NYI */
	lua_State* L;       /* vm in main */

} luv_queue_t;


static void luv_queues_detach(luv_queue_t* q);
static luv_msg_t* luv_queue_recv(luv_queue_t* queue, int timeout);

static void luv_queue_message_release(luv_msg_t* msg)
{
	if (msg) {
		luv_thread_arg_clear(&(msg->arg));
		free(msg);
		msg = NULL;
	}
}

static void luv_queue_async_callback(uv_async_t *handle)
{
	luv_queue_t* queue = handle->data;
	if (queue == NULL) {
		printf("queue");
		return;
	}

	lua_State* L = queue->L;
	if (L == NULL) {
		printf("L");
		return;
	}

	while (1) {
		luv_msg_t* msg = luv_queue_recv(queue, 0);
		if (msg == NULL) {
			break;
		}

		// callback
		lua_rawgeti(L, LUA_REGISTRYINDEX, queue->async_cb);
		if (lua_isnil(L, -1)) {
			luv_queue_message_release(msg);
			continue;
		}

		// args
		int ret = luv_thread_arg_push(L, &(msg->arg));
		luv_queue_message_release(msg);
		msg = NULL;

		// call
		if (lua_pcall(L, ret, 0, 0)) {
			fprintf(stderr, "Uncaught Error in thread async: %s\n", lua_tostring(L, -1));
		}
	}
}

static luv_queue_t* luv_queue_create(const char* name, int limit)
{
	if (name == NULL) {
		return NULL;
	}

	size_t name_len = strlen(name);
	luv_queue_t* queue = (luv_queue_t*)malloc(sizeof(luv_queue_t) + name_len + 1);
	queue->name = (char*)queue + sizeof(luv_queue_t);
	memcpy(queue->name, name, name_len + 1);

	queue->msg_head = queue->msg_tail = NULL;
	queue->limit = limit;
	queue->count = 0;
	queue->prev = queue->next = NULL;
	queue->refs = 1;

	uv_mutex_init(&queue->lock);
	uv_cond_init(&queue->send_sig);
	uv_cond_init(&queue->recv_sig);

	// printf("queue_create: %s, limit=%d\n", name, limit);
	return queue;
}

static void luv_queue_destroy(luv_queue_t* queue)
{
	if (queue == NULL) {
		return;
	}

	luv_msg_t *msgs = queue->msg_head, *last = NULL;
	// printf("queue_destroy: %s\n", queue->name);
	free(queue);

	while (msgs) {
		last = msgs;
		msgs = msgs->next;

		luv_queue_message_release(last);
	}
}

static void luv_queue_lock(luv_queue_t* q)
{
	uv_mutex_lock(&q->lock);
}

static void luv_queue_unlock(luv_queue_t* q)
{
	uv_mutex_unlock(&q->lock);
}

static long luv_queue_acquire(luv_queue_t* queue)
{
	long refs;
	luv_queue_lock(queue);
	refs = ++queue->refs;
	luv_queue_unlock(queue);
	// printf("queue_acquire: %s, refs=%d\n", q->name, q->refs);
	return refs;
}

static long luv_queue_release(luv_queue_t* queue)
{
	long refs;
	luv_queue_lock(queue);
	refs = --queue->refs;
	printf("queue_release: %s, refs=%d\n", queue->name, queue->refs);

	if (refs == 0) {
		luv_queues_detach(queue);
	}

	luv_queue_unlock(queue);
	if (refs == 0) {
		luv_queue_destroy(queue);
	}
	return refs;
}

static int luv_queue_send(luv_queue_t* queue, luv_msg_t* msg, int timeout)
{
	luv_queue_lock(queue);

	// wait
	while (timeout != 0 && queue->limit >= 0 && queue->count + 1 > queue->limit) {
		if (timeout > 0) {
			int64_t waittime = timeout;
			waittime = waittime * 1000000L;

			if (uv_cond_timedwait(&queue->send_sig, &queue->lock, waittime) != 0) {
				break;
			}

		} else {
			uv_cond_wait(&queue->send_sig, &queue->lock);
		}
	}

	// printf("queue: %d/%d", queue->limit, queue->count);

	if (queue->limit < 0 || queue->count + 1 <= queue->limit) {
		msg->next = NULL;
		if (queue->msg_tail) {
			queue->msg_tail->next = msg;
		}

		queue->msg_tail = msg;
		if (queue->msg_head == NULL) {
			queue->msg_head = msg;
		}

		queue->count++;
		uv_cond_signal(&queue->recv_sig);

	} else {
		msg = NULL;
	}

	luv_queue_unlock(queue);
	return msg ? 1 : 0;
}

static luv_msg_t* luv_queue_recv(luv_queue_t* queue, int timeout)
{
	luv_msg_t* msg = NULL;

	luv_queue_lock(queue);
	if (queue->limit >= 0) {
		queue->limit++;
		uv_cond_signal(&queue->send_sig);
	}

	// wait
	while (timeout != 0 && queue->count <= 0) {
		if (timeout > 0) {
			int64_t waittime = timeout;
			waittime = waittime * 1000000L;
			if (uv_cond_timedwait(&queue->recv_sig, &queue->lock, waittime) != 0) {
				break;
			}

		} else {
			uv_cond_wait(&queue->recv_sig, &queue->lock);
		}
	}

	if (queue->count > 0) {
		msg = queue->msg_head;
		if (msg) {
			queue->msg_head = msg->next;
			if (queue->msg_head == NULL) {
				queue->msg_tail = NULL;
			}
			msg->next = NULL;
		}
		queue->count--;
		uv_cond_signal(&queue->send_sig);
	}

	if (queue->limit > 0) {
		queue->limit--;
	}

	luv_queue_unlock(queue);
	return msg;
}

#define BUCKET_SIZE 16
struct luv_queue_entry_t
{
	luv_queue_t* head;
	luv_queue_t* tail;
};

static struct luv_queue_entry_t luv_queue_list[BUCKET_SIZE];
static uv_mutex_t luv_queues_lock; // = PTHREAD_MUTEX_INITIALIZER;

static int luv_queue_name_hash(const char* name)
{
	int hash = 0;
	char ch;
	while ((ch = *name++) != 0) {
		hash += ch;
		hash &= 0xff;
	}
	return hash & (BUCKET_SIZE - 1);
}

static luv_queue_t* luv_queue_bucket_search(int bucket, const char* name)
{
	luv_queue_t* queue = luv_queue_list[bucket].head;
	for (; queue; queue = queue->next) {
		if (strcmp(queue->name, name) == 0) {
			return queue;
		}
	}
	return NULL;
}

static int luv_queues_add(luv_queue_t* queue)
{
	if (queue == NULL) {
		return 0;
	}

	int hash = luv_queue_name_hash(queue->name);
	uv_mutex_lock(&luv_queues_lock);
	if (luv_queue_bucket_search(hash, queue->name)) {
		uv_mutex_unlock(&luv_queues_lock);
		return 0;
	}

	queue->next = NULL;
	queue->prev = luv_queue_list[hash].tail;
	if (luv_queue_list[hash].tail) {
		luv_queue_list[hash].tail->next = queue;
	}

	luv_queue_list[hash].tail = queue;
	if (!luv_queue_list[hash].head) {
		luv_queue_list[hash].head = queue;
	}

	queue->bucket = hash;
	uv_mutex_unlock(&luv_queues_lock);
	// printf("queues_add: %s bucket=%d\n", queue->name, hash);
	return 1;
}

static luv_queue_t* luv_queues_get(const char* name)
{
	if (name == NULL) {
		return NULL;
	}

	int hash = luv_queue_name_hash(name);
	luv_queue_t* queue = NULL;
	uv_mutex_lock(&luv_queues_lock);
	queue = luv_queue_bucket_search(hash, name);
	if (queue) {
		luv_queue_acquire(queue);
	}
	uv_mutex_unlock(&luv_queues_lock);
	return queue;
}

static void luv_queues_detach(luv_queue_t* queue)
{
	if (queue == NULL) {
		return;
	}

	// printf("queues_detach: %s, bucket=%d\n", queue->name, queue->bucket);
	if (queue->prev) {
		queue->prev->next = queue->next;

	} else {
		luv_queue_list[queue->bucket].head = queue->next;
	}

	if (queue->next) {
		queue->next->prev = queue->prev;

	} else {
		luv_queue_list[queue->bucket].tail = queue->prev;
	}

	queue->next = queue->prev = NULL;
	queue->bucket = -1;
}

static void luv_queue_lua_usage(lua_State* L, const char* usage)
{
	lua_pushstring(L, usage);
	lua_error(L);
}

static const char* luv_queue_lua_arg_string(lua_State* L, int index, const char *def_val, const char* usage)
{
	if (lua_gettop(L) >= index) {
		const char* str = lua_tostring(L, index);
		if (str) {
			return str;
		}

	} else if (def_val) {
		return def_val;
	}

	luv_queue_lua_usage(L, usage);
	return NULL;
}

static int luv_queue_lua_arg_integer(lua_State* L, int index, int optional, int def_val, const char* usage)
{
	if (lua_gettop(L) >= index) {
		if (lua_isnumber(L, index)) {
			return (int)lua_tointeger(L, index);
		}

	} else if (optional) {
		return def_val;
	}

	luv_queue_lua_usage(L, usage);
	return 0;
}

static luv_queue_t* luv_queue_check_queue_t(lua_State* L)
{
	luv_queue_t* q = (luv_queue_t*)lua_topointer(L, 1);
	if (q == NULL) {
		lua_pushstring(L, "invalid queue object");
		lua_error(L);
	}
	return q;
}

#define LUV_QUEUE_METATABLE_NAME "luv_chan_metatable"
static const char* queue_usage_send = "chan:send(string|number|boolean)";
static const char* queue_usage_recv = "chan:recv(timeout = -1)";
static const char* queue_usage_new = "chan.new(name, limit = 0, onmessage)";
static const char* queue_usage_get = "chan get(name)";

static int luv_queue_channel_send(lua_State* L)
{
	int type, ret;
	luv_msg_t* msg;
	luv_queue_t* queue = luv_queue_check_queue_t(L);
	if (lua_gettop(L) < 2) {
		luv_queue_lua_usage(L, queue_usage_send);
	}

	msg = (luv_msg_t*)malloc(sizeof(luv_msg_t));
	ret = luv_thread_arg_set(L, &msg->arg, 2, lua_gettop(L), 1);
	// printf("chan_send: %d\r\n", ret);

	ret = luv_queue_send(queue, msg, 0);
	if (!ret) {
		luv_queue_message_release(msg);

	} else {
		if (queue->async_cb != LUA_REFNIL) {
			uv_async_send(&(queue->async));
		}
	}

	lua_pushboolean(L, ret);
	return 1;
}

static int luv_queue_channel_recv(lua_State* L)
{
	luv_queue_t* q = luv_queue_check_queue_t(L);
	int timeout = luv_queue_lua_arg_integer(L, 2, 1, -1, queue_usage_recv);
	luv_msg_t* msg = luv_queue_recv(q, timeout);
	if (msg) {
		int ret = luv_thread_arg_push(L, &(msg->arg));
		luv_queue_message_release(msg);
		return ret;

	} else {
		lua_pushnil(L);
	}
	return 1;
}

static int luv_queue_channel_stop(lua_State* L)
{
	luv_queue_t* queue = luv_queue_check_queue_t(L);

	uv_mutex_lock(&luv_queues_lock);
	if (queue->async_cb != LUA_REFNIL) {
		uv_close((uv_handle_t*)&queue->async, NULL);
		queue->async_cb = LUA_REFNIL;
	}
	uv_mutex_unlock(&luv_queues_lock);
	return 0;
}

static int luv_queue_channel_gc(lua_State* L)
{
	luv_queue_t* queue = luv_queue_check_queue_t(L);
	printf("chan_gc: %s, refs=%d\n", queue->name, queue->refs);

	uv_mutex_lock(&luv_queues_lock);
	if (queue->async_cb != LUA_REFNIL) {
		uv_close((uv_handle_t*)&queue->async, NULL);
		queue->async_cb = LUA_REFNIL;
	}

	luv_queue_release(queue);
	uv_mutex_unlock(&luv_queues_lock);
	return 0;
}

static int luv_queue_channel_push_queue(lua_State* L, luv_queue_t* queue)
{
	lua_pushlightuserdata(L, queue);
	luaL_getmetatable(L, LUV_QUEUE_METATABLE_NAME);
	lua_setmetatable(L, -2);
	return 0;
}

static int luv_queue_channel_new(lua_State* L)
{
	const char* name = luv_queue_lua_arg_string(L, 1, NULL, queue_usage_new);
	int limit = luv_queue_lua_arg_integer(L, 2, 1, 0, queue_usage_new);
	luv_queue_t* queue = luv_queue_create(name, limit);

	if (lua_gettop(L) >= 3) {
		lua_pushvalue(L, 3);
		queue->async_cb = luaL_ref(L, LUA_REGISTRYINDEX);

		uv_async_init(luv_loop(L), &queue->async, luv_queue_async_callback);
		queue->async.data = queue;

	} else {
		queue->async_cb = LUA_REFNIL;
		queue->async.data = NULL;
	}

	queue->L = L;

	if (!luv_queues_add(queue)) {
		luv_queue_destroy(queue);
		lua_pushnil(L);
		lua_pushstring(L, "chan name duplicated");
		return 2;
	}

	luv_queue_channel_push_queue(L, queue);
	return 1;
}

static int luv_queue_channel_get(lua_State* L)
{
	const char* name = luv_queue_lua_arg_string(L, 1, NULL, queue_usage_get);
	luv_queue_t* queue = luv_queues_get(name);
	if (queue) {
		luv_queue_channel_push_queue(L, queue);
		return 1;

	} else {
		lua_pushnil(L);
		lua_pushstring(L, "not found");
		return 2;
	}
};

static const luaL_Reg luv_queue_channel_methods[] = {
	{ "send", luv_queue_channel_send },
	{ "recv", luv_queue_channel_recv },
	{ "stop", luv_queue_channel_stop },
	{ NULL, NULL }
};

static void luv_queue_init(lua_State* L) {
	luaL_newmetatable(L, LUV_QUEUE_METATABLE_NAME);

	lua_pushcfunction(L, luv_queue_channel_gc);
	lua_setfield(L, -2, "__gc");

	lua_newtable(L);
	luaL_setfuncs(L, luv_queue_channel_methods, 0);
	lua_setfield(L, -2, "__index");
	lua_pop(L, 1);
}


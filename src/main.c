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
#include "lnode.h"

static void lnode_print_version (void) {
  	char buffer[250];
  	memset(buffer, 0, sizeof(buffer));
  	sprintf(buffer, "Node.lua %s.%s.%s Copyright (C) 2015 ChengZhen (libuv %s, %s).", 
  		LUA_VERSION_MAJOR, LUA_VERSION_MINOR, LUA_VERSION_RELEASE, 
  		uv_version_string(), __DATE__);
  	lua_writestring(buffer, strlen(buffer));
  	lua_writeline();
}

lua_State* lnode_vm_acquire() {
  lua_State* L = luaL_newstate();
  if (L == NULL) {
    return L;
  }

  // Add in the lua standard libraries
  luaL_openlibs(L);

  // Add in the lua ext libraries
  lnode_openlibs(L);

  // load init module
  lnode_init(L);

  return L;
}

void lnode_vm_release(lua_State* L) {
  lua_close(L);
}

int main(int argc, char* argv[]) {
	lua_State* L = NULL;
	int index = 0;
	int res = 0;
	int script = 1;
	int has_script = 0;

	// Hooks in libuv that need to be done in main.
	argv = uv_setup_args(argc, argv);

	if (argc >= 2) {
		if (strcmp(argv[1], "-d") == 0) {
			lnode_run_as_deamon();
			script = 2;

		} else if (strcmp(argv[1], "-") == 0) {
			script = 2;
			has_script = 1;
		}
	}

	char* filename = NULL;
	if ((script > 0) && (script < argc)) {
		filename = argv[script];
		has_script = 1;
	}

	// Create the lua state.
	L = lnode_vm_acquire();
	if (L == NULL) {
		fprintf(stderr, "luaL_newstate has failed\n");
		return 1;
	}

	luv_set_thread_cb(lnode_vm_acquire, lnode_vm_release);

	if (has_script) {
		res = lnode_load_script(L, filename, argc, argv, script);

	} else {
		lnode_print_version();
	}

	lnode_vm_release(L);
	return res;
}

#ifndef LUTILS_H
#define LUTILS_H

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <string.h>
#include <stdlib.h>
#include <assert.h>

#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#else
#include <unistd.h>
#include <errno.h>
#endif

int lutils_base64_encode( unsigned char *dst, size_t dlen, size_t *olen,
                   const unsigned char *src, size_t slen);

int lutils_base64_decode( unsigned char *dst, size_t dlen, size_t *olen,
                   const unsigned char *src, size_t slen);                  

int lutils_hex16_decode(char* buffer, size_t bufferSize, const void* data, size_t dataSize);
int lutils_hex16_encode(char* buffer, size_t bufferSize, const void* data, size_t dataSize);



#endif // LUTILS_H
#ifndef LUTILS_BUFFER_H
#define LUTILS_BUFFER_H

#define LUV_BUFFER 100

typedef struct luv_ppp_buffer_s {
	int   type;
	char* data;
	int   size;
	int   position;
	int   limit;
} luv_ppp_buffer_t;

#endif // LUTILS_BUFFER_H

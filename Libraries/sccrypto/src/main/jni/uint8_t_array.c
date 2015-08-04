/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "uint8_t_array.h"

uint8_t_array *uint8_t_array_init() {
	uint8_t_array *array = malloc(sizeof(uint8_t_array));
	if (array != NULL) {
		array->version = 1;
		array->size = 0;
		array->items = NULL;
	}
	return array;
}

uint8_t_array *uint8_t_array_allocate(size_t size) {
	uint8_t_array *array = uint8_t_array_init();
	if (array != NULL) {
		array->size = size;
		array->items = calloc(array->size, sizeof(uint8_t));
		// what to do if we can't allocate items? blow this away and return NULL
		if (array->items == NULL) {
			uint8_t_array_free(array);
			return NULL;
		}
	}
	return array;
}

void uint8_t_array_free(uint8_t_array *array) {
	if (array == NULL) {
		return;
	}
	if (array->items != NULL) {
		free(array->items);
		array->items = NULL;
	}
	array->size = 0;
	free(array);
}

uint8_t_array *uint8_t_array_parse(const char *in) {
	uint8_t_array *array = uint8_t_array_init();
	if (array != NULL) {
		size_t size = strlen(in);
		array->size = size;
		array->items = malloc(sizeof(uint8_t) * size);
		// what to do if we can't allocate items? blow this away and return NULL
		if (array->items == NULL) {
			uint8_t_array_free(array);
			return NULL;
		}
		memcpy(array->items, in, sizeof(uint8_t) * size);
	}
	return array;
}

uint8_t *uint8_t_array_copyToCString(uint8_t_array *array) {
	uint8_t *str = malloc(sizeof(uint8_t) * (array->size + 1));
	if (str != NULL) {
		memcpy(str, array->items, array->size);
		str[array->size] = 0; // null-terminated
	}
	return str;
}

uint8_t_array *uint8_t_array_copy(void *from, size_t size) {
	uint8_t_array *array = uint8_t_array_init();
	if (array != NULL) {
		array->size = size;
		array->items = malloc(sizeof(uint8_t) * size);
		// what to do if we can't allocate items? blow this away and return NULL
		if (array->items == NULL) {
			uint8_t_array_free(array);
			return NULL;
		}
		memcpy(array->items, from, sizeof(uint8_t) * array->size);
	}
	return array;
}

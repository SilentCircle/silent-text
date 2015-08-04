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
#include <stdlib.h>

typedef struct QueueObj_t {
	void *data;
	struct QueueObj_t *next;
} QueueObj;

typedef struct OfflineMessageQueue_t {
	QueueObj *first;
	QueueObj *last;
} OfflineMessageQueue;

OfflineMessageQueue *initQ();
void freeQ(OfflineMessageQueue *q);
void pushQ(OfflineMessageQueue *q, void *data);
void *popQ(OfflineMessageQueue *q);

OfflineMessageQueue *initQ() {
	OfflineMessageQueue *q = malloc(sizeof(OfflineMessageQueue));
	q->first = NULL;
	q->last = NULL;
	return q;
}

void freeQ(OfflineMessageQueue *q) {
	void *data;
	while ((data = popQ(q)) != NULL) // pop everything
		free(data);
	free(q);
}

void pushQ(OfflineMessageQueue *q, void *data) {
	QueueObj *obj = malloc(sizeof(QueueObj));
	obj->data = data;
	obj->next = NULL;
	if (q->last) {
		q->last->next = obj;
		q->last = obj;
	} else {
		q->first = obj;
		q->last = obj;
	}
}

void *popQ(OfflineMessageQueue *q) {
	QueueObj *obj = q->first;
	if (obj == NULL)
		return NULL;

	void *data = obj->data;

	q->first = obj->next;
	if (q->last == obj)
		q->last = NULL;

	free(obj);
	return data;
}

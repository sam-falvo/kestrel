#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "types.h"
#include "sdcard.h"


SDCard *
sdcard_new(void) {
	SDCard *sdc = malloc(sizeof(SDCard));
	if(sdc) {
		memset(sdc, 0, sizeof(SDCard));
	}
	return sdc;
}


void
sdcard_dispose(SDCard *sdc) {
	if(sdc) free(sdc);
}


int
sdcard_response_empty(SDCard *sdc) {
	return sdc->response_rd == sdc->response_wr;
}


BYTE
sdcard_dequeue(SDCard *sdc) {
	BYTE b;
	if(sdcard_response_empty(sdc)) {
		return -1;
	}
	b = sdc->response[sdc->response_rd];
	sdc->response_rd = (sdc->response_rd + 1) % SDBUF_SIZE;
	return b;
}


void
sdcard_enqueue_response(SDCard *sdc, BYTE b) {
	sdc->response[sdc->response_wr] = b;
	sdc->response_wr = (sdc->response_wr + 1) % SDBUF_SIZE;
}


BYTE
sdcard_byte(SDCard *sdc, BYTE input) {
	BYTE b = sdcard_dequeue(sdc);

	sdc->command[sdc->cmd_index] = input;
	sdc->cmd_index++;

	if(sdc->cmd_index > 5) {
		sdc->cmd_handler(sdc);
		sdc->cmd_index = 0;
	}

	return b;
}


void
sdcard_select(SDCard *sdc) {
	sdc->selected = 1;
	sdc->cmd_index = 0;
}


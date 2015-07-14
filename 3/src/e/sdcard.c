#include <string.h>
#include <stdlib.h>

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


BYTE
sdcard_byte(SDCard *sdc, BYTE input) {
	sdc->command[sdc->cmd_index] = input;
	sdc->cmd_index++;

	if(sdc->cmd_index > 5) {
		sdc->cmd_handler();
		sdc->cmd_index = 0;
	}

	return 0xFF;
}


void
sdcard_select(SDCard *sdc) {
	sdc->selected = 1;
	sdc->cmd_index = 0;
}


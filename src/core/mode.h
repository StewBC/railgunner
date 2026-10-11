#ifndef RAILGUNNER_MODE_H
#define RAILGUNNER_MODE_H

#include "sim.h"

void mode_set(Game *g, uint8_t mode);
void mode_run(Game *g);
const char *mode_name(uint8_t mode);

#endif

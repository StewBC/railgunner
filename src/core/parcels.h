#ifndef RAILGUNNER_PARCELS_H
#define RAILGUNNER_PARCELS_H

#include "sim.h"

void parcels_init(Game *g);
void parcels_level_reset(Game *g);
void parcels_on_kill(Game *g);
void parcels_update(Game *g);

#endif

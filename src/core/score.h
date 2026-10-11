#ifndef RAILGUNNER_SCORE_H
#define RAILGUNNER_SCORE_H

#include "sim.h"

void score_reset(Game *g);
void score_add_hit(Game *g);
void score_add_n(Game *g, uint8_t points);
void score_paint_if_dirty(Game *g);

#endif

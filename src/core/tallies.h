#ifndef RAILGUNNER_TALLIES_H
#define RAILGUNNER_TALLIES_H

#include "sim.h"

void tallies_reset(Game *g);
void tallies_note_shot(Game *g);
void tallies_note_kill(Game *g, uint8_t slot);
void tallies_paint_gameover(Game *g);

#endif

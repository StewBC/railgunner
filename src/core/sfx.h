#ifndef RAILGUNNER_SFX_H
#define RAILGUNNER_SFX_H

#include "sim.h"

/* Three-voice one-shots. play claims or steals immediately. No samples. */
void sfx_init(Game *g);
void sfx_play(Game *g, uint8_t id);
void sfx_update(Game *g);

#endif

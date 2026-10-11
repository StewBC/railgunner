#ifndef RAILGUNNER_MUSIC_H
#define RAILGUNNER_MUSIC_H

#include "sim.h"

/* Title loop. start_title keeps running across the GFX and text pages.
 * mute/unmute are for the SFX lease. update consumes one frame, in silence
 * while that voice is muted. */
void music_start_title(Game *g);
void music_stop(Game *g);
void music_update(Game *g);
void music_mute_voice(Game *g, uint8_t voice);
void music_unmute_voice(Game *g, uint8_t voice);

#endif

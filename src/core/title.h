#ifndef RAILGUNNER_TITLE_H
#define RAILGUNNER_TITLE_H

#include "sim.h"

void title_gfx_enter(Game *g);
void title_gfx_update(Game *g);
void title_text_enter(Game *g);
void title_text_update(Game *g);
/* Score-row wheel. Hiscore entry calls the same procs as the text title. */
void title_text_color_scores(Game *g);
void title_text_rotate_colors(Game *g);

#endif

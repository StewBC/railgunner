#ifndef RAILGUNNER_HISCORE_H
#define RAILGUNNER_HISCORE_H

#include "sim.h"

/* RAM table only. hiscore_reset matches the empty assembly proc. */
void hiscore_reset(Game *g);
/* Nonzero when the session score earns a top-10 slot (6502 carry set). */
int hiscore_qualifies(const Game *g);
void hiscore_insert(Game *g);
void hiscore_enter(Game *g);
void hiscore_update(Game *g);

/* Shared with the text title. */
void hs_paint_table(Game *g);

#endif

#ifndef RAILGUNNER_TYPEWRITER_H
#define RAILGUNNER_TYPEWRITER_H

#include "sim.h"

/* Caller sets type_src, then typewriter_init. Update each tick. */
void typewriter_init(Game *g);
void typewriter_update(Game *g);

#endif

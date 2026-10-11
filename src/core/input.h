#ifndef RAILGUNNER_INPUT_H
#define RAILGUNNER_INPUT_H

#include "sim.h"

/* Rising edges from the held buttons. The trace or SDL owns the held
 * state; gameplay only reads the edges this computes. */
void input_poll(Game *g);

#endif

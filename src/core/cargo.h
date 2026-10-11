#ifndef RAILGUNNER_CARGO_H
#define RAILGUNNER_CARGO_H

#include "sim.h"

void cargo_init(Game *g);
/* C reached the rail. Drone slot is still live; the caller retires it. */
void cargo_on_c_impact(Game *g, uint8_t drone);
void cargo_update(Game *g);
void cargo_despawn_sprite(Game *g);
void cargo_reward_level_clear(Game *g);
void cargo_clear_stacks(Game *g);
/* Restamp G/H/I/J glyphs from the stack counts. */
void cargo_paint_ghij(Game *g);
/* Centre-pass while armed. Not called until the player checks the centre. */
void cargo_detonate(Game *g);

#endif

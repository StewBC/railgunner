#ifndef RAILGUNNER_PLAYER_H
#define RAILGUNNER_PLAYER_H

#include "sim.h"

void player_begin_deploy(Game *g);
void player_begin_death_fatal(Game *g);
void player_begin_death_respawn(Game *g);
void player_update(Game *g);
/* 1 when the ship is in the centre gap of its current rail. */
int player_at_intersection(const Game *g);

#endif

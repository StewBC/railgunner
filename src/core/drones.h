#ifndef RAILGUNNER_DRONES_H
#define RAILGUNNER_DRONES_H

#include "sim.h"

void drones_init(Game *g);
void drones_update(Game *g);
void drones_apply_bullet_hit(Game *g, uint8_t slot);
void drones_apply_rail_strikes(Game *g, uint8_t slot);
void drones_clear_field(Game *g);
uint8_t drones_count_active(const Game *g);
void drones_roll_cooldown(Game *g);
/* Shared LFSR. Parcel type rolls use the same state as the launcher. */
uint8_t drones_rng8(Game *g);

#endif

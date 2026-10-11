#ifndef RAILGUNNER_RAIL_H
#define RAILGUNNER_RAIL_H

#include "sim.h"

void rail_reset(Game *g);
void rail_strike_frame_reset(Game *g);
/* Heal-mark wipe. Restores rail colour on marked cells, then zeros the flags. */
void rail_clear_heal_marks(Game *g);
void rail_begin_repair(Game *g);
/* While repair_timer is running: mark the ship column or row, then heal once. */
void rail_repair_tick(Game *g);
/* One A/B strike. dmg_amt is remaining HP, 1..3. Slot is the drone. */
void rail_apply_ab_hit(Game *g, uint8_t slot);

#endif

#ifndef RAILGUNNER_BULLETS_H
#define RAILGUNNER_BULLETS_H

#include "sim.h"

void bullets_init(Game *g);
void bullets_update(Game *g);
/* 0 and *slot set when a bullet occupies col/row/half. */
int bullets_find_at(const Game *g, uint8_t col, uint8_t row, uint8_t half,
                    uint8_t *slot);
void bullets_destroy(Game *g, uint8_t slot);
/* 0 and *half set for a vertical bullet glyph. 1 if the glyph is not one. */
int bullets_half_from_glyph(uint8_t glyph, uint8_t *half);

#endif

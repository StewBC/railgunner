#ifndef RAILGUNNER_OBJECTS_H
#define RAILGUNNER_OBJECTS_H

#include "const.h"

#include <stdint.h>

/* One graphical object. Slot 0 is the player and is never freed.
 * Mux, IRQ event banks, and plan ids are not stored. */
typedef struct Object {
    uint8_t flags;
    uint8_t kind;
    uint8_t x_frac;
    uint8_t x_lo;
    uint8_t x_hi;
    uint8_t y_frac;
    uint8_t y_int;
    uint8_t vx_frac;
    uint8_t vx_lo;
    uint8_t vx_hi;
    uint8_t vy_frac;
    uint8_t vy_int;
    uint8_t sprite_ptr;
    uint8_t sprite_color;
    uint8_t sprite_attr;
    uint8_t hitbox_id;
    uint8_t anim_state;
    uint8_t user;
    uint8_t reserved; /* drone HP */
} Object;

typedef struct Game Game;

void objects_init(Game *g);
void objects_clear_slot(Game *g, uint8_t slot);
/* 0 and *slot set, or OBJ_ERR_POOL_FULL. */
int objects_alloc(Game *g, uint8_t *slot);
void objects_discard_new(Game *g, uint8_t slot);
/* 0, or OBJ_ERR_PLAYER_FIXED for slot 0. Free happens in objects_reap. */
int objects_retire(Game *g, uint8_t slot);
void objects_hide_all(Game *g);
void objects_reap(Game *g);

#endif

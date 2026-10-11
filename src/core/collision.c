#include "collision.h"

#include "bullets.h"
#include "cargo.h"
#include "cells.h"
#include "drones.h"
#include "objects.h"

/* Latch modes and border diagnostics are not ported. test_bullets then
 * test_rail run for every live drone, every tick. */

static uint16_t obj_x(const Object *o) {
    return (uint16_t)(o->x_lo | ((uint16_t)o->x_hi << 8));
}

static int is_drone(const Object *o) {
    return o->kind >= OBJ_DRONE_A && o->kind < OBJ_BONUS;
}

static int is_live(const Object *o) {
    return (o->flags & (OBJF_ALLOCATED | OBJF_RETIRING)) == OBJF_ALLOCATED;
}

static uint8_t px_to_col(uint16_t px) {
    uint16_t col;
    if (px < 24) {
        return 0;
    }
    col = (uint16_t)((px - 24) >> 3);
    if (col >= SCREEN_W) {
        return SCREEN_W - 1;
    }
    return (uint8_t)col;
}

static uint8_t y_to_row_raw(uint8_t y, uint8_t add) {
    uint8_t sum = (uint8_t)(y + add);
    if (sum < 50) {
        return 0;
    }
    return (uint8_t)((sum - 50) >> 3);
}

static int cell_on_rail_cross(uint8_t col, uint8_t row) {
    if (row >= RAIL_ROW_TOP && row <= RAIL_ROW_BOT) {
        return 1;
    }
    if (col >= RAIL_COL_LEFT && col <= RAIL_COL_RIGHT) {
        return 1;
    }
    return 0;
}

static int is_rail_tile(uint8_t glyph) {
    return glyph >= SC_RAIL_A && glyph <= SC_RAIL_X;
}

static void bullet_px(const Game *g, uint8_t slot, uint16_t *bx, uint8_t *by) {
    uint8_t dir = g->bullet_dir[slot];
    uint16_t x;
    uint8_t y;
    if (dir == SPR_DIR_UP || dir == SPR_DIR_DOWN) {
        x = (uint16_t)(24u + (uint16_t)g->bullet_col[slot] * 8u);
        if (g->bullet_half[slot] != 0) {
            x = (uint16_t)(x + 4u);
        }
        y = (uint8_t)(50u + (uint16_t)g->bullet_row[slot] * 8u +
                      (uint16_t)g->bullet_phase[slot] * 2u);
    } else {
        x = (uint16_t)(24u + (uint16_t)g->bullet_col[slot] * 8u +
                       (uint16_t)g->bullet_phase[slot] * 2u);
        y = (uint8_t)(50u + (uint16_t)g->bullet_row[slot] * 8u);
        if (g->bullet_half[slot] != 0) {
            y = (uint8_t)(y + 4u);
        }
    }
    *bx = x;
    *by = y;
}

/* 1 and *slot set when a bullet overlaps the drone hit box. */
static int test_bullets(const Game *g, uint8_t drone, uint8_t *slot) {
    const Object *o = &g->objects[drone];
    uint16_t x = obj_x(o);
    uint16_t hit_x0 = (uint16_t)(x + HIT_X0);
    uint16_t hit_x1 = (uint16_t)(x + HIT_X1);
    uint8_t hit_y0 = (uint8_t)(o->y_int + HIT_Y0);
    uint8_t hit_y1 = (uint8_t)(o->y_int + HIT_Y1);
    uint8_t i;

    for (i = 0; i < BULLET_MAX; i++) {
        uint16_t bx;
        uint16_t bx1;
        uint8_t by;
        uint8_t by1;
        uint8_t dir;
        if (!g->bullet_active[i]) {
            continue;
        }
        dir = g->bullet_dir[i];
        if (dir != SPR_DIR_UP && dir != SPR_DIR_DOWN && dir != SPR_DIR_LEFT &&
            dir != SPR_DIR_RIGHT) {
            continue;
        }
        bullet_px(g, i, &bx, &by);
        bx1 = (uint16_t)(bx + 1u);
        by1 = (uint8_t)(by + 1u);
        if (hit_x1 < bx || bx1 < hit_x0 || by > hit_y1 || by1 < hit_y0) {
            continue;
        }
        *slot = i;
        return 1;
    }
    return 0;
}

/* 1 when a rail tile lies under the hit box. */
static int test_rail(const Game *g, uint8_t drone) {
    const Object *o = &g->objects[drone];
    uint16_t x = obj_x(o);
    uint8_t col0 = px_to_col((uint16_t)(x + HIT_X0));
    uint8_t col1 = px_to_col((uint16_t)(x + HIT_X1));
    uint8_t row0 = y_to_row_raw(o->y_int, HIT_Y0);
    uint8_t row1 = y_to_row_raw(o->y_int, HIT_Y1);
    uint8_t row;
    uint8_t col;

    if (row1 >= SCREEN_H) {
        row1 = SCREEN_H - 1;
    }
    row = row0;
    for (;;) {
        col = col0;
        for (;;) {
            if (col < SCREEN_W && row < SCREEN_H && cell_on_rail_cross(col, row) &&
                is_rail_tile(screen_get_xy(g, col, row))) {
                return 1;
            }
            if (col >= col1) {
                break;
            }
            col++;
        }
        if (row >= row1) {
            break;
        }
        row++;
    }
    return 0;
}

static void rail_arrival_retire(Game *g, uint8_t drone) {
    Object *o = &g->objects[drone];
    if (!g->player_dead && o->kind == OBJ_DRONE_C) {
        cargo_on_c_impact(g, drone);
    } else if (!g->player_dead &&
               (o->kind == OBJ_DRONE_A || o->kind == OBJ_DRONE_B)) {
        drones_apply_rail_strikes(g, drone);
    }
    objects_retire(g, drone);
}

void collision_update(Game *g) {
    uint8_t slot;
    for (slot = 1; slot < OBJECT_CAPACITY; slot++) {
        Object *o = &g->objects[slot];
        uint8_t bullet;
        if (!is_live(o) || !is_drone(o)) {
            continue;
        }
        if (o->anim_state & DRONE_DYING_BIT) {
            continue;
        }
        if (test_bullets(g, slot, &bullet)) {
            bullets_destroy(g, bullet);
            drones_apply_bullet_hit(g, slot);
            continue;
        }
        if (test_rail(g, slot)) {
            rail_arrival_retire(g, slot);
        }
    }
}

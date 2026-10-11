#include "cargo.h"

#include "cells.h"
#include "objects.h"
#include "player.h"
#include "sfx.h"

/* Disc top-left for G, H, I, J. All targets sit in x-hi 0. */
static const uint8_t cargo_tgt_x_lo[4] = {
    CARGO_TGT_X0, CARGO_TGT_X1, CARGO_TGT_X0, CARGO_TGT_X1};
static const uint8_t cargo_tgt_x_hi[4] = {0, 0, 0, 0};
static const uint8_t cargo_tgt_y[4] = {
    CARGO_TGT_Y0, CARGO_TGT_Y0, CARGO_TGT_Y1, CARGO_TGT_Y1};
static const uint8_t hub_glyph[4] = {
    SC_RAIL_G, SC_RAIL_H, SC_RAIL_I, SC_RAIL_J};
static const uint8_t hub_mine_glyph[4] = {
    SC_RAIL_G_MINE, SC_RAIL_H_MINE, SC_RAIL_I_MINE, SC_RAIL_J_MINE};
static const uint8_t hub_col[4] = {
    RAIL_COL_LEFT, RAIL_COL_RIGHT, RAIL_COL_LEFT, RAIL_COL_RIGHT};
static const uint8_t hub_row[4] = {
    RAIL_ROW_TOP, RAIL_ROW_TOP, RAIL_ROW_BOT, RAIL_ROW_BOT};


static void check_arm(Game *g);
static void deposit_centre(Game *g);
static void deposit_target(Game *g);

void cargo_init(Game *g) {
    uint8_t i;
    g->cargo_slot = 0xFF;
    g->ghij_last = 0xFF;
    g->cargo_target = 0;
    g->ghij_rr = 0;
    g->mine_armed = 0;
    for (i = 0; i < 4; i++) {
        g->ghij_stack[i] = 0;
    }
}

static void stack_one(Game *g, uint8_t index) {
    if (g->ghij_stack[index] == 255) {
        return;
    }
    g->ghij_stack[index]++;
}

static void paint_one(Game *g, uint8_t index) {
    uint8_t glyph = hub_glyph[index];
    if (g->ghij_stack[index] >= MINE_STACK_K) {
        glyph = hub_mine_glyph[index];
    }
    screen_put_xy(g, hub_col[index], hub_row[index], glyph);
}

void cargo_paint_ghij(Game *g) {
    uint8_t i;
    for (i = 0; i < 4; i++) {
        paint_one(g, i);
    }
}

static void check_arm(Game *g) {
    uint8_t prior = g->mine_armed;
    uint8_t i;
    for (i = 0; i < 4; i++) {
        if (g->ghij_stack[i] < MINE_STACK_K) {
            g->mine_armed = 0;
            return;
        }
    }
    g->mine_armed = 1;
    if (prior != 0) {
        return;
    }
    sfx_play(g, SFX_MINE);
}

static void deposit_centre(Game *g) {
    uint8_t index = g->ghij_rr;
    stack_one(g, index);
    g->ghij_last = index;
    g->ghij_rr = (uint8_t)((index + 1) & 3);
    cargo_paint_ghij(g);
    check_arm(g);
}

static void deposit_target(Game *g) {
    uint8_t index = g->cargo_target;
    stack_one(g, index);
    g->ghij_last = index;
    cargo_paint_ghij(g);
    check_arm(g);
}

void cargo_despawn_sprite(Game *g) {
    if (g->cargo_slot == 0xFF) {
        return;
    }
    objects_retire(g, g->cargo_slot);
    g->cargo_slot = 0xFF;
}

void cargo_clear_stacks(Game *g) {
    uint8_t i;
    g->mine_armed = 0;
    cargo_despawn_sprite(g);
    for (i = 0; i < 4; i++) {
        g->ghij_stack[i] = 0;
    }
    cargo_paint_ghij(g);
}

void cargo_detonate(Game *g) {
    if (g->player_dead || g->mine_armed == 0) {
        return;
    }
    cargo_clear_stacks(g);
    if (g->lives == 0) {
        player_begin_death_fatal(g);
        return;
    }
    player_begin_death_respawn(g);
}

void cargo_on_c_impact(Game *g, uint8_t drone) {
    uint8_t slot;
    Object *dst;
    Object *src;

    if (g->player_dead) {
        return;
    }
    if (g->cargo_slot != 0xFF) {
        deposit_centre(g);
        return;
    }

    g->cargo_target = g->ghij_rr;
    g->ghij_rr = (uint8_t)((g->ghij_rr + 1) & 3);
    if (objects_alloc(g, &slot) != 0) {
        g->ghij_rr = g->cargo_target;
        deposit_centre(g);
        return;
    }

    g->cargo_slot = slot;
    dst = &g->objects[slot];
    src = &g->objects[drone];
    dst->kind = OBJ_BONUS;
    dst->sprite_ptr = SPR_PTR_CARGO;
    dst->sprite_color = SPR_COLOR_CARGO;
    dst->sprite_attr = 0;
    dst->x_frac = 0;
    dst->y_frac = 0;
    dst->vx_frac = 0;
    dst->vx_lo = 0;
    dst->vx_hi = 0;
    dst->vy_frac = 0;
    dst->vy_int = 0;
    dst->x_lo = src->x_lo;
    dst->x_hi = (uint8_t)(src->x_hi & 1);
    dst->y_int = src->y_int;
    dst->flags = (uint8_t)(OBJF_ALLOCATED | OBJF_RENDER);
}

/* 9-bit X step. A differing x-hi decreases without the overshoot clamp. */
static void x_add(Object *o) {
    uint16_t sum = (uint16_t)o->x_lo + CARGO_SPEED;
    o->x_lo = (uint8_t)sum;
    o->x_hi = (uint8_t)((o->x_hi + (uint8_t)(sum >> 8)) & 1);
}

static void x_sub(Object *o) {
    uint8_t borrow = (uint8_t)(o->x_lo < CARGO_SPEED);
    o->x_lo = (uint8_t)(o->x_lo - CARGO_SPEED);
    o->x_hi = (uint8_t)((uint8_t)(o->x_hi - borrow) & 1);
}

static void snap_x(Object *o, uint8_t target) {
    o->x_lo = cargo_tgt_x_lo[target];
    o->x_hi = cargo_tgt_x_hi[target];
}

/* 1 when x-hi, x-lo, and y all match the claimed hub. */
static int step_toward_target(Game *g) {
    Object *o = &g->objects[g->cargo_slot];
    uint8_t target = g->cargo_target;
    uint8_t y;
    uint8_t ty;

    if (o->x_hi == cargo_tgt_x_hi[target]) {
        if (o->x_lo != cargo_tgt_x_lo[target]) {
            if (o->x_lo < cargo_tgt_x_lo[target]) {
                x_add(o);
                if (o->x_hi == cargo_tgt_x_hi[target] &&
                    o->x_lo > cargo_tgt_x_lo[target]) {
                    snap_x(o, target);
                }
            } else {
                x_sub(o);
                if (o->x_hi == cargo_tgt_x_hi[target] &&
                    o->x_lo < cargo_tgt_x_lo[target]) {
                    snap_x(o, target);
                }
            }
        }
    } else if (o->x_hi < cargo_tgt_x_hi[target]) {
        x_add(o);
        if (o->x_hi == cargo_tgt_x_hi[target] &&
            o->x_lo > cargo_tgt_x_lo[target]) {
            snap_x(o, target);
        }
    } else {
        x_sub(o);
    }

    y = o->y_int;
    ty = cargo_tgt_y[target];
    if (y != ty) {
        if (y < ty) {
            y = (uint8_t)(y + CARGO_SPEED);
            o->y_int = y;
            if (y > ty) {
                o->y_int = ty;
            }
        } else {
            y = (uint8_t)(y - CARGO_SPEED);
            o->y_int = y;
            if (y < ty) {
                o->y_int = ty;
            }
        }
    }

    return o->x_hi == cargo_tgt_x_hi[target] &&
           o->x_lo == cargo_tgt_x_lo[target] && o->y_int == ty;
}

void cargo_update(Game *g) {
    Object *o;
    if (g->cargo_slot == 0xFF) {
        return;
    }
    o = &g->objects[g->cargo_slot];
    if ((o->flags & OBJF_ALLOCATED) == 0) {
        g->cargo_slot = 0xFF;
        return;
    }
    if (!step_toward_target(g)) {
        return;
    }
    cargo_despawn_sprite(g);
    deposit_target(g);
}

void cargo_reward_level_clear(Game *g) {
    int index = -1;
    int scan;
    if (g->ghij_last < 4 && g->ghij_stack[g->ghij_last] != 0) {
        index = g->ghij_last;
    } else {
        for (scan = 3; scan >= 0; scan--) {
            if (g->ghij_stack[scan] != 0) {
                index = scan;
                break;
            }
        }
        if (index < 0) {
            return;
        }
    }
    g->ghij_stack[index]--;
    g->ghij_last = (uint8_t)index;
    if (g->ghij_stack[index] == 0) {
        g->ghij_last = 0xFF;
    }
    cargo_paint_ghij(g);
    check_arm(g);
}

#include "rail.h"

#include "cargo.h"
#include "cells.h"
#include "player.h"
#include "sfx.h"

static const uint8_t d_glyph[4] = {
    SC_RAIL_D, SC_RAIL_D_DMG, SC_RAIL_D_CRIT, SC_SPACE};
static const uint8_t e_glyph[4] = {
    SC_RAIL_E, SC_RAIL_E_DMG, SC_RAIL_E_CRIT, SC_SPACE};
static const uint8_t f_glyph[4] = {
    SC_RAIL_F, SC_RAIL_F_DMG, SC_RAIL_F_CRIT, SC_SPACE};
static const uint8_t a_glyph[4] = {
    SC_RAIL_A, SC_RAIL_A_DMG, SC_RAIL_A_CRIT, SC_SPACE};
static const uint8_t b_glyph[4] = {
    SC_RAIL_B, SC_RAIL_B_DMG, SC_RAIL_B_CRIT, SC_SPACE};
static const uint8_t c_glyph[4] = {
    SC_RAIL_C, SC_RAIL_C_DMG, SC_RAIL_C_CRIT, SC_SPACE};

static uint16_t obj_x(const Object *o) {
    return (uint16_t)(o->x_lo | ((uint16_t)o->x_hi << 8));
}

static int col_is_junction(uint8_t col) {
    return col >= RAIL_COL_LEFT && col <= RAIL_COL_RIGHT;
}

static int row_is_hrail(uint8_t row) {
    return row >= RAIL_ROW_TOP && row <= RAIL_ROW_BOT;
}

/* 8-bit (y + add - 50) >> 3, or 0 when the 8-bit sum is below 50. */
static uint8_t y_to_row(uint8_t y, uint8_t add) {
    uint8_t sum = (uint8_t)(y + add);
    if (sum < 50) {
        return 0;
    }
    return (uint8_t)((sum - 50) >> 3);
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

static uint8_t outer_glyph_idx(uint8_t dmg) {
    if (dmg == 0) {
        return 0;
    }
    if (dmg < 3) {
        return 1;
    }
    if (dmg < 5) {
        return 2;
    }
    return 3;
}

static uint8_t core_glyph_idx(uint8_t dmg) {
    return outer_glyph_idx(dmg);
}

static void draw_d(Game *g, uint8_t col) {
    uint8_t idx;
    if (col_is_junction(col)) {
        return;
    }
    idx = outer_glyph_idx(g->rail_dmg_d[col]);
    screen_put_xy(g, col, RAIL_ROW_TOP, d_glyph[idx]);
}

static void draw_e(Game *g, uint8_t col) {
    uint8_t idx;
    if (col == RAIL_COL_MID) {
        screen_put_xy(g, col, RAIL_ROW_MID, SC_RAIL_X);
        return;
    }
    idx = core_glyph_idx(g->rail_dmg_e[col]);
    screen_put_xy(g, col, RAIL_ROW_MID, e_glyph[idx]);
}

static void draw_f(Game *g, uint8_t col) {
    uint8_t idx;
    if (col_is_junction(col)) {
        return;
    }
    idx = outer_glyph_idx(g->rail_dmg_f[col]);
    screen_put_xy(g, col, RAIL_ROW_BOT, f_glyph[idx]);
}

static void draw_va(Game *g, uint8_t row) {
    uint8_t idx;
    if (row_is_hrail(row)) {
        return;
    }
    idx = outer_glyph_idx(g->rail_dmg_va[row]);
    screen_put_xy(g, RAIL_COL_LEFT, row, a_glyph[idx]);
}

static void draw_vb(Game *g, uint8_t row) {
    uint8_t idx;
    if (row_is_hrail(row)) {
        return;
    }
    idx = core_glyph_idx(g->rail_dmg_vb[row]);
    screen_put_xy(g, RAIL_COL_MID, row, b_glyph[idx]);
}

static void draw_vc(Game *g, uint8_t row) {
    uint8_t idx;
    if (row_is_hrail(row)) {
        return;
    }
    idx = outer_glyph_idx(g->rail_dmg_vc[row]);
    screen_put_xy(g, RAIL_COL_RIGHT, row, c_glyph[idx]);
}

static void damage_e_h_one(Game *g, uint8_t col) {
    if (g->rail_dmg_e[col] >= RAIL_CORE_HP) {
        return;
    }
    g->rail_dmg_e[col]++;
    draw_e(g, col);
    if (g->rail_dmg_e[col] >= RAIL_CORE_HP && !g->player_dead) {
        player_begin_death_fatal(g);
    }
}

static void damage_b_v_one(Game *g, uint8_t row) {
    if (g->rail_dmg_vb[row] >= RAIL_CORE_HP) {
        return;
    }
    g->rail_dmg_vb[row]++;
    draw_vb(g, row);
    if (g->rail_dmg_vb[row] >= RAIL_CORE_HP && !g->player_dead) {
        player_begin_death_fatal(g);
    }
}

static void damage_from_top(Game *g, uint8_t col) {
    while (g->rail_hit_left != 0) {
        g->rail_hit_left--;
        if (col_is_junction(col) || g->rail_dmg_d[col] >= RAIL_OUTER_HP) {
            damage_e_h_one(g, col);
        } else {
            g->rail_dmg_d[col]++;
            draw_d(g, col);
        }
    }
}

static void damage_from_bot(Game *g, uint8_t col) {
    while (g->rail_hit_left != 0) {
        g->rail_hit_left--;
        if (col_is_junction(col) || g->rail_dmg_f[col] >= RAIL_OUTER_HP) {
            damage_e_h_one(g, col);
        } else {
            g->rail_dmg_f[col]++;
            draw_f(g, col);
        }
    }
}

static void damage_from_left(Game *g, uint8_t row) {
    while (g->rail_hit_left != 0) {
        g->rail_hit_left--;
        if (g->rail_dmg_va[row] >= RAIL_OUTER_HP) {
            damage_b_v_one(g, row);
        } else {
            g->rail_dmg_va[row]++;
            draw_va(g, row);
        }
    }
}

static void damage_from_right(Game *g, uint8_t row) {
    while (g->rail_hit_left != 0) {
        g->rail_hit_left--;
        if (g->rail_dmg_vc[row] >= RAIL_OUTER_HP) {
            damage_b_v_one(g, row);
        } else {
            g->rail_dmg_vc[row]++;
            draw_vc(g, row);
        }
    }
}

static void apply_h(Game *g, uint8_t slot) {
    const Object *o = &g->objects[slot];
    uint16_t px = (uint16_t)(obj_x(o) + DRONE_IMPACT_X_OFF);
    uint8_t col = px_to_col(px);
    g->rail_hit_left = g->rail_dmg_amt;
    if (o->user == DRONE_APPROACH_UP) {
        damage_from_bot(g, col);
    } else {
        damage_from_top(g, col);
    }
}

static void apply_v(Game *g, uint8_t slot) {
    const Object *o = &g->objects[slot];
    uint8_t row = y_to_row(o->y_int, DRONE_IMPACT_Y_OFF);
    if (row >= SCREEN_H) {
        row = SCREEN_H - 1;
    }
    if (row_is_hrail(row)) {
        return;
    }
    g->rail_hit_left = g->rail_dmg_amt;
    if (o->user == DRONE_APPROACH_LEFT) {
        damage_from_right(g, row);
    } else {
        damage_from_left(g, row);
    }
}

void rail_reset(Game *g) {
    uint8_t i;
    for (i = 0; i < SCREEN_W; i++) {
        g->rail_dmg_d[i] = 0;
        g->rail_dmg_e[i] = 0;
        g->rail_dmg_f[i] = 0;
        g->heal_mark_d[i] = 0;
        g->heal_mark_e[i] = 0;
        g->heal_mark_f[i] = 0;
    }
    for (i = 0; i < SCREEN_H; i++) {
        g->rail_dmg_va[i] = 0;
        g->rail_dmg_vb[i] = 0;
        g->rail_dmg_vc[i] = 0;
        g->heal_mark_va[i] = 0;
        g->heal_mark_vb[i] = 0;
        g->heal_mark_vc[i] = 0;
    }
    g->rail_dmg_amt = 0;
    g->rail_hit_left = 0;
    g->rail_hit_slot = 0xFF;
}

void rail_strike_frame_reset(Game *g) {
    g->rail_hit_slot = 0xFF;
}

void rail_clear_heal_marks(Game *g) {
    uint8_t i;
    for (i = 0; i < SCREEN_W; i++) {
        if (g->heal_mark_d[i] != 0) {
            screen_color_xy(g, i, RAIL_ROW_TOP, COL_RAIL);
            g->heal_mark_d[i] = 0;
        }
        if (g->heal_mark_e[i] != 0) {
            screen_color_xy(g, i, RAIL_ROW_MID, COL_RAIL);
            g->heal_mark_e[i] = 0;
        }
        if (g->heal_mark_f[i] != 0) {
            screen_color_xy(g, i, RAIL_ROW_BOT, COL_RAIL);
            g->heal_mark_f[i] = 0;
        }
    }
    for (i = 0; i < SCREEN_H; i++) {
        if (g->heal_mark_va[i] != 0) {
            screen_color_xy(g, RAIL_COL_LEFT, i, COL_RAIL);
            g->heal_mark_va[i] = 0;
        }
        if (g->heal_mark_vb[i] != 0) {
            screen_color_xy(g, RAIL_COL_MID, i, COL_RAIL);
            g->heal_mark_vb[i] = 0;
        }
        if (g->heal_mark_vc[i] != 0) {
            screen_color_xy(g, RAIL_COL_RIGHT, i, COL_RAIL);
            g->heal_mark_vc[i] = 0;
        }
    }
}

static void paint_mark_h(Game *g, uint8_t col) {
    screen_color_xy(g, col, RAIL_ROW_TOP, COL_RAIL_HEAL_MARK);
    screen_color_xy(g, col, RAIL_ROW_MID, COL_RAIL_HEAL_MARK);
    screen_color_xy(g, col, RAIL_ROW_BOT, COL_RAIL_HEAL_MARK);
}

static void paint_mark_v(Game *g, uint8_t row) {
    screen_color_xy(g, RAIL_COL_LEFT, row, COL_RAIL_HEAL_MARK);
    screen_color_xy(g, RAIL_COL_MID, row, COL_RAIL_HEAL_MARK);
    screen_color_xy(g, RAIL_COL_RIGHT, row, COL_RAIL_HEAL_MARK);
}

static void mark_player_tiles(Game *g) {
    if (g->player_rail == PLAYER_RAIL_V) {
        uint8_t sum = (uint8_t)(g->objects[0].y_int + 10);
        uint8_t row = (uint8_t)((uint8_t)(sum - 50) >> 3);
        if (row >= SCREEN_H) {
            return;
        }
        g->heal_mark_va[row] = 1;
        g->heal_mark_vb[row] = 1;
        g->heal_mark_vc[row] = 1;
        paint_mark_v(g, row);
        return;
    }
    {
        uint16_t px = obj_x(&g->objects[0]);
        uint8_t col = px_to_col((uint16_t)(px + 12));
        if (col >= SCREEN_W) {
            return;
        }
        g->heal_mark_d[col] = 1;
        g->heal_mark_e[col] = 1;
        g->heal_mark_f[col] = 1;
        paint_mark_h(g, col);
    }
}

static void apply_heal_marks(Game *g) {
    uint8_t i;
    for (i = 0; i < SCREEN_W; i++) {
        if (g->heal_mark_d[i] != 0) {
            if (g->rail_dmg_d[i] != 0) {
                g->rail_dmg_d[i]--;
            }
            draw_d(g, i);
            screen_color_xy(g, i, RAIL_ROW_TOP, COL_RAIL);
            g->heal_mark_d[i] = 0;
        }
        if (g->heal_mark_e[i] != 0) {
            if (g->rail_dmg_e[i] != 0) {
                g->rail_dmg_e[i]--;
            }
            draw_e(g, i);
            screen_color_xy(g, i, RAIL_ROW_MID, COL_RAIL);
            g->heal_mark_e[i] = 0;
        }
        if (g->heal_mark_f[i] != 0) {
            if (g->rail_dmg_f[i] != 0) {
                g->rail_dmg_f[i]--;
            }
            draw_f(g, i);
            screen_color_xy(g, i, RAIL_ROW_BOT, COL_RAIL);
            g->heal_mark_f[i] = 0;
        }
    }
    for (i = 0; i < SCREEN_H; i++) {
        if (g->heal_mark_va[i] != 0) {
            if (g->rail_dmg_va[i] != 0) {
                g->rail_dmg_va[i]--;
            }
            draw_va(g, i);
            screen_color_xy(g, RAIL_COL_LEFT, i, COL_RAIL);
            g->heal_mark_va[i] = 0;
        }
        if (g->heal_mark_vb[i] != 0) {
            if (g->rail_dmg_vb[i] != 0) {
                g->rail_dmg_vb[i]--;
            }
            draw_vb(g, i);
            screen_color_xy(g, RAIL_COL_MID, i, COL_RAIL);
            g->heal_mark_vb[i] = 0;
        }
        if (g->heal_mark_vc[i] != 0) {
            if (g->rail_dmg_vc[i] != 0) {
                g->rail_dmg_vc[i]--;
            }
            draw_vc(g, i);
            screen_color_xy(g, RAIL_COL_RIGHT, i, COL_RAIL);
            g->heal_mark_vc[i] = 0;
        }
    }
    cargo_paint_ghij(g);
}

void rail_repair_tick(Game *g) {
    if (g->repair_timer == 0) {
        return;
    }
    mark_player_tiles(g);
    g->repair_timer--;
    if (g->repair_timer != 0) {
        return;
    }
    sfx_play(g, SFX_HEAL);
    apply_heal_marks(g);
}

void rail_begin_repair(Game *g) {
    rail_clear_heal_marks(g);
    g->repair_timer = REPAIR_MARK_FRAMES;
}

void rail_apply_ab_hit(Game *g, uint8_t slot) {
    uint8_t approach;
    if (slot == g->rail_hit_slot) {
        return;
    }
    g->rail_hit_slot = slot;
    approach = g->objects[slot].user;
    if (approach == DRONE_APPROACH_RIGHT || approach == DRONE_APPROACH_LEFT) {
        apply_v(g, slot);
    } else {
        apply_h(g, slot);
    }
}

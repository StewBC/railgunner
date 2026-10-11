#include "bullets.h"

#include "cells.h"
#include "player.h"
#include "tallies.h"

static uint16_t obj_x(const Object *o) {
    return (uint16_t)(o->x_lo | ((uint16_t)o->x_hi << 8));
}

static void erase_slot(Game *g, uint8_t slot) {
    screen_put_xy(g, g->bullet_col[slot], g->bullet_row[slot], SC_SPACE);
}

static void draw_slot(Game *g, uint8_t slot) {
    uint8_t dir = g->bullet_dir[slot];
    uint8_t base = SC_BULLET_VL0;
    uint8_t glyph;
    if (dir == SPR_DIR_LEFT || dir == SPR_DIR_RIGHT) {
        base = SC_BULLET_HT0;
    }
    glyph = (uint8_t)(base + (g->bullet_half[slot] << 2) + g->bullet_phase[slot]);
    screen_put_xy(g, g->bullet_col[slot], g->bullet_row[slot], glyph);
    screen_color_xy(g, g->bullet_col[slot], g->bullet_row[slot], BULLET_COLOR);
}

static void advance_one(Game *g, uint8_t slot) {
    uint8_t dir;
    g->bullet_hold[slot]--;
    if (g->bullet_hold[slot] != 0) {
        draw_slot(g, slot);
        return;
    }
    g->bullet_hold[slot] = BULLET_HOLD;
    dir = g->bullet_dir[slot];
    if (dir == SPR_DIR_DOWN) {
        if (g->bullet_phase[slot] >= 3) {
            erase_slot(g, slot);
            g->bullet_row[slot]++;
            if (g->bullet_row[slot] >= SCREEN_H) {
                g->bullet_active[slot] = 0;
                return;
            }
            g->bullet_phase[slot] = 0;
        } else {
            g->bullet_phase[slot]++;
        }
    } else if (dir == SPR_DIR_UP) {
        if (g->bullet_phase[slot] == 0) {
            erase_slot(g, slot);
            if (g->bullet_row[slot] <= BULLET_ROW_MIN) {
                g->bullet_active[slot] = 0;
                return;
            }
            g->bullet_row[slot]--;
            g->bullet_phase[slot] = 3;
        } else {
            g->bullet_phase[slot]--;
        }
    } else if (dir == SPR_DIR_LEFT) {
        if (g->bullet_phase[slot] == 0) {
            erase_slot(g, slot);
            if (g->bullet_col[slot] <= BULLET_COL_MIN) {
                g->bullet_active[slot] = 0;
                return;
            }
            g->bullet_col[slot]--;
            g->bullet_phase[slot] = 3;
        } else {
            g->bullet_phase[slot]--;
        }
    } else {
        if (g->bullet_phase[slot] >= 3) {
            erase_slot(g, slot);
            g->bullet_col[slot]++;
            if (g->bullet_col[slot] >= BULLET_COL_MAX + 1) {
                g->bullet_active[slot] = 0;
                return;
            }
            g->bullet_phase[slot] = 0;
        } else {
            g->bullet_phase[slot]++;
        }
    }
    draw_slot(g, slot);
}

static void launch_lane(const Game *g, uint8_t *col, uint8_t *half) {
    uint16_t rel = (uint16_t)(obj_x(&g->objects[0]) + PLAYER_GUN_X_OFF - 24);
    uint8_t cell = (uint8_t)(rel >> 3);
    *half = (rel & 4) ? BULLET_HALF_RIGHT : BULLET_HALF_LEFT;
    if (cell >= SCREEN_W) {
        cell = SCREEN_W - 1;
    }
    *col = cell;
}

static void launch_row(const Game *g, uint8_t *row, uint8_t *half) {
    uint8_t rel = (uint8_t)((uint8_t)(g->objects[0].y_int + PLAYER_GUN_Y_OFF) - 50);
    *half = (rel & 4) ? BULLET_HALF_BOT : BULLET_HALF_TOP;
    *row = (uint8_t)(rel >> 3);
    if (*row >= SCREEN_H) {
        *row = SCREEN_H - 1;
    }
}

static void try_fire(Game *g) {
    uint8_t dir;
    uint8_t col;
    uint8_t row;
    uint8_t half;
    uint8_t phase;
    uint8_t slot;

    if (g->player_dead || g->deploy_timer != 0 || g->fire_lock != 0) {
        return;
    }
    if (g->player_swing_t != 0 || player_at_intersection(g)) {
        return;
    }
    if (!g->input_fire) {
        return;
    }
    dir = g->player_rest_dir;
    if (dir == SPR_DIR_UP) {
        launch_lane(g, &col, &half);
        row = BULLET_LAUNCH_ROW_UP;
        phase = 3;
    } else if (dir == SPR_DIR_DOWN) {
        launch_lane(g, &col, &half);
        row = BULLET_LAUNCH_ROW_DOWN;
        phase = 0;
    } else if (dir == SPR_DIR_LEFT) {
        launch_row(g, &row, &half);
        col = BULLET_LAUNCH_COL_LEFT;
        phase = 3;
    } else if (dir == SPR_DIR_RIGHT) {
        launch_row(g, &row, &half);
        col = BULLET_LAUNCH_COL_RIGHT;
        phase = 0;
    } else {
        return;
    }
    for (slot = 0; slot < BULLET_MAX; slot++) {
        if (!g->bullet_active[slot]) {
            break;
        }
    }
    if (slot == BULLET_MAX) {
        return;
    }
    g->bullet_active[slot] = 1;
    g->bullet_col[slot] = col;
    g->bullet_row[slot] = row;
    g->bullet_half[slot] = half;
    g->bullet_dir[slot] = dir;
    g->bullet_phase[slot] = phase;
    g->bullet_hold[slot] = BULLET_HOLD;
    g->fire_lock = BULLET_CELL_TICKS;
    draw_slot(g, slot);
    tallies_note_shot(g);
}

void bullets_init(Game *g) {
    uint8_t i;
    g->fire_lock = 0;
    for (i = 0; i < BULLET_MAX; i++) {
        g->bullet_active[i] = 0;
    }
}

void bullets_update(Game *g) {
    uint8_t slot;
    if (g->fire_lock != 0) {
        g->fire_lock--;
    }
    for (slot = 0; slot < BULLET_MAX; slot++) {
        if (g->bullet_active[slot]) {
            advance_one(g, slot);
        }
    }
    try_fire(g);
}

int bullets_find_at(const Game *g, uint8_t col, uint8_t row, uint8_t half,
                    uint8_t *slot) {
    uint8_t i;
    for (i = 0; i < BULLET_MAX; i++) {
        if (!g->bullet_active[i]) {
            continue;
        }
        if (g->bullet_col[i] == col && g->bullet_row[i] == row &&
            g->bullet_half[i] == half) {
            *slot = i;
            return 0;
        }
    }
    return 1;
}

void bullets_destroy(Game *g, uint8_t slot) {
    if (!g->bullet_active[slot]) {
        return;
    }
    erase_slot(g, slot);
    g->bullet_active[slot] = 0;
}

int bullets_half_from_glyph(uint8_t glyph, uint8_t *half) {
    if (glyph < SC_BULLET_VL0 || glyph >= SC_BULLET_HT0) {
        return 1;
    }
    *half = (glyph >= SC_BULLET_VR0) ? BULLET_HALF_RIGHT : BULLET_HALF_LEFT;
    return 0;
}

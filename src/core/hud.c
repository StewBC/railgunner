#include "hud.h"

#include "cells.h"
#include "data/tables.h"
#include "score.h"

static void paint_level(Game *g) {
    uint8_t level = g->level;
    uint8_t tens = 0;
    while (level >= 10) {
        level = (uint8_t)(level - 10);
        tens++;
    }
    screen_put_xy(g, HUD_LEVEL_COL, HUD_ROW, (uint8_t)(SC_ZERO + tens));
    screen_put_xy(g, (uint8_t)(HUD_LEVEL_COL + 1), HUD_ROW,
                   (uint8_t)(SC_ZERO + level));
}

/* Full bar drains as kills rise. rem*8 is an 8-bit shift, so a quota of 32
 * wraps and draws an empty bar until the first kill. */
static void paint_progress(Game *g) {
    uint8_t rem;
    uint8_t den;
    uint8_t steps = 0;
    uint8_t scaled;
    uint8_t cell;

    if (g->level_quota == 0) {
        g->level_quota = 16;
    }
    if (g->level_kills > g->level_quota) {
        rem = 0;
    } else {
        rem = (uint8_t)(g->level_quota - g->level_kills);
    }
    den = (uint8_t)(g->level_quota >> 2);
    if (den == 0) {
        den = 1;
    }
    scaled = (uint8_t)(rem << 1);
    scaled = (uint8_t)(scaled << 1);
    scaled = (uint8_t)(scaled << 1);
    while (scaled >= den) {
        scaled = (uint8_t)(scaled - den);
        steps++;
        if (steps >= (uint8_t)(LEVEL_BAR_STEPS + 1)) {
            steps = LEVEL_BAR_STEPS;
            break;
        }
    }

    for (cell = 0; cell < HUD_PROGRESS_LEN; cell++) {
        uint8_t glyph;
        if (steps == 0) {
            glyph = SC_SPACE;
        } else if (steps < 4) {
            if (steps == 1) {
                glyph = SC_UDG_BAR2;
            } else if (steps == 2) {
                glyph = SC_UDG_BAR4;
            } else {
                glyph = SC_UDG_BAR6;
            }
            steps = 0;
        } else {
            glyph = SC_UDG_BAR8;
            steps = (uint8_t)(steps - 4);
        }
        screen_put_xy(g, (uint8_t)(HUD_PROGRESS_COL + cell), HUD_ROW, glyph);
    }
}

static void paint_lives(Game *g) {
    uint8_t i;
    uint8_t n;
    uint8_t col;

    for (i = 0; i < HUD_LIVES_MAX_SHOW; i++) {
        screen_put_xy(g, (uint8_t)(HUD_LIVES_COL + i), HUD_ROW, SC_SPACE);
    }
    if (g->lives == 0) {
        return;
    }
    n = g->lives;
    if (n > HUD_LIVES_MAX_SHOW) {
        n = HUD_LIVES_MAX_SHOW;
    }
    col = (uint8_t)(HUD_LIVES_COL + HUD_LIVES_MAX_SHOW - 1);
    while (n != 0) {
        screen_put_xy(g, col, HUD_ROW, SC_UDG_LIFE);
        col--;
        n--;
    }
}

void hud_paint_full_line(Game *g) {
    screen_print(g, 0, HUD_ROW, str_hud);
    g->score_dirty = 1;
    score_paint_if_dirty(g);
    paint_level(g);
    paint_progress(g);
    paint_lives(g);
}

void hud_paint_status_if_dirty(Game *g) {
    if (g->hud_status_dirty == 0) {
        return;
    }
    g->hud_status_dirty = 0;
    if (g->level_banner_t != 0) {
        return;
    }
    paint_level(g);
    paint_progress(g);
    paint_lives(g);
}

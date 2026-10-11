#include "cells.h"

#include "data/tables.h"
#include "sim.h"

void cells_clear(Game *g) {
    uint8_t row;
    uint8_t col;

    for (row = 0; row < SCREEN_H; row++) {
        for (col = 0; col < SCREEN_W; col++) {
            g->cells[row][col].glyph = 0;
            g->cells[row][col].color = 0;
        }
    }
}

void screen_clear(Game *g) {
    uint8_t row;
    uint8_t col;

    for (row = 0; row < SCREEN_H; row++) {
        for (col = 0; col < SCREEN_W; col++) {
            g->cells[row][col].glyph = SC_SPACE;
            g->cells[row][col].color = COL_WHITE;
        }
    }
}

void screen_put_xy(Game *g, uint8_t col, uint8_t row, uint8_t glyph) {
    if (row >= SCREEN_H || col >= SCREEN_W) {
        return;
    }
    g->cells[row][col].glyph = glyph;
}

uint8_t screen_get_xy(const Game *g, uint8_t col, uint8_t row) {
    if (row >= SCREEN_H || col >= SCREEN_W) {
        return 0;
    }
    return g->cells[row][col].glyph;
}

void screen_color_xy(Game *g, uint8_t col, uint8_t row, uint8_t color) {
    if (row >= SCREEN_H || col >= SCREEN_W) {
        return;
    }
    g->cells[row][col].color = (uint8_t)(color & 0x0F);
}

void screen_color_row(Game *g, uint8_t row, uint8_t color) {
    uint8_t col;
    if (row >= SCREEN_H) {
        return;
    }
    color = (uint8_t)(color & 0x0F);
    for (col = 0; col < SCREEN_W; col++) {
        g->cells[row][col].color = color;
    }
}

uint8_t ascii_to_screen(uint8_t ch) {
    if (ch == ' ') {
        return SC_SPACE;
    }
    if (ch == PET_LEFT_ARROW) {
        return SC_LEFT_ARROW;
    }
    if (ch >= '0' && ch <= '9') {
        return ch;
    }
    if (ch >= 'A' && ch <= 'Z') {
        return (uint8_t)(ch - ('A' - 1));
    }
    return ch;
}

void hud_color_static(Game *g) {
    uint8_t col;
    for (col = 0; col < SCREEN_W; col++) {
        uint8_t color = COL_WHITE;
        if (col >= HUD_PROGRESS_COL &&
            col < HUD_PROGRESS_COL + HUD_PROGRESS_LEN) {
            color = COL_CYAN;
        }
        screen_color_xy(g, col, HUD_ROW, color);
    }
}

/* Static cross. Damage redraw (rail::redraw_from_state) replaces glyphs
 * once the rail module owns the HP. */
void screen_draw_playfield(Game *g) {
    uint8_t row;
    uint8_t col;

    screen_clear(g);
    screen_print(g, 0, HUD_ROW, str_hud);
    hud_color_static(g);

    for (row = 1; row < SCREEN_H; row++) {
        if (row >= RAIL_ROW_TOP && row <= RAIL_ROW_BOT) {
            continue;
        }
        screen_put_xy(g, RAIL_COL_LEFT, row, SC_RAIL_A);
        screen_put_xy(g, RAIL_COL_MID, row, SC_RAIL_B);
        screen_put_xy(g, RAIL_COL_RIGHT, row, SC_RAIL_C);
    }

    for (col = 0; col < SCREEN_W; col++) {
        uint8_t glyph = SC_RAIL_D;
        if (col == RAIL_COL_LEFT) {
            glyph = SC_RAIL_G;
        } else if (col == RAIL_COL_MID) {
            glyph = SC_RAIL_B;
        } else if (col == RAIL_COL_RIGHT) {
            glyph = SC_RAIL_H;
        }
        screen_put_xy(g, col, RAIL_ROW_TOP, glyph);
    }

    for (col = 0; col < SCREEN_W; col++) {
        uint8_t glyph = SC_RAIL_E;
        if (col == RAIL_COL_MID) {
            glyph = SC_RAIL_X;
        }
        screen_put_xy(g, col, RAIL_ROW_MID, glyph);
    }

    for (col = 0; col < SCREEN_W; col++) {
        uint8_t glyph = SC_RAIL_F;
        if (col == RAIL_COL_LEFT) {
            glyph = SC_RAIL_I;
        } else if (col == RAIL_COL_MID) {
            glyph = SC_RAIL_B;
        } else if (col == RAIL_COL_RIGHT) {
            glyph = SC_RAIL_J;
        }
        screen_put_xy(g, col, RAIL_ROW_BOT, glyph);
    }

    for (row = 1; row < SCREEN_H; row++) {
        screen_color_row(g, row, COL_RAIL);
    }
    hud_color_static(g);
}

void screen_print(Game *g, uint8_t col, uint8_t row, const char *text) {
    unsigned i = (unsigned)row * SCREEN_W + col;
    if (row >= SCREEN_H || col >= SCREEN_W) {
        return;
    }
    while (*text != '\0') {
        uint8_t glyph;
        uint8_t r;
        uint8_t c;
        if (i >= SCREEN_SIZE) {
            return;
        }
        glyph = ascii_to_screen((uint8_t)*text++);
        r = (uint8_t)(i / SCREEN_W);
        c = (uint8_t)(i % SCREEN_W);
        g->cells[r][c].glyph = glyph;
        i++;
    }
}

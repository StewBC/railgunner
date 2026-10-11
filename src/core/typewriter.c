#include "typewriter.h"

#include "cells.h"
#include "data/tables.h"

/* frontend/typewriter.asm. One source unit per delay. Gray, then white. */

static void src_advance(Game *g) {
    g->type_src++;
}

static void whiten_prev(Game *g) {
    if (g->type_prev_col == 0xFF) {
        return;
    }
    screen_color_xy(g, g->type_prev_col, g->type_prev_row, COL_WHITE);
}

static void show_continue(Game *g) {
    g->mode_state = STORY_STATE_DONE;
    screen_print(g, STORY_MARGIN_X, 24, str_fire_to_continue);
    screen_color_row(g, 24, COL_LT_GREEN);
    g->mode_timer = MENU_FIRE_GUARD;
}

static void type_one(Game *g) {
    uint8_t ch = (uint8_t)*g->type_src;
    if (ch == 0) {
        whiten_prev(g);
        show_continue(g);
        return;
    }
    if (ch == 0x0A) {
        src_advance(g);
        g->type_col = STORY_MARGIN_X;
        g->type_row++;
        return;
    }
    whiten_prev(g);
    screen_put_xy(g, g->type_col, g->type_row, ascii_to_screen(ch));
    screen_color_xy(g, g->type_col, g->type_row, COL_GRAY);
    g->type_prev_col = g->type_col;
    g->type_prev_row = g->type_row;
    g->type_col++;
    src_advance(g);
}

static void skip_to_end(Game *g) {
    whiten_prev(g);
    g->type_prev_col = 0xFF;
    for (;;) {
        uint8_t ch = (uint8_t)*g->type_src;
        if (ch == 0) {
            break;
        }
        if (ch == 0x0A) {
            src_advance(g);
            g->type_col = STORY_MARGIN_X;
            g->type_row++;
            continue;
        }
        screen_put_xy(g, g->type_col, g->type_row, ascii_to_screen(ch));
        screen_color_xy(g, g->type_col, g->type_row, COL_WHITE);
        g->type_col++;
        src_advance(g);
    }
    show_continue(g);
}

void typewriter_init(Game *g) {
    g->type_col = STORY_MARGIN_X;
    g->type_row = STORY_START_Y;
    g->type_prev_col = 0xFF;
    g->type_prev_row = 0xFF;
    g->mode_state = STORY_STATE_TYPING;
    g->mode_timer = STORY_TYPE_DELAY;
}

void typewriter_update(Game *g) {
    if (g->mode_state == STORY_STATE_DONE) {
        if (g->mode_timer != 0) {
            g->mode_timer--;
        }
        return;
    }
    if (g->input_fire_edge) {
        skip_to_end(g);
        return;
    }
    if (g->mode_timer != 0) {
        g->mode_timer--;
        return;
    }
    g->mode_timer = STORY_TYPE_DELAY;
    type_one(g);
}

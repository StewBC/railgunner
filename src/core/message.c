#include "message.h"

#include "cells.h"
#include "data/tables.h"
#include "hud.h"

#include <string.h>

static uint8_t wave_idx(const Game *g) {
    uint8_t level = g->level;
    if (level == 0) {
        level = 1;
    }
    if (level > MAX_LEVEL) {
        level = MAX_LEVEL;
    }
    return (uint8_t)(level - 1);
}

static void paint_banner_color(Game *g) {
    uint8_t elapsed;
    uint8_t index = 0;
    uint8_t col;
    uint8_t left;
    uint8_t color;

    if (g->banner_len == 0) {
        return;
    }
    elapsed = (uint8_t)(LEVEL_BANNER_FRAMES - g->level_banner_t);
    while (elapsed >= BANNER_COLOR_HOLD && index < (uint8_t)(BANNER_NUM_COLORS - 1)) {
        elapsed = (uint8_t)(elapsed - BANNER_COLOR_HOLD);
        index++;
    }
    color = score_color_table[index];
    col = g->banner_col;
    left = g->banner_len;
    while (left != 0) {
        screen_color_xy(g, col, HUD_ROW, color);
        col++;
        left--;
    }
}

void message_clear_banner_zone(Game *g) {
    uint8_t col;
    for (col = HUD_BANNER_COL; col < HUD_BANNER_END; col++) {
        screen_put_xy(g, col, HUD_ROW, SC_SPACE);
        screen_color_xy(g, col, HUD_ROW, COL_WHITE);
    }
}

static uint8_t fit_pad(uint8_t text_len) {
    uint8_t pad = BANNER_PAD_SPACES;
    for (;;) {
        uint8_t sum;
        if ((uint16_t)text_len + pad > 255) {
            return 0;
        }
        sum = (uint8_t)(text_len + pad);
        if ((uint16_t)sum + pad > 255 ||
            (uint8_t)(sum + pad) >= (uint8_t)(HUD_BANNER_ZONE_LEN + 1)) {
            if (pad == 0) {
                return 0;
            }
            pad--;
            continue;
        }
        return pad;
    }
}

void message_show_rank_banner(Game *g) {
    uint8_t index = wave_idx(g);
    const char *nicety = nicety_tbl[index];
    const char *rank = rank_title_tbl[index];
    uint8_t nicety_len = (uint8_t)strlen(nicety);
    uint8_t rank_len = (uint8_t)strlen(rank);
    uint16_t sum = (uint16_t)nicety_len + rank_len + 2;
    uint8_t text_len;
    uint8_t pad;
    uint8_t col;
    uint8_t i;

    message_clear_banner_zone(g);
    if (sum > HUD_BANNER_ZONE_LEN) {
        text_len = HUD_BANNER_ZONE_LEN;
    } else {
        text_len = (uint8_t)sum;
    }
    pad = fit_pad(text_len);
    g->banner_len = (uint8_t)(text_len + pad + pad);
    g->banner_col =
        (uint8_t)(HUD_BANNER_COL + ((HUD_BANNER_ZONE_LEN - g->banner_len) >> 1));

    col = g->banner_col;
    for (i = 0; i < pad; i++) {
        screen_put_xy(g, col, HUD_ROW, SC_SPACE);
        col++;
    }
    screen_print(g, col, HUD_ROW, nicety);
    col = (uint8_t)(col + nicety_len);
    screen_put_xy(g, col, HUD_ROW, ',');
    col++;
    screen_put_xy(g, col, HUD_ROW, SC_SPACE);
    col++;
    screen_print(g, col, HUD_ROW, rank);

    if (pad != 0) {
        col = (uint8_t)(g->banner_col + g->banner_len - pad);
        for (i = 0; i < pad; i++) {
            screen_put_xy(g, col, HUD_ROW, SC_SPACE);
            col++;
        }
    }
    paint_banner_color(g);
}

void message_tick_banner_color(Game *g) {
    if (g->level_banner_t == 0) {
        return;
    }
    paint_banner_color(g);
}

void message_restore_hud_line(Game *g) {
    hud_paint_full_line(g);
    hud_color_static(g);
}

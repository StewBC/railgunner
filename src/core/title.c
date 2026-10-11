#include "title.h"

#include "cells.h"
#include "data/tables.h"
#include "hiscore.h"
#include "mode.h"
#include "music.h"
#include "sfx.h"

/* Text-title rows and centred columns. From frontend/title.asm. */
#define TT_ROW_TITLE 0
#define TT_ROW_FIRE 16
#define TT_ROW_STORY 17
#define TT_ROW_INSTR 18
#define TT_ROW_CODE 20
#define TT_ROW_AI 21
#define TT_ROW_PROD 23
#define TT_ROW_NAME 24

#define TT_COL_TITLE 14
#define TT_COL_FIRE 14
#define TT_COL_STORY 14
#define TT_COL_INSTR 11
#define TT_COL_CODE 13
#define TT_COL_AI 9
#define TT_COL_PROD 14
#define TT_COL_NAME 10

static void attract_reset_timer(Game *g) {
    g->attract_lo = (uint8_t)(ATTRACT_FRAMES & 0xFF);
    g->attract_hi = (uint8_t)((ATTRACT_FRAMES >> 8) & 0xFF);
}

/* 1 when the countdown hits 0 on this call, or was already 0. */
static int attract_tick(Game *g) {
    if ((g->attract_lo | g->attract_hi) == 0) {
        return 1;
    }
    if (g->attract_lo == 0) {
        g->attract_hi--;
    }
    g->attract_lo--;
    if ((g->attract_lo | g->attract_hi) == 0) {
        return 1;
    }
    return 0;
}

void title_text_color_scores(Game *g) {
    uint8_t row_i;
    for (row_i = 0; row_i < 10; row_i++) {
        uint8_t idx = (uint8_t)(g->score_color_phase + row_i);
        while (idx >= 10) {
            idx = (uint8_t)(idx - 10);
        }
        screen_color_row(g, (uint8_t)(HS_ROW_SCORE0 + row_i), score_color_table[idx]);
    }
}

void title_text_rotate_colors(Game *g) {
    g->score_color_tick++;
    if (g->score_color_tick < SCORE_COLOR_PERIOD) {
        return;
    }
    g->score_color_tick = 0;
    g->score_color_phase--;
    if (g->score_color_phase >= 10) {
        g->score_color_phase = 9;
    }
    title_text_color_scores(g);
}

void title_gfx_enter(Game *g) {
    g->present = PRESENT_HIRES_TITLE;
    attract_reset_timer(g);
    g->mode_timer = MENU_FIRE_GUARD;
    music_start_title(g);
}

void title_gfx_update(Game *g) {
    if (g->mode_timer != 0) {
        g->mode_timer--;
    } else if (g->input_fire_edge) {
        sfx_play(g, SFX_UI_FIRE);
        mode_set(g, MODE_TITLE_TEXT);
        return;
    }
    if (attract_tick(g)) {
        mode_set(g, MODE_TITLE_TEXT);
    }
}

void title_text_enter(Game *g) {
    g->present = PRESENT_TEXT;
    screen_clear(g);

    screen_print(g, TT_COL_TITLE, TT_ROW_TITLE, str_title);
    screen_color_row(g, TT_ROW_TITLE, COL_YELLOW);

    hs_paint_table(g);

    screen_print(g, TT_COL_FIRE, TT_ROW_FIRE, str_fire_to_play);
    screen_color_row(g, TT_ROW_FIRE, COL_WHITE);

    screen_print(g, TT_COL_STORY, TT_ROW_STORY, str_s_for_story);
    screen_color_row(g, TT_ROW_STORY, COL_LT_GREEN);

    screen_print(g, TT_COL_INSTR, TT_ROW_INSTR, str_i_for_instructions);
    screen_color_row(g, TT_ROW_INSTR, COL_LT_GREEN);

    screen_print(g, TT_COL_CODE, TT_ROW_CODE, str_code_art_by);
    screen_color_row(g, TT_ROW_CODE, COL_LT_GRAY);

    screen_print(g, TT_COL_AI, TT_ROW_AI, str_credits_ai);
    screen_color_row(g, TT_ROW_AI, COL_LT_BLUE);

    screen_print(g, TT_COL_PROD, TT_ROW_PROD, str_produced_by);
    screen_color_row(g, TT_ROW_PROD, COL_LT_GRAY);

    screen_print(g, TT_COL_NAME, TT_ROW_NAME, str_producer);
    screen_color_row(g, TT_ROW_NAME, COL_PURPLE);

    g->score_color_phase = 0;
    g->score_color_tick = 0;
    title_text_color_scores(g);

    attract_reset_timer(g);
    g->mode_timer = MENU_FIRE_GUARD;
    music_start_title(g);
}

void title_text_update(Game *g) {
    title_text_rotate_colors(g);
    if (g->mode_timer != 0) {
        g->mode_timer--;
    } else if (g->input_fire_edge) {
        sfx_play(g, SFX_UI_FIRE);
        mode_set(g, MODE_GAME_INIT);
        return;
    } else if (g->input_key_s_edge) {
        sfx_play(g, SFX_UI_FIRE);
        mode_set(g, MODE_STORY);
        return;
    } else if (g->input_key_i_edge) {
        sfx_play(g, SFX_UI_FIRE);
        mode_set(g, MODE_INSTRUCTIONS);
        return;
    }
    if (attract_tick(g)) {
        mode_set(g, MODE_TITLE_GFX);
    }
}

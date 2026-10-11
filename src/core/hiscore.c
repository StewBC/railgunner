#include "hiscore.h"

#include "cells.h"
#include "data/tables.h"
#include "mode.h"
#include "sfx.h"
#include "title.h"

/* frontend/hiscore.asm. Lines and the prompt are the mutable data segment. */

static const uint8_t hs_charset[HS_CHARSET_LEN] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    '.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ' ',
    PET_LEFT_ARROW
};

static uint32_t session_score(const Game *g) {
    return (uint32_t)g->score0 | ((uint32_t)g->score1 << 8) |
           ((uint32_t)g->score2 << 16);
}

static uint32_t hs_parse_score(const char *line) {
    uint32_t work = 0;
    uint8_t i;
    for (i = 0; i < 6; i++) {
        work = work * 10u + (uint8_t)(line[HS_SCORE_OFF + i] - '0');
    }
    return work;
}

static uint8_t hs_session_waves(const Game *g) {
    if (g->victory) {
        return MAX_LEVEL;
    }
    if (g->level == 0) {
        return 0;
    }
    return (uint8_t)(g->level - 1);
}

static void hs_write_u8_2(char *line, uint8_t off, uint8_t value) {
    uint8_t ones = value;
    uint8_t tens = 0;
    uint8_t orig = value;
    while (ones >= 10) {
        ones = (uint8_t)(ones - 10);
    }
    line[off + 1] = (char)('0' + ones);
    while (orig >= 10) {
        orig = (uint8_t)(orig - 10);
        tens++;
    }
    line[off] = (char)('0' + tens);
}

static void hs_write_rank(char *line, uint8_t waves) {
    uint8_t i;
    const char *title;
    if (waves == 0) {
        for (i = 0; i < HS_RANK_LEN; i++) {
            line[HS_RANK_OFF + i] = ' ';
        }
        return;
    }
    if (waves > MAX_LEVEL) {
        waves = MAX_LEVEL;
    }
    title = rank_title_tbl[waves - 1];
    for (i = 0; i < HS_RANK_LEN; i++) {
        if (title[i] == '\0') {
            break;
        }
        line[HS_RANK_OFF + i] = title[i];
    }
    for (; i < HS_RANK_LEN; i++) {
        line[HS_RANK_OFF + i] = ' ';
    }
}

/* Place loops stop once the digit reaches 10, matching the assembly. */
static void hs_write_u16_5(char *line, uint8_t off, uint16_t value) {
    static const uint16_t place[5] = {10000, 1000, 100, 10, 1};
    uint8_t p;
    for (p = 0; p < 5; p++) {
        uint8_t digit = 0;
        while (value >= place[p] && digit < 10) {
            value = (uint16_t)(value - place[p]);
            digit++;
        }
        line[off + p] = (char)('0' + digit);
    }
}

static void hs_write_score_6(char *line, uint8_t off, const Game *g) {
    static const uint32_t place[6] = {100000u, 10000u, 1000u, 100u, 10u, 1u};
    uint32_t value = session_score(g);
    uint8_t p;
    for (p = 0; p < 6; p++) {
        uint8_t digit = 0;
        while (value >= place[p] && digit < 10) {
            value -= place[p];
            digit++;
        }
        line[off + p] = (char)('0' + digit);
    }
}

static void hs_paint_prompt(Game *g) {
    screen_print(g, HS_COL_PROMPT, HS_ROW_PROMPT, str_hs_prompt);
    screen_color_row(g, HS_ROW_PROMPT, COL_WHITE);
}

static void hs_store_char(Game *g, uint8_t ch) {
    char *line = hs_lines[g->hs_rank];
    line[HS_INITIALS_OFF + g->hs_cursor] = (char)ch;
    str_hs_prompt[HS_PROMPT_NAME_OFF + g->hs_cursor] = (char)ch;
}

static void hs_apply_char(Game *g) {
    hs_store_char(g, hs_charset[g->hs_char_idx]);
}

static void hs_clear_right(Game *g) {
    uint8_t i;
    if (g->hs_cursor >= 2) {
        return;
    }
    for (i = (uint8_t)(g->hs_cursor + 1); i < 3; i++) {
        hs_lines[g->hs_rank][HS_INITIALS_OFF + i] = '-';
        str_hs_prompt[HS_PROMPT_NAME_OFF + i] = '-';
    }
}

static void hs_load_char_idx(Game *g) {
    uint8_t ch = (uint8_t)hs_lines[g->hs_rank][HS_INITIALS_OFF + g->hs_cursor];
    uint8_t i;
    g->hs_char_idx = 0;
    for (i = 0; i < HS_CHARSET_LEN; i++) {
        if (hs_charset[i] == ch) {
            g->hs_char_idx = i;
            return;
        }
    }
}

static void hs_refresh_name(Game *g) {
    screen_print(g, HS_COL_TABLE, (uint8_t)(HS_ROW_SCORE0 + g->hs_rank),
                 hs_lines[g->hs_rank]);
    hs_paint_prompt(g);
}

static void hs_paint_name_colors(Game *g) {
    uint8_t i;
    if (g->hs_phase != 0) {
        return;
    }
    for (i = 0; i < 3; i++) {
        uint8_t color = (i == g->hs_cursor) ? COL_YELLOW : COL_WHITE;
        screen_color_xy(g,
                        (uint8_t)(HS_COL_TABLE + HS_INITIALS_OFF + i),
                        (uint8_t)(HS_ROW_SCORE0 + g->hs_rank), color);
        screen_color_xy(g,
                        (uint8_t)(HS_COL_PROMPT + HS_PROMPT_NAME_OFF + i),
                        HS_ROW_PROMPT, color);
    }
}

static void hs_blank_row(Game *g, uint8_t row) {
    uint8_t col;
    for (col = 0; col < SCREEN_W; col++) {
        screen_put_xy(g, col, row, SC_SPACE);
    }
}

static void hs_step_up(Game *g) {
    g->hs_char_idx++;
    if (g->hs_char_idx >= HS_CHARSET_LEN) {
        g->hs_char_idx = 0;
    }
    sfx_play(g, SFX_HS_TICK);
    hs_apply_char(g);
    hs_refresh_name(g);
}

static void hs_step_down(Game *g) {
    if (g->hs_char_idx == 0) {
        g->hs_char_idx = HS_CHARSET_LEN;
    }
    g->hs_char_idx--;
    sfx_play(g, SFX_HS_TICK);
    hs_apply_char(g);
    hs_refresh_name(g);
}

static void hs_handle_dirs(Game *g) {
    if ((g->input_dirs & (JOY_UP | JOY_DOWN)) == 0) {
        g->hs_repeat_t = 0;
        return;
    }
    if ((g->input_dirs & JOY_UP) != 0) {
        if ((g->hs_dirs_prev & JOY_UP) == 0) {
            hs_step_up(g);
            g->hs_repeat_t = HS_REPEAT_DELAY;
            return;
        }
        if (g->hs_repeat_t == 0) {
            hs_step_up(g);
            g->hs_repeat_t = HS_REPEAT_RATE;
            return;
        }
        g->hs_repeat_t--;
        if (g->hs_repeat_t == 0) {
            hs_step_up(g);
            g->hs_repeat_t = HS_REPEAT_RATE;
        }
        return;
    }
    if ((g->input_dirs & JOY_DOWN) == 0) {
        return;
    }
    if ((g->hs_dirs_prev & JOY_DOWN) == 0) {
        hs_step_down(g);
        g->hs_repeat_t = HS_REPEAT_DELAY;
        return;
    }
    if (g->hs_repeat_t == 0) {
        hs_step_down(g);
        g->hs_repeat_t = HS_REPEAT_RATE;
        return;
    }
    g->hs_repeat_t--;
    if (g->hs_repeat_t == 0) {
        hs_step_down(g);
        g->hs_repeat_t = HS_REPEAT_RATE;
    }
}

static void hs_handle_fire(Game *g) {
    if (!g->input_fire_edge) {
        return;
    }
    sfx_play(g, SFX_UI_FIRE);
    if (g->hs_char_idx == HS_CHAR_BACK) {
        if (g->hs_cursor == 0) {
            return;
        }
        hs_store_char(g, '-');
        g->hs_cursor--;
        hs_clear_right(g);
        hs_load_char_idx(g);
        hs_refresh_name(g);
        return;
    }
    if (g->hs_cursor == 2) {
        hs_apply_char(g);
        hs_refresh_name(g);
        hs_blank_row(g, HS_ROW_PROMPT);
        hs_blank_row(g, HS_ROW_HELP);
        g->hs_phase = 1;
        g->mode_timer = HS_HOLD_FRAMES;
        title_text_color_scores(g);
        return;
    }
    g->hs_cursor++;
    hs_apply_char(g);
    hs_clear_right(g);
    hs_refresh_name(g);
}

void hs_paint_table(Game *g) {
    uint8_t i;

    screen_print(g, HS_COL_HEROES, HS_ROW_HEROES, str_past_heroes);
    screen_color_row(g, HS_ROW_HEROES, COL_CYAN);

    screen_print(g, HS_COL_TABLE, HS_ROW_HEAD, str_hs_header);
    screen_color_row(g, HS_ROW_HEAD, COL_WHITE);

    for (i = 0; i < 10; i++) {
        screen_print(g, HS_COL_TABLE, (uint8_t)(HS_ROW_SCORE0 + i), hs_lines[i]);
    }
}

void hiscore_reset(Game *g) {
    (void)g;
}

int hiscore_qualifies(const Game *g) {
    uint32_t session = session_score(g);
    uint8_t count = 0;
    uint8_t i;
    for (i = 0; i < 10; i++) {
        if (hs_parse_score(hs_lines[i]) >= session) {
            count++;
        }
    }
    return count < 10;
}

void hiscore_insert(Game *g) {
    uint32_t session = session_score(g);
    uint8_t draw_i;
    char *line;
    uint8_t waves;

    g->hs_rank = 0;
    while (g->hs_rank < 10) {
        if (hs_parse_score(hs_lines[g->hs_rank]) < session) {
            break;
        }
        g->hs_rank++;
    }
    if (g->hs_rank >= 10) {
        g->hs_rank = 9;
    }

    draw_i = 9;
    while (draw_i != g->hs_rank) {
        char *dst = hs_lines[draw_i];
        char *src = hs_lines[draw_i - 1];
        uint8_t off;
        for (off = HS_INITIALS_OFF; off < HS_LINE_LEN; off++) {
            dst[off] = src[off];
        }
        draw_i--;
    }

    line = hs_lines[g->hs_rank];
    line[HS_INITIALS_OFF] = 'A';
    line[HS_INITIALS_OFF + 1] = '-';
    line[HS_INITIALS_OFF + 2] = '-';
    waves = hs_session_waves(g);
    hs_write_u8_2(line, HS_WAVE_OFF, waves);
    hs_write_rank(line, waves);
    hs_write_u16_5(line, HS_SHOTS_OFF, g->tally_shots);
    hs_write_score_6(line, HS_SCORE_OFF, g);
}

void hiscore_enter(Game *g) {
    hiscore_insert(g);
    g->present = PRESENT_TEXT;
    screen_clear(g);

    screen_print(g, HS_COL_CONGRATS, HS_ROW_CONGRATS, str_hs_congrats);
    screen_color_row(g, HS_ROW_CONGRATS, COL_YELLOW);

    hs_paint_table(g);

    screen_print(g, HS_COL_NEW, HS_ROW_NEW, str_hs_new_score);
    screen_color_row(g, HS_ROW_NEW, COL_LT_GREEN);

    str_hs_prompt[HS_PROMPT_NAME_OFF] = 'A';
    str_hs_prompt[HS_PROMPT_NAME_OFF + 1] = '-';
    str_hs_prompt[HS_PROMPT_NAME_OFF + 2] = '-';
    hs_paint_prompt(g);

    screen_print(g, HS_COL_HELP, HS_ROW_HELP, str_hs_help);
    screen_color_row(g, HS_ROW_HELP, COL_LT_GRAY);

    g->hs_cursor = 0;
    g->hs_char_idx = 0;
    g->hs_phase = 0;
    g->hs_dirs_prev = 0;
    g->hs_repeat_t = 0;
    g->score_color_phase = 0;
    g->score_color_tick = 0;
    title_text_color_scores(g);
    hs_paint_name_colors(g);
    g->mode_timer = MENU_FIRE_GUARD;
}

void hiscore_update(Game *g) {
    if (g->hs_phase != 0) {
        title_text_rotate_colors(g);
        if (g->mode_timer != 0) {
            g->mode_timer--;
        }
        if (g->input_fire_edge || g->mode_timer == 0) {
            mode_set(g, MODE_TITLE_TEXT);
        }
        return;
    }
    if (g->mode_timer != 0) {
        g->mode_timer--;
        title_text_rotate_colors(g);
        hs_paint_name_colors(g);
        g->hs_dirs_prev = g->input_dirs;
        return;
    }
    title_text_rotate_colors(g);
    hs_handle_dirs(g);
    hs_handle_fire(g);
    hs_paint_name_colors(g);
    g->hs_dirs_prev = g->input_dirs;
}

#include "tallies.h"

#include "cells.h"
#include "data/tables.h"

/* game/tallies.asm paint_gameover. Rows and columns are the assembly's. */
#define GO_ROW_GAMEOVER 1
#define GO_ROW_RESULTS 3
#define GO_ROW_SCORE 6
#define GO_ROW_RANK 7
#define GO_ROW_WAVES 8
#define GO_ROW_SHOTS 9
#define GO_ROW_DEST 11
#define GO_ROW_C 12
#define GO_ROW_B 13
#define GO_ROW_A 14
#define GO_ROW_FIRE 22
#define GO_LABEL_END 15
#define GO_VALUE_COL 21

static void sat_inc(uint16_t *n) {
    if (*n != 0xFFFFu) {
        (*n)++;
    }
}

void tallies_reset(Game *g) {
    g->tally_shots = 0;
    g->tally_kill_a = 0;
    g->tally_kill_b = 0;
    g->tally_kill_c = 0;
}

void tallies_note_shot(Game *g) {
    sat_inc(&g->tally_shots);
}

void tallies_note_kill(Game *g, uint8_t slot) {
    uint8_t kind = g->objects[slot].kind;
    if (kind == OBJ_DRONE_A) {
        sat_inc(&g->tally_kill_a);
    } else if (kind == OBJ_DRONE_B) {
        sat_inc(&g->tally_kill_b);
    } else if (kind == OBJ_DRONE_C) {
        sat_inc(&g->tally_kill_c);
    }
}

static uint8_t cstr_len(const char *s) {
    uint8_t n = 0;
    while (s[n] != '\0') {
        n++;
    }
    return n;
}

static void print_label_ra(Game *g, uint8_t row, const char *text) {
    uint8_t len = cstr_len(text);
    screen_print(g, (uint8_t)((GO_LABEL_END + 1) - len), row, text);
}

/* Same wave count as hiscore's hs_session_waves. Kept separate, as in the asm. */
static uint8_t session_waves(const Game *g) {
    if (g->victory) {
        return MAX_LEVEL;
    }
    if (g->level == 0) {
        return 0;
    }
    return (uint8_t)(g->level - 1);
}

/* Place loops stop once the digit reaches 10, matching the assembly. */
static void print_score6(Game *g, uint8_t row) {
    static const uint32_t place[6] = {100000u, 10000u, 1000u, 100u, 10u, 1u};
    uint32_t value = (uint32_t)g->score0 | ((uint32_t)g->score1 << 8) |
                     ((uint32_t)g->score2 << 16);
    uint8_t col = GO_VALUE_COL;
    uint8_t p;
    for (p = 0; p < 6; p++) {
        uint8_t digit = 0;
        while (value >= place[p] && digit < 10) {
            value -= place[p];
            digit++;
        }
        screen_put_xy(g, col, row, (uint8_t)(SC_ZERO + digit));
        col++;
    }
}

static void print_u16_at(Game *g, uint8_t col, uint8_t row, uint16_t value) {
    static const uint16_t place[5] = {10000, 1000, 100, 10, 1};
    uint8_t started = 0;
    uint8_t p;
    for (p = 0; p < 5; p++) {
        uint8_t digit = 0;
        if (p == 4) {
            started = 1;
        }
        while (value >= place[p] && digit < 10) {
            value = (uint16_t)(value - place[p]);
            digit++;
        }
        if (!started) {
            if (digit == 0) {
                continue;
            }
            started = 1;
        }
        screen_put_xy(g, col, row, (uint8_t)(SC_ZERO + digit));
        col++;
    }
}

void tallies_paint_gameover(Game *g) {
    uint8_t waves;
    if (g->victory) {
        screen_print(g, 16, GO_ROW_GAMEOVER, str_victory);
        screen_color_row(g, GO_ROW_GAMEOVER, COL_GREEN);
    } else {
        screen_print(g, 15, GO_ROW_GAMEOVER, str_game_over);
        screen_color_row(g, GO_ROW_GAMEOVER, COL_RED);
    }

    screen_print(g, 13, GO_ROW_RESULTS, str_go_results);
    screen_color_row(g, GO_ROW_RESULTS, COL_YELLOW);

    print_label_ra(g, GO_ROW_SCORE, str_go_score);
    print_score6(g, GO_ROW_SCORE);
    screen_color_row(g, GO_ROW_SCORE, COL_WHITE);

    print_label_ra(g, GO_ROW_RANK, str_go_rank);
    waves = session_waves(g);
    if (waves != 0) {
        if (waves > MAX_LEVEL) {
            waves = MAX_LEVEL;
        }
        screen_print(g, GO_VALUE_COL, GO_ROW_RANK, rank_title_tbl[waves - 1]);
    }
    screen_color_row(g, GO_ROW_RANK, COL_WHITE);

    print_label_ra(g, GO_ROW_WAVES, str_go_waves);
    print_u16_at(g, GO_VALUE_COL, GO_ROW_WAVES, session_waves(g));
    screen_color_row(g, GO_ROW_WAVES, COL_WHITE);

    print_label_ra(g, GO_ROW_SHOTS, str_go_shots);
    print_u16_at(g, GO_VALUE_COL, GO_ROW_SHOTS, g->tally_shots);
    screen_color_row(g, GO_ROW_SHOTS, COL_WHITE);

    screen_print(g, 14, GO_ROW_DEST, str_go_destruction);
    screen_color_row(g, GO_ROW_DEST, COL_ORANGE);

    print_label_ra(g, GO_ROW_C, str_go_mine);
    print_u16_at(g, GO_VALUE_COL, GO_ROW_C, g->tally_kill_c);
    screen_color_row(g, GO_ROW_C, COL_WHITE);

    print_label_ra(g, GO_ROW_B, str_go_medium);
    print_u16_at(g, GO_VALUE_COL, GO_ROW_B, g->tally_kill_b);
    screen_color_row(g, GO_ROW_B, COL_WHITE);

    print_label_ra(g, GO_ROW_A, str_go_heavy);
    print_u16_at(g, GO_VALUE_COL, GO_ROW_A, g->tally_kill_a);
    screen_color_row(g, GO_ROW_A, COL_WHITE);

    screen_print(g, 15, GO_ROW_FIRE, str_press_fire);
    screen_color_row(g, GO_ROW_FIRE, COL_YELLOW);
}

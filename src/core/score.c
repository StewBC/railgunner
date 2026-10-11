#include "score.h"

#include "cells.h"

/* Place values 100000, 10000, 1000, 100, 10, 1 as 24-bit lo/mid/hi. */
static const uint8_t place_lo[6] = {0xA0, 0x10, 0xE8, 0x64, 0x0A, 0x01};
static const uint8_t place_mid[6] = {0x86, 0x27, 0x03, 0x00, 0x00, 0x00};
static const uint8_t place_hi[6] = {0x01, 0x00, 0x00, 0x00, 0x00, 0x00};

void score_reset(Game *g) {
    g->score0 = 0;
    g->score1 = 0;
    g->score2 = 0;
    g->score_dirty = 0;
}

void score_add_n(Game *g, uint8_t points) {
    uint16_t sum = (uint16_t)g->score0 + points;
    g->score0 = (uint8_t)sum;
    sum = (uint16_t)g->score1 + (sum >> 8);
    g->score1 = (uint8_t)sum;
    sum = (uint16_t)g->score2 + (sum >> 8);
    g->score2 = (uint8_t)sum;
    if (g->score2 > SCORE_MAX2 ||
        (g->score2 == SCORE_MAX2 && g->score1 > SCORE_MAX1) ||
        (g->score2 == SCORE_MAX2 && g->score1 == SCORE_MAX1 &&
         g->score0 > SCORE_MAX0)) {
        g->score0 = SCORE_MAX0;
        g->score1 = SCORE_MAX1;
        g->score2 = SCORE_MAX2;
    }
    g->score_dirty = 1;
}

void score_add_hit(Game *g) {
    uint8_t points = SCORE_HIT_POINTS;
    if (g->score_2x) {
        points = (uint8_t)(points << 1);
    }
    score_add_n(g, points);
}

static int work_ge_place(uint8_t w0, uint8_t w1, uint8_t w2, uint8_t place) {
    if (w2 > place_hi[place]) {
        return 1;
    }
    if (w2 < place_hi[place]) {
        return 0;
    }
    if (w1 > place_mid[place]) {
        return 1;
    }
    if (w1 < place_mid[place]) {
        return 0;
    }
    return w0 >= place_lo[place];
}

void score_paint_if_dirty(Game *g) {
    uint8_t work0;
    uint8_t work1;
    uint8_t work2;
    uint8_t place;

    if (!g->score_dirty) {
        return;
    }
    g->score_dirty = 0;
    work0 = g->score0;
    work1 = g->score1;
    work2 = g->score2;
    for (place = 0; place < 6; place++) {
        uint8_t digit = 0;
        while (work_ge_place(work0, work1, work2, place) && digit < 10) {
            uint16_t diff = (uint16_t)work0 - place_lo[place];
            work0 = (uint8_t)diff;
            diff = (uint16_t)work1 - place_mid[place] - ((diff >> 8) & 1);
            /* borrow is 1 when the uint16 wrapped, i.e. high byte is 0xFF */
            work1 = (uint8_t)diff;
            diff = (uint16_t)work2 - place_hi[place] - ((diff >> 8) & 1);
            work2 = (uint8_t)diff;
            digit++;
        }
        if (digit > 9) {
            digit = 9;
        }
        screen_put_xy(g, (uint8_t)(HUD_SCORE_COL + place), HUD_ROW,
                      (uint8_t)(SC_ZERO + digit));
    }
}

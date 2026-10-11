#include "input.h"

static void edge_u8(uint8_t held, uint8_t *prev, uint8_t *edge) {
    *edge = 0;
    if (held && !*prev) {
        *edge = 1;
    }
    *prev = held;
}

void input_poll(Game *g) {
    edge_u8(g->input_fire, &g->input_fire_prev, &g->input_fire_edge);
    edge_u8(g->input_key_s, &g->input_key_s_prev, &g->input_key_s_edge);
    edge_u8(g->input_key_i, &g->input_key_i_prev, &g->input_key_i_edge);
    edge_u8(g->input_runstop, &g->input_runstop_prev, &g->input_runstop_edge);
    g->frame_count++;
}

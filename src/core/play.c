#include "play.h"

#include "bullets.h"
#include "cargo.h"
#include "collision.h"
#include "drones.h"
#include "hud.h"
#include "mode.h"
#include "parcels.h"
#include "player.h"
#include "rail.h"
#include "score.h"
#include "waves.h"

void play_enter(Game *g) {
    /* Border green in the assembly is not state. */
    g->pending_mode = 0;
}

void play_update(Game *g) {
    uint8_t next;
    if (g->input_runstop_edge) {
        mode_set(g, MODE_GAME_OVER);
        return;
    }
    g->pending_mode = 0;
    rail_strike_frame_reset(g);
    player_update(g);
    drones_update(g);
    cargo_update(g);
    parcels_update(g);
    bullets_update(g);
    collision_update(g);
    waves_update_banner(g);
    if (g->pending_mode == 0 && !g->player_dead) {
        waves_check_clear(g);
    }
    score_paint_if_dirty(g);
    hud_paint_status_if_dirty(g);
    if (g->pending_mode == 0) {
        return;
    }
    next = g->pending_mode;
    g->pending_mode = 0;
    mode_set(g, next);
}

void next_wave_enter(Game *g) {
    mode_set(g, MODE_PLAY);
}

void next_wave_update(Game *g) {
    (void)g;
}

void next_level_enter(Game *g) {
    mode_set(g, MODE_PLAY);
}

void next_level_update(Game *g) {
    (void)g;
}

#include "game_init.h"

#include "cargo.h"
#include "mode.h"
#include "music.h"
#include "objects.h"
#include "rail.h"
#include "score.h"
#include "tallies.h"

void game_init_enter(Game *g) {
    music_stop(g);
    score_reset(g);
    tallies_reset(g);
    objects_init(g);
    g->lives = START_LIVES;
    g->level = START_LEVEL;
    g->level_kills = 0;
    g->level_banner_t = 0;
    g->pending_mode = 0;
    g->victory = 0;
    g->kill_extra_cnt = 0;
    g->parcel_flags = 0;
    g->power_2x = 0;
    g->score_2x = 0;
    g->clear_armed = 0;
    g->repair_timer = 0;
    g->deploy_timer = 0;
    g->player_was_centre = 0;
    g->hud_status_dirty = 1;
    cargo_init(g);
    rail_reset(g);
    mode_set(g, MODE_STAGE_INIT);
}

void game_init_update(Game *g) {
    (void)g;
}

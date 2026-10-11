#include "waves.h"

#include "cargo.h"
#include "data/tables.h"
#include "drones.h"
#include "message.h"
#include "parcels.h"
#include "sfx.h"

static void apply_spawn_params(Game *g) {
    uint8_t half;
    g->wave_quad_mask = WAVE_Q_ALL;
    g->wave_flags = WAVE_F_MAIN_C;
    g->wave_cd_min = 50;
    g->wave_cd_max = 90;
    g->wave_max_active = 3;

    if (g->level < 3 && g->level_kills < 1) {
        g->wave_quad_mask = WAVE_Q_TOP;
        g->wave_cd_min = 70;
        g->wave_cd_max = 110;
        g->wave_max_active = 2;
        return;
    }

    half = (uint8_t)(g->level_quota >> 1);
    if (half >= g->level_kills) {
        if (g->level < 2) {
            return;
        }
        g->wave_flags = (uint8_t)(WAVE_F_MAIN_C | WAVE_F_PIGGY_C);
        g->wave_cd_min = 40;
        g->wave_cd_max = 75;
        g->wave_max_active = 4;
        return;
    }

    g->wave_flags = (uint8_t)(WAVE_F_MAIN_C | WAVE_F_PIGGY_C);
    g->wave_cd_min = 28;
    g->wave_cd_max = 55;
    g->wave_max_active = 5;
    if (g->level >= 8) {
        g->wave_max_active = 7;
    }
    if (g->wave_max_active > WAVE_MAX_ACTIVE_CAP) {
        g->wave_max_active = WAVE_MAX_ACTIVE_CAP;
    }
}

static uint8_t clamped_level(uint8_t level) {
    if (level == 0) {
        level = 1;
    }
    if (level > MAX_LEVEL) {
        level = MAX_LEVEL;
    }
    return level;
}

static void advance_level(Game *g) {
    if (g->level >= MAX_LEVEL) {
        g->victory = 1;
        g->pending_mode = MODE_GAME_OVER;
        return;
    }
    g->level++;
    g->level_kills = 0;
    g->level_banner_t = 0;
    waves_load(g);
    message_restore_hud_line(g);
    sfx_play(g, SFX_WAVE);
}

void waves_load(Game *g) {
    uint8_t lv = clamped_level(g->level);
    g->level_quota = level_kill_quota_tbl[lv - 1];
    g->level_kills = 0;
    g->level_banner_t = 0;
    g->piggy_timer = 0;
    g->power_2x = 0;
    g->score_2x = 0;
    g->spawn_last_quad = 0xFF;
    g->drone_speed_cap = clamped_level(g->level);
    apply_spawn_params(g);
    if (g->rng_state == 0) {
        g->rng_state = (uint8_t)(g->frame_count | 1);
    }
    drones_roll_cooldown(g);
    parcels_level_reset(g);
    g->hud_status_dirty = 1;
}

void waves_note_kill(Game *g) {
    if (g->level_kills != 255) {
        g->level_kills++;
    }
    g->kill_extra_cnt++;
    if (g->kill_extra_cnt >= EXTRA_KILL_EVERY) {
        g->kill_extra_cnt = 0;
        g->parcel_flags = (uint8_t)(g->parcel_flags | PARCEL_FLAG_EXTRA);
    }
    g->hud_status_dirty = 1;
    apply_spawn_params(g);
    parcels_on_kill(g);
}

void waves_check_clear(Game *g) {
    if (g->level_banner_t != 0) {
        return;
    }
    if (g->level_kills < g->level_quota) {
        return;
    }
    if (drones_count_active(g) != 0) {
        return;
    }
    g->level_banner_t = LEVEL_BANNER_FRAMES;
    message_show_rank_banner(g);
    cargo_reward_level_clear(g);
}

void waves_update_banner(Game *g) {
    if (g->level_banner_t == 0) {
        return;
    }
    message_tick_banner_color(g);
    g->level_banner_t--;
    if (g->level_banner_t != 0) {
        return;
    }
    advance_level(g);
}

#ifndef RAILGUNNER_SIM_H
#define RAILGUNNER_SIM_H

#include "cells.h"
#include "objects.h"

#include <stdint.h>

/* One logic tick is 1/LOGIC_HZ second. The host may repaint faster; it
 * must not run more than one tick per host frame. */

/* What the frontend blits. Hires title ignores the cell buffer. */
#define PRESENT_TEXT 0
#define PRESENT_HIRES_TITLE 1

typedef struct Game {
    uint32_t frame;             /* logic ticks, for the headless dump */
    uint8_t frame_count;        /* assembly frame_count, wraps at 256 */
    Cell cells[SCREEN_H][SCREEN_W];
    uint8_t mode;
    uint8_t mode_timer;
    uint8_t mode_state;
    uint8_t pending_mode;
    uint8_t lives;
    uint8_t hud_status_dirty;
    uint8_t player_rail;
    uint8_t player_rest_dir;
    uint8_t player_swing_t;
    uint8_t player_swing_to;
    uint8_t player_move_dir;
    uint8_t player_cross_decided;
    uint8_t player_dead;
    uint8_t player_was_centre;
    uint8_t player_frame;
    uint8_t deploy_timer;
    uint8_t bullet_active[BULLET_MAX];
    uint8_t bullet_col[BULLET_MAX];
    uint8_t bullet_row[BULLET_MAX];
    uint8_t bullet_half[BULLET_MAX];
    uint8_t bullet_dir[BULLET_MAX];
    uint8_t bullet_phase[BULLET_MAX];
    uint8_t bullet_hold[BULLET_MAX];
    uint8_t fire_lock;
    uint8_t score0;
    uint8_t score1;
    uint8_t score2;
    uint8_t score_dirty;
    uint8_t death_phase;
    uint8_t death_timer;
    uint8_t death_fatal;
    uint8_t death_flash;
    uint8_t death_flash_t;
    uint8_t death_banner_col;
    uint8_t death_banner_len;
    uint8_t rng_state;
    uint8_t drone_spawn_timer;
    uint8_t drone_speed_cap;
    uint8_t level;
    uint8_t level_quota;
    uint8_t level_kills;
    uint8_t level_banner_t;
    uint8_t banner_col;
    uint8_t banner_len;
    uint8_t piggy_timer;
    uint8_t piggy_quad;
    uint8_t piggy_approach;
    uint8_t power_2x;
    uint8_t score_2x;
    uint8_t spawn_last_quad;
    uint8_t wave_quad_mask;
    uint8_t wave_flags;
    uint8_t wave_cd_min;
    uint8_t wave_cd_max;
    uint8_t wave_max_active;
    uint8_t kill_extra_cnt;
    uint8_t parcel_flags;
    uint8_t parcel_due;
    uint8_t parcel_drop_mask;
    uint8_t parcel_slot;
    uint8_t parcel_flip;
    uint8_t parcel_dir;
    uint8_t parcel_type;
    uint8_t clear_armed;
    uint8_t repair_timer;
    uint8_t cargo_slot;
    uint8_t cargo_target;
    uint8_t ghij_rr;
    uint8_t ghij_last;
    uint8_t mine_armed;
    uint8_t ghij_stack[4];
    uint8_t victory;
    uint16_t tally_shots;
    uint16_t tally_kill_a;
    uint16_t tally_kill_b;
    uint16_t tally_kill_c;
    uint8_t rail_dmg_d[SCREEN_W];
    uint8_t rail_dmg_e[SCREEN_W];
    uint8_t rail_dmg_f[SCREEN_W];
    uint8_t rail_dmg_va[SCREEN_H];
    uint8_t rail_dmg_vb[SCREEN_H];
    uint8_t rail_dmg_vc[SCREEN_H];
    uint8_t heal_mark_d[SCREEN_W];
    uint8_t heal_mark_e[SCREEN_W];
    uint8_t heal_mark_f[SCREEN_W];
    uint8_t heal_mark_va[SCREEN_H];
    uint8_t heal_mark_vb[SCREEN_H];
    uint8_t heal_mark_vc[SCREEN_H];
    uint8_t rail_dmg_amt;
    uint8_t rail_hit_left;
    uint8_t rail_hit_slot;
    uint8_t attract_lo;
    uint8_t attract_hi;
    uint8_t present;
    uint8_t music_active;
    uint8_t input_dirs;
    uint8_t input_fire;
    uint8_t input_fire_edge;
    uint8_t input_fire_prev;
    uint8_t input_key_s;
    uint8_t input_key_s_edge;
    uint8_t input_key_s_prev;
    uint8_t input_key_i;
    uint8_t input_key_i_edge;
    uint8_t input_key_i_prev;
    uint8_t input_runstop;
    uint8_t input_runstop_edge;
    uint8_t input_runstop_prev;
    uint8_t score_color_phase;
    uint8_t score_color_tick;
    uint8_t type_col;
    uint8_t type_row;
    uint8_t type_prev_col;
    uint8_t type_prev_row;
    const char *type_src;
    uint8_t hs_rank;
    uint8_t hs_cursor;
    uint8_t hs_char_idx;
    uint8_t hs_phase;
    uint8_t hs_dirs_prev;
    uint8_t hs_repeat_t;
    /* Title loop. An SFX lease sets mus_mute and writes sid_* itself.
     * Music keeps counting mus_timer while muted. */
    uint8_t mus_mute[MUSIC_VOICES];
    uint8_t mus_pos[MUSIC_VOICES];
    uint8_t mus_timer[MUSIC_VOICES];
    uint8_t mus_lo[MUSIC_VOICES];
    uint8_t mus_hi[MUSIC_VOICES];
    uint8_t mus_wave[MUSIC_VOICES];
    uint8_t sfx_id[MUSIC_VOICES];
    uint8_t sfx_phase[MUSIC_VOICES];
    uint8_t sfx_timer[MUSIC_VOICES];
    uint8_t sfx_state[MUSIC_VOICES];
    uint8_t sfx_wave[MUSIC_VOICES];
    /* Published SID voice. The core does not produce samples. */
    uint16_t sid_freq[MUSIC_VOICES];
    uint16_t sid_pw[MUSIC_VOICES];
    uint8_t sid_ctrl[MUSIC_VOICES];
    uint8_t sid_ad[MUSIC_VOICES];
    uint8_t sid_sr[MUSIC_VOICES];
    uint32_t sid_gen[MUSIC_VOICES]; /* note-on count; host envelope restarts */
    Object objects[OBJECT_CAPACITY];
    uint8_t free_stack[OBJECT_FREE_CAPACITY];
    uint8_t free_count;
} Game;

void sim_init(Game *g);
void sim_tick(Game *g);

#endif

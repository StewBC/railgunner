#ifndef RAILGUNNER_TABLES_H
#define RAILGUNNER_TABLES_H

#include "const.h"

#include <stdint.h>

/* Title loop. Each event is duration_frames, freq_lo, freq_hi.
 * 0,0 is a rest. 0xFF ends the list and loops.
 * music_track0 starts 12, 0xDA, 0x20 (B4), the first Valkyrie event. */
extern const uint8_t music_track0[];
extern const uint8_t music_track1[];
extern const uint8_t music_track2[];
extern const uint8_t *const music_tracks[MUSIC_VOICES];
extern const uint8_t music_wave[MUSIC_VOICES];
extern const uint8_t music_ad[MUSIC_VOICES];
extern const uint8_t music_sr[MUSIC_VOICES];

/* SFX step lists, indexed by SFX id. A step with wave 0 ends the list. */
extern const uint8_t steps_ui_fire[];
extern const uint8_t steps_hs_tick[];
extern const uint8_t steps_wave[];
extern const uint8_t steps_mine[];
extern const uint8_t steps_parcel[];
extern const uint8_t steps_player_die[];
extern const uint8_t steps_extra[];
extern const uint8_t steps_heal[];
extern const uint8_t steps_drone_die[];
extern const uint8_t steps_ping[];
extern const uint8_t *const sfx_steps[SFX_COUNT];

/* Level and spawn tables from data/waves.asm and the quota in strings.asm. */
extern const uint8_t level_speed_scale[];
extern const uint8_t drone_vel_tier[];
extern const uint8_t wave_base_c[];
extern const uint8_t wave_base_b[];
extern const uint8_t wave_base_a[];
extern const uint8_t wave_base_cd_min[];
extern const uint8_t wave_base_cd_max[];
extern const uint8_t wave_base_max_active[];
extern const uint8_t wave_base_quad_mask[];
extern const uint8_t wave_base_flags[];
extern const uint8_t wave_grow_c[];
extern const uint8_t wave_grow_b[];
extern const uint8_t wave_grow_a[];
extern const uint8_t level_kill_quota_tbl[MAX_LEVEL];

/* Screen text. Uppercase, NUL-terminated, as screen_print receives it.
 * Story and instructions use newline (0x0A) the way the assembly does. */
extern const char str_title[];
extern const char str_past_heroes[];
extern const char str_fire_to_play[];
extern const char str_s_for_story[];
extern const char str_i_for_instructions[];
extern const char str_code_art_by[];
extern const char str_credits_ai[];
extern const char str_produced_by[];
extern const char str_producer[];
extern const char str_fire_to_continue[];
extern const char story_text[];
extern const char instructions_text[];
extern const char str_press_fire[];
extern const char str_game_over[];
extern const char str_victory[];
extern const char str_game_over_banner[];
extern const char str_rip_pilot_banner[];
extern const char str_hs_congrats[];
extern const char str_hs_new_score[];
extern char str_hs_prompt[];
extern const char str_hs_help[];
extern const char str_go_results[];
extern const char str_go_score[];
extern const char str_go_rank[];
extern const char str_go_waves[];
extern const char str_go_shots[];
extern const char str_go_destruction[];
extern const char str_go_mine[];
extern const char str_go_medium[];
extern const char str_go_heavy[];
extern const char str_hiscore[];
extern const char str_hud[];
extern const char str_nicety_01[];
extern const char str_nicety_02[];
extern const char str_nicety_03[];
extern const char str_nicety_04[];
extern const char str_nicety_05[];
extern const char str_nicety_06[];
extern const char str_nicety_07[];
extern const char str_nicety_08[];
extern const char str_nicety_09[];
extern const char str_nicety_10[];
extern const char str_nicety_11[];
extern const char str_nicety_12[];
extern const char str_nicety_13[];
extern const char str_nicety_14[];
extern const char str_nicety_15[];
extern const char str_rank_title_01[];
extern const char str_rank_title_02[];
extern const char str_rank_title_03[];
extern const char str_rank_title_04[];
extern const char str_rank_title_05[];
extern const char str_rank_title_06[];
extern const char str_rank_title_07[];
extern const char str_rank_title_08[];
extern const char str_rank_title_09[];
extern const char str_rank_title_10[];
extern const char str_rank_title_11[];
extern const char str_rank_title_12[];
extern const char str_rank_title_13[];
extern const char str_rank_title_14[];
extern const char str_rank_title_15[];
extern const char str_hs_header[];
extern char hs_line_1[];
extern char hs_line_2[];
extern char hs_line_3[];
extern char hs_line_4[];
extern char hs_line_5[];
extern char hs_line_6[];
extern char hs_line_7[];
extern char hs_line_8[];
extern char hs_line_9[];
extern char hs_line_10[];
#define str_hud_placeholder str_hud
extern const char *const nicety_tbl[MAX_LEVEL];
extern const char *const rank_title_tbl[MAX_LEVEL];
extern char *const hs_lines[10];

/* 10 bright colours for the heroes / banner wheel. From title.asm. */
extern const uint8_t score_color_table[BANNER_NUM_COLORS];

/* Cargo disc is drawn in sprites.asm, not stored as a PNG bin. */
extern const uint8_t spr_cargo_disc[SPR_FRAME_BYTES];

/* VIC pointer id -> file under assets/c64/sprites.
 * bin_name NULL means spr_cargo_disc. */
typedef struct SprFrameBin {
    uint8_t ptr_id;
    const char *bin_name;
} SprFrameBin;
extern const SprFrameBin spr_frame_bins[SPR_FRAMES_SRC_COUNT];
/* Player facings, SPR_DIR_LEFT .. SPR_DIR_DOWN. Buffers are SPR_PTR_PLAYER_0/1. */
extern const char *const spr_player_bins[4];

#endif

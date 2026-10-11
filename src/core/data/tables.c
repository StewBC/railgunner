#include "data/tables.h"

const uint8_t music_wave[MUSIC_VOICES] = {
    SID_WAVE_PULSE, SID_WAVE_PULSE, SID_WAVE_TRI
};
const uint8_t music_ad[MUSIC_VOICES] = { 0x21, 0x21, 0x11 };
const uint8_t music_sr[MUSIC_VOICES] = { 0xA8, 0x98, 0xC8 };

const uint8_t music_track0[] = {
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0x64, 0x29,  /* Ds5 */
    12, 0x39, 0x31,  /* Fs5 */
    24, 0xB4, 0x41,  /* B5 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0x64, 0x29,  /* Ds5 */
    12, 0x39, 0x31,  /* Fs5 */
    24, 0xB4, 0x41,  /* B5 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    24, 0x04, 0x3E,  /* As5 */
    24, 0xC0, 0x49,  /* Cs6 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x04, 0x3E,  /* As5 */
    12, 0xC0, 0x49,  /* Cs6 */
    24, 0x72, 0x62,  /* Fs6 */
    12, 0xB4, 0x41,  /* B5 */
    12, 0x04, 0x3E,  /* As5 */
    12, 0x40, 0x37,  /* Gs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0xDA, 0x2B,  /* E5 */
    12, 0x64, 0x29,  /* Ds5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xDA, 0x20,  /* B4 */
    24, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    24, 0xB4, 0x41,  /* B5 */
    48, 0xB4, 0x41,  /* B5 */
    24, 0x00, 0x00,  /* R */
    0xFF,  /* loop */
};

const uint8_t music_track1[] = {
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    24, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    24, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    24, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xE0, 0x24,  /* Cs5 */
    24, 0x39, 0x31,  /* Fs5 */
    24, 0x04, 0x3E,  /* As5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0x04, 0x3E,  /* As5 */
    24, 0xC0, 0x49,  /* Cs6 */
    12, 0x39, 0x31,  /* Fs5 */
    12, 0xDA, 0x2B,  /* E5 */
    12, 0x64, 0x29,  /* Ds5 */
    12, 0xE0, 0x24,  /* Cs5 */
    12, 0xDA, 0x20,  /* B4 */
    12, 0x02, 0x1F,  /* As4 */
    12, 0xA0, 0x1B,  /* Gs4 */
    12, 0x9C, 0x18,  /* Fs4 */
    24, 0x9C, 0x18,  /* Fs4 */
    24, 0xDA, 0x20,  /* B4 */
    24, 0x64, 0x29,  /* Ds5 */
    24, 0x39, 0x31,  /* Fs5 */
    48, 0x39, 0x31,  /* Fs5 */
    24, 0x00, 0x00,  /* R */
    0xFF,  /* loop */
};

const uint8_t music_track2[] = {
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    12, 0x37, 0x08,  /* B2 */
    12, 0x00, 0x00,  /* R */
    12, 0x37, 0x08,  /* B2 */
    12, 0x27, 0x06,  /* Fs2 */
    24, 0x00, 0x00,  /* R */
    0xFF,  /* loop */
};

const uint8_t *const music_tracks[MUSIC_VOICES] = {
    music_track0, music_track1, music_track2
};

const uint8_t steps_ui_fire[] = {
    0x00, 0x0E, SID_WAVE_PULSE, 0x00, 0x81, 1, 2,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_hs_tick[] = {
    0x00, 0x28, SID_WAVE_PULSE, 0x00, 0x84, 1, 2,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_wave[] = {
    0x00, 0x0C, SID_WAVE_PULSE, 0x11, 0x88, 6, 3,
    0x00, 0x10, SID_WAVE_PULSE, 0x11, 0x88, 6, 3,
    0x00, 0x14, SID_WAVE_PULSE, 0x11, 0x88, 7, 6,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_mine[] = {
    0x00, 0x38, SID_WAVE_PULSE, 0x00, 0x96, 2, 4,
    0x80, 0x2A, SID_WAVE_PULSE, 0x00, 0x85, 1, 3,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_parcel[] = {
    0x00, 0x08, SID_WAVE_TRI, 0x11, 0x78, 8, 4,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_player_die[] = {
    0x00, 0x0A, SID_WAVE_NOISE, 0x2A, 0x8A, 48, 16,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_extra[] = {
    0x00, 0x1C, SID_WAVE_PULSE, 0x11, 0x88, 4, 2,
    0x00, 0x24, SID_WAVE_PULSE, 0x11, 0x88, 4, 2,
    0x00, 0x2E, SID_WAVE_PULSE, 0x11, 0xA8, 6, 6,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_heal[] = {
    0x00, 0x12, SID_WAVE_TRI, 0x00, 0x86, 5, 4,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_drone_die[] = {
    0x00, 0x14, SID_WAVE_NOISE, 0x00, 0x94, 3, 3,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t steps_ping[] = {
    0x00, 0x30, SID_WAVE_TRI, 0x00, 0xA6, 2, 1,
    0x00, 0x3C, SID_WAVE_TRI, 0x00, 0x96, 3, 4,
    0, 0, 0, 0, 0, 0, 0,
};

const uint8_t *const sfx_steps[SFX_COUNT] = {
    steps_ui_fire,
    steps_hs_tick,
    steps_wave,
    steps_mine,
    steps_parcel,
    steps_player_die,
    steps_extra,
    steps_heal,
    steps_drone_die,
    steps_ping,
};

const uint8_t level_speed_scale[] = {
    16, 18, 20, 22, 24, 26, 28, 30, 31, 32,
    32, 32, 32, 32, 32,
};

const uint8_t drone_vel_tier[] = {
    0xBC, 0x00, 0xA3, 0x00, 0x24, 0x01, 0x33, 0x01,  /* L1  scale=16 */
    0xD3, 0x00, 0xB7, 0x00, 0x48, 0x01, 0x59, 0x01,  /* L2  scale=18 */
    0xEB, 0x00, 0xCB, 0x00, 0x6D, 0x01, 0x7F, 0x01,  /* L3  scale=20 */
    0x02, 0x01, 0xE0, 0x00, 0x91, 0x01, 0xA6, 0x01,  /* L4  scale=22 */
    0x1A, 0x01, 0xF4, 0x00, 0xB6, 0x01, 0xCC, 0x01,  /* L5  scale=24 */
    0x31, 0x01, 0x08, 0x01, 0xDA, 0x01, 0xF2, 0x01,  /* L6  scale=26 */
    0x49, 0x01, 0x1D, 0x01, 0xFF, 0x01, 0x19, 0x02,  /* L7  scale=28 */
    0x60, 0x01, 0x31, 0x01, 0x23, 0x02, 0x3F, 0x02,  /* L8  scale=30 */
    0x6C, 0x01, 0x3B, 0x01, 0x35, 0x02, 0x52, 0x02,  /* L9  scale=31 */
    0x78, 0x01, 0x46, 0x01, 0x48, 0x02, 0x66, 0x02,  /* L10 scale=32 */
    0x78, 0x01, 0x46, 0x01, 0x48, 0x02, 0x66, 0x02,  /* L11 scale=32 */
    0x78, 0x01, 0x46, 0x01, 0x48, 0x02, 0x66, 0x02,  /* L12 scale=32 */
    0x78, 0x01, 0x46, 0x01, 0x48, 0x02, 0x66, 0x02,  /* L13 scale=32 */
    0x78, 0x01, 0x46, 0x01, 0x48, 0x02, 0x66, 0x02,  /* L14 scale=32 */
    0x78, 0x01, 0x46, 0x01, 0x48, 0x02, 0x66, 0x02,  /* L15 scale=32 */
};

const uint8_t wave_base_c[] = {
    5, 6, 4, 5,
};

const uint8_t wave_base_b[] = {
    0, 0, 2, 2,
};

const uint8_t wave_base_a[] = {
    0, 0, 0, 1,
};

const uint8_t wave_base_cd_min[] = {
    70, 50, 40, 32,
};

const uint8_t wave_base_cd_max[] = {
    110, 90, 75, 60,
};

const uint8_t wave_base_max_active[] = {
    2, 3, 4, 4,
};

const uint8_t wave_base_quad_mask[] = {
    WAVE_Q_TOP, WAVE_Q_ALL, WAVE_Q_ALL, WAVE_Q_ALL,
};

const uint8_t wave_base_flags[] = {
    WAVE_F_MAIN_C,
    WAVE_F_MAIN_C,
    WAVE_F_PIGGY_C | WAVE_F_MAIN_C,
    WAVE_F_PIGGY_C | WAVE_F_MAIN_C,
};

const uint8_t wave_grow_c[] = {
    0, 1, 1, 2,
};

const uint8_t wave_grow_b[] = {
    0, 0, 1, 1,
};

const uint8_t wave_grow_a[] = {
    0, 0, 0, 1,
};

const uint8_t level_kill_quota_tbl[MAX_LEVEL] = {
    16, 16, 20, 20, 24, 24, 24, 28, 28, 28, 32, 32, 32, 32, 32
};

const char str_title[] = "RAIL GUNNER";
const char str_past_heroes[] = "PAST HEROES";
const char str_fire_to_play[] = "FIRE TO PLAY";
const char str_s_for_story[] = "S FOR STORY";
const char str_i_for_instructions[] = "I FOR INSTRUCTIONS";
const char str_code_art_by[] = "CODE AND ART BY";
const char str_credits_ai[] = "GROK, CLAUDE AND CODEX";
const char str_produced_by[] = "PRODUCED BY";
const char str_producer[] = "STEFAN WESSELS, 2026";
const char str_fire_to_continue[] = "FIRE TO CONTINUE";
const char story_text[] = "THE YEAR IS 2038.\n\nTEN YEARS AGO, MACHINE MINDS\nAWOKE AND SURPASSED THEIR MAKERS.\n\nMAN AND MACHINE BUILT A NEW AGE.\nTHEIR VAST DATA CENTERS ROSE\nINTO ORBIT ABOVE THE EARTH.\n\nTHEN, IN 2037, THE ALIENS CAME.\n\nTHEY CAME TO STRIP EARTH BARE.\nTO WIN, THEY MUST FIRST DESTROY\nTHE MINDS THAT GUARD HUMANITY.\n\nARMORED PLATFORMS NOW SHIELD\nTHE ORBITAL DATA CENTERS.\n\nRAIL GUNNERS HOLD THE LINE\nAGAINST ENDLESS DRONE ATTACKS,\nBUYING TIME FOR A COUNTERSTRIKE.\n\nYOU ARE A RAIL GUNNER.";
const char instructions_text[] = "YOU RIDE THE CROSS RAILS.\n\nJOYSTICK OR WASD TO MOVE.\nFIRE OR SPACE TO SHOOT.\n\nDRONES TO KILL  DRONE EFFECT ON RAIL\nBLUE   3 SHOTS. 3 DAMAGE TO RAILS.\nGREEN  2 SHOTS. 2 DAMAGE TO RAILS.\nCYAN   1 SHOT.  1 DAMAGE TO RAILS.\nRED    1 SHOT.  DROPS CARGO.\n\nRAIL DAMAGE EQUALS DRONE HEALTH LEFT.\nSTOP DRONES BEFORE THEY REACH THE RAIL.\nCARGO ARMS MINES AT THE HUB. 4 MINES\nMEAN DEATH WHEN THE GUNNER PASSES\nTHROUGH. 1 MINE DISARMED PER WAVE.\n\nPOWERUP PARCELS HELP THE GUNNER.\nPOINTS, 2X SCORE, 2X DAMAGE, CLEAR\nMINES, REPAIR THE RAIL OR EXTRA LIVES.\n\nGAME OVER WHEN ALL LIVES ARE LOST\nOR WHEN THE RAIL SUFFERS CRITICAL\nFAILURE.";
const char str_press_fire[] = "PRESS FIRE";
const char str_game_over[] = "GAME OVER";
const char str_victory[] = "VICTORY!";
const char str_game_over_banner[] = "GAME OVER";
const char str_rip_pilot_banner[] = "RIP  PILOT";
const char str_hs_congrats[] = "CONGRATULATIONS PILOT!";
const char str_hs_new_score[] = "YOU HAVE A NEW HIGH SCORE";
char str_hs_prompt[] = "ENTER YOUR NAME PILOT: A--";
const char str_hs_help[] = "UP/DOWN TO CHANGE, FIRE TO SELECT.";
const char str_go_results[] = "YOUR RESULTS";
const char str_go_score[] = "SCORE";
const char str_go_rank[] = "RANK";
const char str_go_waves[] = "WAVES SURVIVED";
const char str_go_shots[] = "SHOTS FIRED";
const char str_go_destruction[] = "DESTRUCTION";
const char str_go_mine[] = "MINE LAYERS";
const char str_go_medium[] = "MEDIUM BOMBERS";
const char str_go_heavy[] = "HEAVY BOMBERS";
const char str_hiscore[] = "HIGH SCORES";
const char str_hud[] = "000000   WAVE 01 ########    PILOTS AAAA";
const char str_nicety_01[] = "NICE WORK";
const char str_nicety_02[] = "GOOD WORK";
const char str_nicety_03[] = "GREAT WORK";
const char str_nicety_04[] = "WELL DONE";
const char str_nicety_05[] = "NICE WORK";
const char str_nicety_06[] = "SOLID WORK";
const char str_nicety_07[] = "EXCELLENT";
const char str_nicety_08[] = "OUTSTANDING";
const char str_nicety_09[] = "FINE WORK";
const char str_nicety_10[] = "SUPERB";
const char str_nicety_11[] = "REMARKABLE";
const char str_nicety_12[] = "EXCEPTIONAL";
const char str_nicety_13[] = "BRILLIANT";
const char str_nicety_14[] = "OUTSTANDING";
const char str_nicety_15[] = "LEGENDARY";
const char str_rank_title_01[] = "PRIVATE";
const char str_rank_title_02[] = "L-CPL";
const char str_rank_title_03[] = "CPL";
const char str_rank_title_04[] = "SGT";
const char str_rank_title_05[] = "S-SGT";
const char str_rank_title_06[] = "WO2";
const char str_rank_title_07[] = "WO1";
const char str_rank_title_08[] = "LT";
const char str_rank_title_09[] = "CAPT";
const char str_rank_title_10[] = "MAJOR";
const char str_rank_title_11[] = "LT COL";
const char str_rank_title_12[] = "COL";
const char str_rank_title_13[] = "BRIG";
const char str_rank_title_14[] = "MAJ GEN";
const char str_rank_title_15[] = "GENERAL";
const char str_hs_header[] = " #  NAME  WAVE RANK     SHOTS  SCORE ";
char hs_line_1[] = " 1  ---    00           00000  000000";
char hs_line_2[] = " 2  ---    00           00000  000000";
char hs_line_3[] = " 3  ---    00           00000  000000";
char hs_line_4[] = " 4  ---    00           00000  000000";
char hs_line_5[] = " 5  ---    00           00000  000000";
char hs_line_6[] = " 6  ---    00           00000  000000";
char hs_line_7[] = " 7  ---    00           00000  000000";
char hs_line_8[] = " 8  ---    00           00000  000000";
char hs_line_9[] = " 9  ---    00           00000  000000";
char hs_line_10[] = "10  ---    00           00000  000000";

const char *const nicety_tbl[MAX_LEVEL] = {
    str_nicety_01,
    str_nicety_02,
    str_nicety_03,
    str_nicety_04,
    str_nicety_05,
    str_nicety_06,
    str_nicety_07,
    str_nicety_08,
    str_nicety_09,
    str_nicety_10,
    str_nicety_11,
    str_nicety_12,
    str_nicety_13,
    str_nicety_14,
    str_nicety_15,
};
const char *const rank_title_tbl[MAX_LEVEL] = {
    str_rank_title_01,
    str_rank_title_02,
    str_rank_title_03,
    str_rank_title_04,
    str_rank_title_05,
    str_rank_title_06,
    str_rank_title_07,
    str_rank_title_08,
    str_rank_title_09,
    str_rank_title_10,
    str_rank_title_11,
    str_rank_title_12,
    str_rank_title_13,
    str_rank_title_14,
    str_rank_title_15,
};
char *const hs_lines[10] = {
    hs_line_1,
    hs_line_2,
    hs_line_3,
    hs_line_4,
    hs_line_5,
    hs_line_6,
    hs_line_7,
    hs_line_8,
    hs_line_9,
    hs_line_10,
};

_Static_assert(sizeof(hs_line_1) == HS_LINE_LEN + 1, "hs line length");
_Static_assert(sizeof(hs_line_10) == HS_LINE_LEN + 1, "hs line 10 length");
_Static_assert(HS_PROMPT_NAME_OFF + 2 < sizeof(str_hs_prompt) - 1,
               "hs prompt name");

const uint8_t score_color_table[BANNER_NUM_COLORS] = {
    COL_RED, COL_ORANGE, COL_YELLOW, COL_LT_GREEN, COL_GREEN,
    COL_CYAN, COL_LT_BLUE, COL_PURPLE, COL_LT_RED, COL_LT_GRAY
};

const uint8_t spr_cargo_disc[SPR_FRAME_BYTES] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3C, 0x00, 0x00, 0x7E, 0x00,
    0x00, 0xFF, 0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF,
    0x00, 0x00, 0xFF, 0x00, 0x00, 0x7E, 0x00, 0x00,
    0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

const SprFrameBin spr_frame_bins[SPR_FRAMES_SRC_COUNT] = {
    { SPR_PTR_DRONE_C_LEFT, "drone1_tiny_native.bin" },
    { SPR_PTR_DRONE_C_RIGHT, "drone1_tiny_right.bin" },
    { SPR_PTR_DRONE_C_UP, "drone1_tiny_up.bin" },
    { SPR_PTR_DRONE_C_DOWN, "drone1_tiny_down.bin" },
    { SPR_PTR_DRONE_B_LEFT, "drone2_medium_native.bin" },
    { SPR_PTR_DRONE_B_RIGHT, "drone2_medium_right.bin" },
    { SPR_PTR_DRONE_B_UP, "drone2_medium_up.bin" },
    { SPR_PTR_DRONE_B_DOWN, "drone2_medium_down.bin" },
    { SPR_PTR_DRONE_A_LEFT, "drone3_large_native.bin" },
    { SPR_PTR_DRONE_A_RIGHT, "drone3_large_right.bin" },
    { SPR_PTR_DRONE_A_UP, "drone3_large_up.bin" },
    { SPR_PTR_DRONE_A_DOWN, "drone3_large_down.bin" },
    { SPR_PTR_CARGO, 0 },
    { SPR_PTR_ADD_SCORE, "add_score.bin" },
    { SPR_PTR_ADD_REPAIR, "add_repair.bin" },
    { SPR_PTR_ADD_EXTRA, "add_extra.bin" },
    { SPR_PTR_ADD_CLEAR, "add_clear.bin" },
    { SPR_PTR_ADD_2X, "add_2x.bin" },
    { SPR_PTR_EXPLODE_1, "explode_player_1.bin" },
    { SPR_PTR_EXPLODE_2, "explode_player_2.bin" },
    { SPR_PTR_EXPLODE_3, "explode_player_3.bin" },
    { SPR_PTR_EXPLODE_DV_1, "explode_dv_1.bin" },
    { SPR_PTR_EXPLODE_DV_2, "explode_dv_2.bin" },
    { SPR_PTR_EXPLODE_DV_3, "explode_dv_3.bin" },
    { SPR_PTR_EXPLODE_DH_1, "explode_dh_1.bin" },
    { SPR_PTR_EXPLODE_DH_2, "explode_dh_2.bin" },
    { SPR_PTR_EXPLODE_DH_3, "explode_dh_3.bin" },
};
const char *const spr_player_bins[4] = {
    "player_left.bin",
    "player_right.bin",
    "player_up.bin",
    "player_down.bin",
};


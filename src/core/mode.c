#include "mode.h"

#include "game_init.h"
#include "gameover.h"
#include "hiscore.h"
#include "instructions.h"
#include "life.h"
#include "play.h"
#include "stage.h"
#include "story.h"
#include "title.h"

static void (*const mode_enter_table[MODE_COUNT])(Game *) = {
    title_gfx_enter,
    game_init_enter,
    stage_init_enter,
    play_enter,
    next_wave_enter,
    next_level_enter,
    next_life_enter,
    gameover_enter,
    hiscore_enter,
    title_text_enter,
    story_enter,
    instructions_enter,
};

static void (*const mode_update_table[MODE_COUNT])(Game *) = {
    title_gfx_update,
    game_init_update,
    stage_init_update,
    play_update,
    next_wave_update,
    next_level_update,
    next_life_update,
    gameover_update,
    hiscore_update,
    title_text_update,
    story_update,
    instructions_update,
};

static const char *const mode_names[MODE_COUNT] = {
    "MODE_TITLE_GFX",
    "MODE_GAME_INIT",
    "MODE_STAGE_INIT",
    "MODE_PLAY",
    "MODE_NEXT_WAVE",
    "MODE_NEXT_LEVEL",
    "MODE_NEXT_LIFE",
    "MODE_GAME_OVER",
    "MODE_HISCORE",
    "MODE_TITLE_TEXT",
    "MODE_STORY",
    "MODE_INSTRUCTIONS",
};

const char *mode_name(uint8_t mode) {
    if (mode >= MODE_COUNT) {
        return "MODE_INVALID";
    }
    return mode_names[mode];
}

void mode_set(Game *g, uint8_t mode) {
    g->mode = mode;
    g->mode_timer = 0;
    g->mode_state = 0;
    if (mode < MODE_COUNT) {
        mode_enter_table[mode](g);
    }
}

void mode_run(Game *g) {
    if (g->mode >= MODE_COUNT) {
        g->mode = MODE_TITLE_TEXT;
    }
    mode_update_table[g->mode](g);
}

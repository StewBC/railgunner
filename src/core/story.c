#include "story.h"

#include "cells.h"
#include "data/tables.h"
#include "mode.h"
#include "music.h"
#include "sfx.h"
#include "typewriter.h"

void story_enter(Game *g) {
    music_stop(g);
    g->present = PRESENT_TEXT;
    screen_clear(g);
    g->type_src = story_text;
    typewriter_init(g);
}

void story_update(Game *g) {
    typewriter_update(g);
    if (g->mode_state != STORY_STATE_DONE) {
        return;
    }
    if (g->mode_timer != 0) {
        return;
    }
    if (!g->input_fire_edge) {
        return;
    }
    sfx_play(g, SFX_UI_FIRE);
    mode_set(g, MODE_TITLE_TEXT);
}

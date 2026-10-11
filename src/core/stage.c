#include "stage.h"

#include "bullets.h"
#include "cargo.h"
#include "cells.h"
#include "drones.h"
#include "hud.h"
#include "mode.h"
#include "parcels.h"
#include "player.h"
#include "sfx.h"
#include "waves.h"

/* New game draws the undamaged cross, paints the live HUD, and enters play.
 * Rail redraw joins when that module owns the HP glyphs. */
void stage_init_enter(Game *g) {
    g->present = PRESENT_TEXT;
    screen_draw_playfield(g);
    bullets_init(g);
    drones_init(g);
    cargo_init(g);
    parcels_init(g);
    waves_load(g);
    player_begin_deploy(g);
    hud_paint_full_line(g);
    hud_color_static(g);
    sfx_play(g, SFX_WAVE);
    mode_set(g, MODE_PLAY);
}

void stage_init_update(Game *g) {
    (void)g;
}

#include "gameover.h"

#include "hiscore.h"
#include "mode.h"
#include "objects.h"
#include "sfx.h"
#include "tallies.h"

void gameover_enter(Game *g) {
    /* Border colour is not core state. */
    objects_hide_all(g);
    screen_clear(g);
    tallies_paint_gameover(g);
    g->mode_timer = 30;
}

void gameover_update(Game *g) {
    if (g->mode_timer != 0) {
        g->mode_timer--;
        return;
    }
    if (!g->input_fire_edge && !g->input_fire) {
        return;
    }
    sfx_play(g, SFX_UI_FIRE);
    if (hiscore_qualifies(g)) {
        mode_set(g, MODE_HISCORE);
    } else {
        mode_set(g, MODE_TITLE_TEXT);
    }
}

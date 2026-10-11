#include "sim.h"

#include "hiscore.h"
#include "input.h"
#include "mode.h"
#include "music.h"
#include "objects.h"
#include "sfx.h"
#include "title.h"

#include <string.h>

void sim_init(Game *g) {
    memset(g, 0, sizeof(*g));
    /* Boot calls hiscore_reset. It is empty: the line buffers are the
     * data segment, seeded when the process starts, not on each boot call. */
    hiscore_reset(g);
    /* Ids must be SFX_FREE before the title gates a note. 0 is UI fire. */
    sfx_init(g);
    /* cold_init stores MODE_TITLE_GFX and calls the enter directly. */
    g->mode = MODE_TITLE_GFX;
    title_gfx_enter(g);
}

void sim_tick(Game *g) {
    /* main.asm reaps before input and the mode update. */
    objects_reap(g);
    input_poll(g);
    mode_run(g);
    /* main.asm updates audio before this logic. The port runs it here, on
     * the same 50 Hz tick, so a PAL frame that is only a logic tick still
     * advances the tune. sfx then music: a voice freed this tick is
     * unmuted before the music timer moves. */
    sfx_update(g);
    music_update(g);
    g->frame++;
}

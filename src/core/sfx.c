#include "sfx.h"

#include "data/tables.h"
#include "music.h"

static const uint8_t *step_at(const Game *g, int v) {
    return sfx_steps[g->sfx_id[v]] + (unsigned)g->sfx_phase[v] * SFX_STEP_LEN;
}

static void voice_write(Game *g, int v, uint8_t fl, uint8_t fh, uint8_t ad,
                        uint8_t sr) {
    g->sid_freq[v] = (uint16_t)(fl | ((unsigned)fh << 8));
    g->sid_ad[v] = ad;
    g->sid_sr[v] = sr;
    g->sid_ctrl[v] = (uint8_t)(g->sfx_wave[v] | SID_GATE);
    g->sid_gen[v]++;
}

static void voice_cut(Game *g, int v) {
    g->sid_ctrl[v] = 0;
    g->sfx_id[v] = SFX_FREE;
    g->sfx_state[v] = 0;
    g->sfx_timer[v] = 0;
    g->sfx_phase[v] = 0;
}

static void voice_free(Game *g, int v) {
    g->sid_ctrl[v] = 0;
    g->sfx_id[v] = SFX_FREE;
    g->sfx_state[v] = 0;
    g->sfx_timer[v] = 0;
    g->sfx_phase[v] = 0;
    music_unmute_voice(g, (uint8_t)v);
}

/* Wave byte 0 ends the effect. A live step gates the voice. */
static void start_step(Game *g, int v) {
    const uint8_t *step = step_at(g, v);
    uint8_t wave = step[2];

    if (wave == 0) {
        voice_free(g, v);
        return;
    }
    g->sfx_wave[v] = wave;
    g->sfx_timer[v] = step[5];
    voice_write(g, v, step[0], step[1], step[3], step[4]);
    g->sfx_state[v] = 1;
}

static uint8_t gap_for_phase(const Game *g, int v) {
    return step_at(g, v)[6];
}

/* +$40 each gate frame on the swoosh / whoop ids. 16-bit wrap. */
static void slide_if_needed(Game *g, int v) {
    uint8_t id = g->sfx_id[v];

    if (id != SFX_PARCEL && id != SFX_WAVE && id != SFX_HEAL) {
        return;
    }
    g->sid_freq[v] = (uint16_t)(g->sid_freq[v] + 0x40);
}

static void play_use(Game *g, int v, uint8_t id) {
    music_mute_voice(g, (uint8_t)v);
    g->sfx_id[v] = id;
    g->sfx_phase[v] = 0;
    start_step(g, v);
}

void sfx_init(Game *g) {
    int v;

    for (v = 0; v < MUSIC_VOICES; v++) {
        g->sfx_id[v] = SFX_FREE;
        g->sfx_phase[v] = 0;
        g->sfx_timer[v] = 0;
        g->sfx_state[v] = 0;
        g->sfx_wave[v] = 0;
        g->sid_freq[v] = 0;
        g->sid_pw[v] = MUSIC_PULSE_WIDTH;
        g->sid_ctrl[v] = 0;
        g->sid_ad[v] = 0;
        g->sid_sr[v] = 0;
    }
}

void sfx_play(Game *g, uint8_t id) {
    int v;
    int steal_v = -1;
    uint8_t steal_id = 0;

    if (id >= SFX_COUNT) {
        return;
    }
    for (v = 0; v < MUSIC_VOICES; v++) {
        if (g->sfx_id[v] == SFX_FREE) {
            play_use(g, v, id);
            return;
        }
    }
    /* Lowest priority is the largest id strictly above the new one.
     * Same id is not stolen. An equal candidate replaces the previous. */
    for (v = 0; v < MUSIC_VOICES; v++) {
        uint8_t cur = g->sfx_id[v];

        if (cur <= id) {
            continue;
        }
        if (steal_v < 0 || cur >= steal_id) {
            steal_id = cur;
            steal_v = v;
        }
    }
    if (steal_v < 0) {
        return;
    }
    voice_cut(g, steal_v);
    play_use(g, steal_v, id);
}

void sfx_update(Game *g) {
    int v;

    for (v = 0; v < MUSIC_VOICES; v++) {
        if (g->sfx_id[v] == SFX_FREE) {
            continue;
        }
        if (g->sfx_timer[v] != 0) {
            g->sfx_timer[v]--;
            if (g->sfx_state[v] == 1) {
                slide_if_needed(g, v);
            }
            continue;
        }
        if (g->sfx_state[v] == 1) {
            g->sid_ctrl[v] = g->sfx_wave[v];
            g->sfx_state[v] = 2;
            g->sfx_timer[v] = gap_for_phase(g, v);
            continue;
        }
        g->sfx_phase[v]++;
        start_step(g, v);
    }
}

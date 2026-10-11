#include "music.h"

#include "data/tables.h"

static void load_next_note(Game *g, int v) {
    const uint8_t *trk = music_tracks[v];
    uint8_t pos = g->mus_pos[v];

    if (trk[pos] == 0xFF) {
        pos = 0;
    }
    g->mus_timer[v] = trk[pos];
    g->mus_lo[v] = trk[pos + 1];
    g->mus_hi[v] = trk[pos + 2];
    g->mus_pos[v] = (uint8_t)(pos + 3);
    g->mus_wave[v] = music_wave[v];
}

/* Gate clear then gate set is the SID retrigger. The published control
 * byte only shows the set, so sid_gen counts the restart for the host. */
static void apply_voice(Game *g, int v) {
    uint8_t wave;

    if (!g->music_active || g->mus_mute[v] || g->sfx_id[v] != SFX_FREE) {
        return;
    }
    if (g->mus_lo[v] == 0 && g->mus_hi[v] == 0) {
        g->sid_ctrl[v] = 0;
        return;
    }
    wave = g->mus_wave[v];
    g->sid_freq[v] = (uint16_t)(g->mus_lo[v] | ((unsigned)g->mus_hi[v] << 8));
    g->sid_pw[v] = MUSIC_PULSE_WIDTH;
    g->sid_ad[v] = music_ad[v];
    g->sid_sr[v] = music_sr[v];
    g->sid_ctrl[v] = wave;
    g->sid_ctrl[v] = (uint8_t)(wave | SID_GATE);
    g->sid_gen[v]++;
}

void music_mute_voice(Game *g, uint8_t voice) {
    g->mus_mute[voice] = 1;
}

void music_unmute_voice(Game *g, uint8_t voice) {
    g->mus_mute[voice] = 0;
    if (g->music_active) {
        apply_voice(g, voice);
    }
}

void music_start_title(Game *g) {
    int v;

    if (g->music_active) {
        return;
    }
    g->music_active = 1;
    for (v = 0; v < MUSIC_VOICES; v++) {
        g->mus_mute[v] = 0;
        g->mus_pos[v] = 0;
        g->mus_timer[v] = 0;
        g->mus_lo[v] = 0;
        g->mus_hi[v] = 0;
        /* v_cur_wave is left alone in the assembly clear loop. */
    }
    for (v = 0; v < MUSIC_VOICES; v++) {
        load_next_note(g, v);
        apply_voice(g, v);
    }
}

void music_stop(Game *g) {
    int v;

    if (!g->music_active) {
        return;
    }
    g->music_active = 0;
    for (v = 0; v < MUSIC_VOICES; v++) {
        if (!g->mus_mute[v]) {
            g->sid_ctrl[v] = 0;
        }
        g->mus_mute[v] = 0;
        g->mus_timer[v] = 0;
        g->mus_pos[v] = 0;
    }
}

void music_update(Game *g) {
    int v;

    if (!g->music_active) {
        return;
    }
    for (v = 0; v < MUSIC_VOICES; v++) {
        if (g->mus_timer[v] != 0) {
            g->mus_timer[v]--;
            continue;
        }
        load_next_note(g, v);
        apply_voice(g, v);
    }
}

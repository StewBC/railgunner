#include "audio.h"

#include <SDL.h>

#include <stdlib.h>
#include <string.h>

/* PAL SID clock. Hz = freq_word * SID_CLOCK / 2^24. */
#define SID_CLOCK 985248

enum { ENV_ATTACK, ENV_DECAY, ENV_SUSTAIN, ENV_RELEASE };

/* PAL ADSR times, milliseconds, nibble 0..15. Attack is 0→peak.
 * Decay and release are peak→0. */
static const int attack_ms[16] = {
    2, 8, 16, 24, 38, 56, 68, 80, 100, 250, 500, 800, 1000, 3000, 5000, 8000
};
static const int decay_ms[16] = {
    6, 24, 48, 72, 114, 168, 204, 240, 300, 750, 1500, 2400, 3000, 9000,
    15000, 24000
};

struct AudioEnv {
    int rate;
    double level[MUSIC_VOICES];
    int state[MUSIC_VOICES];
    uint32_t gen[MUSIC_VOICES];
    uint8_t gate[MUSIC_VOICES];
    uint32_t phase[MUSIC_VOICES];
    uint32_t lfsr[MUSIC_VOICES];
    int clock_rem[MUSIC_VOICES];
};

static SDL_AudioDeviceID dev_id;
static SDL_mutex *pub_mutex;
static AudioEnv *dev_env;
static SidVoice published[MUSIC_VOICES];

static int noise_s16(uint32_t sr) {
    unsigned n = ((sr & 0x400000u) >> 15) | ((sr & 0x100000u) >> 14) |
                 ((sr & 0x010000u) >> 11) | ((sr & 0x002000u) >> 9) |
                 ((sr & 0x000800u) >> 8) | ((sr & 0x000080u) >> 5) |
                 ((sr & 0x000020u) >> 3) | ((sr & 0x000004u) >> 2);
    return ((int)n - 128) << 8;
}

static void clock_osc(AudioEnv *env, int i, uint16_t freq, int noise) {
    int clocks = SID_CLOCK / env->rate;
    int c;

    env->clock_rem[i] += SID_CLOCK % env->rate;
    if (env->clock_rem[i] >= env->rate) {
        env->clock_rem[i] -= env->rate;
        clocks++;
    }
    for (c = 0; c < clocks; c++) {
        uint32_t prev = env->phase[i];
        env->phase[i] = (prev + freq) & 0xFFFFFFu;
        if (noise && (prev & 0x80000u) == 0 && (env->phase[i] & 0x80000u) != 0) {
            uint32_t sr = env->lfsr[i];
            uint32_t bit0 = ((sr >> 22) ^ (sr >> 17)) & 1u;
            env->lfsr[i] = ((sr << 1) | bit0) & 0x7FFFFFu;
        }
    }
}

static int osc_sample(const AudioEnv *env, int i, const SidVoice *v) {
    uint32_t phase = env->phase[i];
    uint8_t wave = v->wave;

    if (wave & SID_WAVE_NOISE) {
        return noise_s16(env->lfsr[i]);
    }
    if (wave & SID_WAVE_PULSE) {
        unsigned top = (phase >> 12) & 0xFFFu;
        unsigned pw = v->pw & 0xFFFu;
        return top >= pw ? 32767 : -32768;
    }
    if (wave & SID_WAVE_SAW) {
        return (int)(phase >> 8) - 32768;
    }
    if (wave & SID_WAVE_TRI) {
        uint32_t fold = (phase & 0x800000u) ? (phase ^ 0xFFFFFFu) : phase;
        return (int)(fold >> 7) - 32768;
    }
    return 0;
}

static void env_advance(AudioEnv *env, int i, const SidVoice *v) {
    int gate = v->gate ? 1 : 0;
    int rising = gate && !env->gate[i];
    double sustain;
    double ms;

    if ((v->gen != env->gen[i] || rising) && gate) {
        env->state[i] = ENV_ATTACK;
        env->level[i] = 0;
    } else if (!gate && env->gate[i]) {
        env->state[i] = ENV_RELEASE;
    }
    env->gen[i] = v->gen;
    env->gate[i] = (uint8_t)gate;

    sustain = ((v->sr >> 4) & 15) / 15.0;
    if (env->state[i] == ENV_ATTACK) {
        ms = attack_ms[(v->ad >> 4) & 15];
        env->level[i] += 1000.0 / (ms * env->rate);
        if (env->level[i] >= 1.0) {
            env->level[i] = 1.0;
            env->state[i] = ENV_DECAY;
        }
    } else if (env->state[i] == ENV_DECAY) {
        ms = decay_ms[v->ad & 15];
        env->level[i] -= 1000.0 / (ms * env->rate);
        if (env->level[i] <= sustain) {
            env->level[i] = sustain;
            env->state[i] = ENV_SUSTAIN;
        }
    } else if (env->state[i] == ENV_SUSTAIN) {
        env->level[i] = sustain;
    } else {
        ms = decay_ms[v->sr & 15];
        env->level[i] -= 1000.0 / (ms * env->rate);
        if (env->level[i] < 0) {
            env->level[i] = 0;
        }
    }
}

AudioEnv *audio_env_new(int rate) {
    AudioEnv *env = calloc(1, sizeof(*env));
    int i;

    if (env == NULL) {
        return NULL;
    }
    env->rate = rate > 0 ? rate : 44100;
    for (i = 0; i < MUSIC_VOICES; i++) {
        env->lfsr[i] = 0x7FFFFFu;
        env->state[i] = ENV_RELEASE;
    }
    return env;
}

void audio_env_free(AudioEnv *env) {
    free(env);
}

void audio_render(AudioEnv *env, int16_t *stereo, int frames,
                  const SidVoice v[MUSIC_VOICES]) {
    int f;

    if (env == NULL || stereo == NULL || frames <= 0 || env->rate <= 0) {
        return;
    }
    for (f = 0; f < frames; f++) {
        double mix = 0;
        int i;
        int32_t out;

        for (i = 0; i < MUSIC_VOICES; i++) {
            int osc;
            clock_osc(env, i, v[i].freq, (v[i].wave & SID_WAVE_NOISE) != 0);
            env_advance(env, i, &v[i]);
            osc = osc_sample(env, i, &v[i]);
            mix += osc * env->level[i] * (SID_VOL_MAX / 15.0);
        }
        mix /= MUSIC_VOICES;
        if (mix > 32767.0) {
            mix = 32767.0;
        } else if (mix < -32768.0) {
            mix = -32768.0;
        }
        out = (int32_t)mix;
        stereo[f * 2] = (int16_t)out;
        stereo[f * 2 + 1] = (int16_t)out;
    }
}

static void audio_cb(void *userdata, Uint8 *stream, int len) {
    AudioEnv *env = userdata;
    SidVoice snap[MUSIC_VOICES];
    int frames = len / (int)(2 * sizeof(int16_t));

    memset(stream, 0, (size_t)len);
    memset(snap, 0, sizeof snap);
    /* The device lock from this callback deadlocks. Copy, then render. */
    if (pub_mutex != NULL && SDL_LockMutex(pub_mutex) == 0) {
        memcpy(snap, published, sizeof snap);
        SDL_UnlockMutex(pub_mutex);
    }
    audio_render(env, (int16_t *)stream, frames, snap);
}

int audio_open(void) {
    SDL_AudioSpec want;
    SDL_AudioSpec have;

    if (dev_id != 0) {
        return 0;
    }
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        return -1;
    }
    dev_env = audio_env_new(44100);
    pub_mutex = SDL_CreateMutex();
    if (dev_env == NULL || pub_mutex == NULL) {
        audio_close();
        return -1;
    }
    memset(&want, 0, sizeof want);
    want.freq = 44100;
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = audio_cb;
    want.userdata = dev_env;
    dev_id = SDL_OpenAudioDevice(NULL, 0, &want, &have,
                                 SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);
    if (dev_id == 0 || have.format != AUDIO_S16SYS || have.channels != 2) {
        audio_close();
        return -1;
    }
    dev_env->rate = have.freq > 0 ? (int)have.freq : 44100;
    SDL_PauseAudioDevice(dev_id, 0);
    return 0;
}

void audio_close(void) {
    if (dev_id != 0) {
        SDL_CloseAudioDevice(dev_id);
        dev_id = 0;
    }
    if (pub_mutex != NULL) {
        SDL_DestroyMutex(pub_mutex);
        pub_mutex = NULL;
    }
    audio_env_free(dev_env);
    dev_env = NULL;
    memset(published, 0, sizeof published);
}

void audio_publish(const Game *g) {
    SidVoice snap[MUSIC_VOICES];
    int i;

    if (pub_mutex == NULL || g == NULL) {
        return;
    }
    for (i = 0; i < MUSIC_VOICES; i++) {
        uint8_t ctrl = g->sid_ctrl[i];
        snap[i].freq = g->sid_freq[i];
        snap[i].pw = g->sid_pw[i];
        snap[i].wave = (uint8_t)(ctrl & (uint8_t)~SID_GATE);
        snap[i].gate = (uint8_t)(ctrl & SID_GATE);
        snap[i].ad = g->sid_ad[i];
        snap[i].sr = g->sid_sr[i];
        snap[i].gen = g->sid_gen[i];
    }
    if (SDL_LockMutex(pub_mutex) == 0) {
        memcpy(published, snap, sizeof snap);
        SDL_UnlockMutex(pub_mutex);
    }
}

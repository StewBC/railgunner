#ifndef RAILGUNNER_AUDIO_H
#define RAILGUNNER_AUDIO_H

#include "sim.h"

#include <stdint.h>

/* One published SID voice. The 50 Hz tick writes these. The callback
 * only reads them. */
typedef struct SidVoice {
    uint16_t freq;
    uint16_t pw;
    uint8_t wave;
    uint8_t gate;
    uint8_t ad;
    uint8_t sr;
    uint32_t gen;
} SidVoice;

typedef struct AudioEnv AudioEnv;

/* 0 on success. Failure leaves the game silent. */
int audio_open(void);
void audio_close(void);
void audio_publish(const Game *g);

AudioEnv *audio_env_new(int rate);
void audio_env_free(AudioEnv *env);
/* Interleaved stereo int16. `frames` is the number of sample pairs. */
void audio_render(AudioEnv *env, int16_t *stereo, int frames,
                  const SidVoice v[MUSIC_VOICES]);

#endif

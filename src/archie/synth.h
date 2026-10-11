#ifndef RG_ARCHIE_SYNTH_H
#define RG_ARCHIE_SYNTH_H
#include "sim.h"
#include <stdint.h>
typedef struct {
    uint16_t freq,pw;
    uint8_t wave,gate,ad,sr;
    uint32_t gen;
} RgVoice;
typedef struct {
    uint32_t phase,lfsr,level,gen;
    unsigned state,gate;
    uint32_t cached_gain;
    int32_t noise_scaled[256];
} RgOsc;
typedef struct {
    unsigned rate,clock_base,clock_mod,clock_rem;
    uint32_t attack[16],decay[16];
    RgOsc osc[MUSIC_VOICES];
} RgSynth;
typedef struct { uint32_t clocks,envelope,oscillator,mix; } RgSynthTimings;
void rg_synth_profile(RgSynthTimings *timings,uint32_t (*timer)(void));
void rg_synth_init(RgSynth *s,unsigned rate);
void rg_synth_snapshot(RgVoice v[MUSIC_VOICES],const Game *g);
void rg_synth_render(RgSynth *s,const RgVoice v[MUSIC_VOICES],int16_t *mono,unsigned count);
void rg_synth_render_scalar(RgSynth *s,const RgVoice v[MUSIC_VOICES],int16_t *mono,unsigned count);
uint32_t rg_noise_jump(uint32_t sr,unsigned count);
#endif

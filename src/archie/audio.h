#ifndef RG_ARCHIE_AUDIO_H
#define RG_ARCHIE_AUDIO_H
#include "synth.h"
typedef struct { volatile uint32_t write,read,calls,underruns,played,period,dma_end,stride,dma_start,last_count; uint8_t ring[1024]; } RgAudioRing;
typedef struct {
    RgSynth synth;
    RgAudioRing *ring;
    void *block;
    unsigned rate,period,buffer_bytes,voice;
    int configured,installed,attached,settings_saved,enabled,old_voice;
    int old_config[5],old_enable,old_speaker,old_volume,old_voices[8];
    uint8_t log[8192];
    int16_t samples[208];
} RgAudio;
int rg_audio_open(RgAudio *a);
int rg_audio_start(RgAudio *a,const RgVoice v[3]);
void rg_audio_generate(RgAudio *a,const RgVoice v[3],unsigned count);
void rg_audio_refill(RgAudio *a,const RgVoice v[3]);
int rg_audio_stop(RgAudio *a);
int rg_audio_close(RgAudio *a);
const char *rg_audio_error(void);
#endif

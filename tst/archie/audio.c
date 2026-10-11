#include "synth.h"
#include "music.h"
#include "sfx.h"
#include "../../src/sdl/audio.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
uint32_t reference_phase(AudioEnv *,int);
uint32_t reference_noise(AudioEnv *,int);
int main(void) {
    uint32_t seed=1;
    for(unsigned n=0;n<100000;n++) {
        seed=seed*1664525+1013904223;
        for(unsigned k=0;k<=4;k++) {
            uint32_t sr=seed&0x7fffff;
            for(unsigned j=0;j<k;j++) sr=((sr<<1)|(((sr>>22)^(sr>>17))&1))&0x7fffff;
            assert(sr==rg_noise_jump(seed&0x7fffff,k));
        }
    }
    unsigned max_error=0; uint64_t sum_error=0,samples=0;
    unsigned waves[]={SID_WAVE_PULSE,SID_WAVE_TRI,SID_WAVE_SAW,SID_WAVE_NOISE};
    for(unsigned w=0;w<4;w++) {
        RgSynth synth; rg_synth_init(&synth,20833);
        AudioEnv *reference=audio_env_new(20833); assert(reference);
        RgVoice voices[3]={{0}}; SidVoice ref[3]={{0}};
        int16_t mono[417],stereo[834];
        for(unsigned tick=0;tick<600;tick++) {
            for(unsigned i=0;i<3;i++) {
                voices[i].freq=(uint16_t)(1000+tick*97+i*13001);
                voices[i].pw=(uint16_t)((tick*13+i*900)&4095);
                voices[i].wave=waves[(w+i)%4]; voices[i].gate=tick%150<100;
                voices[i].ad=(uint8_t)(0x28+i*0x11); voices[i].sr=(uint8_t)(0x84+i*0x21);
                voices[i].gen=tick/150;
                ref[i]=(SidVoice){voices[i].freq,voices[i].pw,voices[i].wave,voices[i].gate,voices[i].ad,voices[i].sr,voices[i].gen};
            }
            rg_synth_render(&synth,voices,mono,417); audio_render(reference,stereo,417,ref);
            for(unsigned i=0;i<3;i++) { assert(synth.osc[i].phase==reference_phase(reference,i)); assert(synth.osc[i].lfsr==reference_noise(reference,i)); }
            for(unsigned i=0;i<417;i++) { unsigned e=(unsigned)abs(mono[i]-stereo[2*i]); if(e>max_error) max_error=e; sum_error+=e; samples++; }
        }
        audio_env_free(reference);
    }
    /* Exercise actual sequencers, all effects, steals and title resumption. */
    Game game; sim_init(&game); music_start_title(&game);
    RgSynth synth; rg_synth_init(&synth,20833);
    AudioEnv *reference=audio_env_new(20833); assert(reference);
    for(unsigned tick=0;tick<3000;tick++) {
        if(tick%37==0) sfx_play(&game,(uint8_t)((tick/37)%SFX_COUNT));
        music_update(&game); sfx_update(&game);
        RgVoice voices[3]; SidVoice ref[3]; rg_synth_snapshot(voices,&game);
        for(unsigned i=0;i<3;i++) ref[i]=(SidVoice){voices[i].freq,voices[i].pw,voices[i].wave,voices[i].gate,voices[i].ad,voices[i].sr,voices[i].gen};
        int16_t mono[417],stereo[834];
        rg_synth_render(&synth,voices,mono,417); audio_render(reference,stereo,417,ref);
        for(unsigned i=0;i<3;i++) { assert(synth.osc[i].phase==reference_phase(reference,i)); assert(synth.osc[i].lfsr==reference_noise(reference,i)); }
        for(unsigned i=0;i<417;i++) { unsigned e=(unsigned)abs(mono[i]-stereo[2*i]); if(e>max_error) max_error=e; sum_error+=e; samples++; }
    }
    audio_env_free(reference);
    printf("Audio reference: %llu samples; exact oscillator/noise; max error=%u mean=%.3f signed-16 units\n",(unsigned long long)samples,max_error,(double)sum_error/samples);
    assert(max_error<=100);
}

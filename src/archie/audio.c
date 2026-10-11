#include "audio.h"
#include <kernel.h>
#include <swis.h>
#include <oslib/sound.h>
#include <string.h>
#include <stdlib.h>
#include <stddef.h>
_Static_assert(offsetof(RgAudioRing,ring)==40,"Native sound voice ring ABI");
extern const uint8_t rg_voice_start[],rg_voice_end[],rg_voice_state[];
static char error[252];
static RgAudio *active;
static void cleanup(void) { if(active && !rg_audio_close(active)) abort(); }
const char *rg_audio_error(void) { return error; }
static int call(int swi,_kernel_swi_regs *r) {
    _kernel_oserror *e=_kernel_swi(swi,r,r);
    if(!e) return 1;
    memcpy(error,e->errmess,sizeof error); error[sizeof error-1]=0; return 0;
}
static int state(int swi,int value,int *previous) {
    _kernel_swi_regs r={{0}}; r.r[0]=value;
    if(!call(swi,&r)) return 0;
    if(previous) *previous=r.r[0];
    return 1;
}
int rg_audio_stop(RgAudio *a) {
    if(!state(Sound_Enable,sound_STATE_OFF,NULL)) return 0;
    a->enabled=0; return 1;
}
int rg_audio_close(RgAudio *a) {
    _kernel_swi_regs r={{0}}; int ok=1;
    if(a->attached || a->enabled) {
        if(!state(Sound_Enable,sound_STATE_OFF,NULL)) return 0;
        a->enabled=0;
    }
    if(a->attached) {
        r.r[0]=1; r.r[1]=0;
        if(!call(Sound_AttachVoice,&r)) return 0;
        a->attached=0;
    }
    if(a->installed) {
        r.r[0]=(int)a->block; r.r[1]=(int)a->voice;
        if(!call(Sound_RemoveVoice,&r) || r.r[1]==0) return 0;
        a->installed=0;
    }
    if(a->block) {
        r.r[0]=7; r.r[2]=(int)a->block;
        if(!call(OS_Module,&r)) return 0;
        a->block=NULL; a->ring=NULL;
    }
    if(a->configured) {
        memset(&r,0,sizeof r); for(unsigned i=0;i<5;i++) r.r[i]=a->old_config[i];
        ok&=call(Sound_Configure,&r); a->configured=0;
        for(int i=0;i<a->old_config[0] && i<8;i++) {
            memset(&r,0,sizeof r); r.r[0]=i+1; r.r[1]=a->old_voices[i];
            ok&=call(Sound_AttachVoice,&r) && r.r[0]!=0;
        }
    }
    if(a->settings_saved) {
        ok&=state(Sound_Volume,a->old_volume,NULL);
        ok&=state(Sound_Speaker,a->old_speaker,NULL);
        ok&=state(Sound_Enable,a->old_enable,NULL);
        a->settings_saved=0;
    }
    if(ok && active==a) active=NULL;
    return ok;
}
int rg_audio_open(RgAudio *a) {
    _kernel_swi_regs r={{0}};
    if(active) { strcpy(error,"Native audio already open"); return 0; }
    memset(a,0,sizeof *a);
    if(!active) { static int registered; if(!registered) { atexit(cleanup); registered=1; } }
    active=a;
    if(!state(Sound_Enable,sound_STATE_READ,&a->old_enable) ||
       !state(Sound_Speaker,sound_STATE_READ,&a->old_speaker) ||
       !state(Sound_Volume,0,&a->old_volume)) { active=NULL; return 0; }
    a->settings_saved=1;
    if(!state(Sound_Enable,sound_STATE_OFF,NULL)) goto fail;
    if(!call(Sound_Configure,&r)) goto fail;
    for(unsigned i=0;i<5;i++) a->old_config[i]=r.r[i];
    for(int i=0;i<a->old_config[0] && i<8;i++) {
        memset(&r,0,sizeof r); r.r[0]=i+1;
        if(!call(Sound_ReadControlBlock,&r) || !r.r[0]) goto fail;
        a->old_voices[i]=(r.r[2]>>8)&255;
    }
    memset(&r,0,sizeof r); r.r[0]=1; r.r[1]=208; r.r[2]=48;
    if(!call(Sound_Configure,&r)) goto fail;
    a->configured=1;
    memset(&r,0,sizeof r);
    if(!call(Sound_Configure,&r)) goto fail;
    if(r.r[0]!=1 || r.r[1]!=208 || r.r[2]<40 || r.r[2]>64) {
        strcpy(error,"Unexpected native sound configuration"); goto fail;
    }
    a->buffer_bytes=(unsigned)r.r[1]; a->period=(unsigned)r.r[2];
    a->rate=(1000000u+a->period/2)/a->period;
    rg_synth_init(&a->synth,a->rate);
    if(!state(Sound_Volume,127,NULL)) goto fail;
    for(unsigned i=0;i<8192;i++) {
        memset(&r,0,sizeof r); r.r[0]=((int)i-4096)*524288;
        if(!call(Sound_SoundLog,&r)) goto fail;
        a->log[i]=(uint8_t)r.r[0];
    }
    memset(&r,0,sizeof r); r.r[0]=6; r.r[3]=(int)(rg_voice_end-rg_voice_start);
    if(!call(OS_Module,&r)) goto fail;
    a->block=(void *)r.r[2];
    memcpy(a->block,rg_voice_start,(size_t)(rg_voice_end-rg_voice_start));
    a->ring=(RgAudioRing *)((uint8_t *)a->block+(rg_voice_state-rg_voice_start));
    memset(&r,0,sizeof r); r.r[0]=(int)a->block;
    if(!call(Sound_InstallVoice,&r)) goto fail;
    if(r.r[1]==0) { strcpy(error,"Native sound voice installation rejected"); goto fail; }
    a->voice=(unsigned)r.r[1]; a->installed=1;
    memset(&r,0,sizeof r); r.r[0]=1; r.r[1]=(int)a->voice;
    if(!call(Sound_AttachVoice,&r) || !r.r[0]) goto fail;
    a->attached=1;
    return 1;
fail:
    /* Do not exit with a live IRQ referring to released application storage. */
    if(!rg_audio_close(a)) abort();
    return 0;
}
void rg_audio_generate(RgAudio *a,const RgVoice v[3],unsigned count) {
    uint32_t write=a->ring->write;
    while(count) {
        unsigned n=count>208?208:count;
        rg_synth_render(&a->synth,v,a->samples,n);
        for(unsigned i=0;i<n;i++) a->ring->ring[(write+i)&1023]=a->log[((int)a->samples[i]+32768)>>3];
        write+=n;
        __asm__ volatile("" ::: "memory");
        a->ring->write=write;
        count-=n;
    }
}
void rg_audio_refill(RgAudio *a,const RgVoice v[3]) {
    unsigned target=a->rate*40/1000;
    unsigned queued=a->ring->write-a->ring->read;
    if(queued<target) rg_audio_generate(a,v,target-queued);
}
int rg_audio_start(RgAudio *a,const RgVoice v[3]) {
    _kernel_swi_regs r={{0}};
    rg_audio_refill(a,v);
    if(!state(Sound_Speaker,sound_STATE_ON,NULL)) return 0;
    r.r[0]=1; r.r[1]=0x17f; r.r[2]=53; r.r[3]=10;
    if(!call(Sound_Control,&r)) return 0;
    if(!state(Sound_Enable,sound_STATE_ON,NULL)) return 0;
    a->enabled=1;
    return 1;
}

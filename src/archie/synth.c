/* SDL's linear ADSR and SID oscillator model, implemented with integer math.
 * Q24 envelope; exact whole-SID-clock phase and noise crossings. */
#include "synth.h"
#include <string.h>
#include <stddef.h>
_Static_assert(offsetof(RgOsc,phase)==0 && offsetof(RgOsc,lfsr)==4 &&
    offsetof(RgOsc,level)==8 && offsetof(RgOsc,state)==16,"ARM oscillator/envelope ABI");
#define CLOCK 985248u
#define PEAK 0x1000000u
enum { ATTACK,DECAY,SUSTAIN,RELEASE };
static const unsigned attack_ms[16]={2,8,16,24,38,56,68,80,100,250,500,800,1000,3000,5000,8000};
static const unsigned decay_ms[16]={6,24,48,72,114,168,204,240,300,750,1500,2400,3000,9000,15000,24000};
uint32_t rg_noise_jump(uint32_t sr,unsigned count) {
    /* Up to four shifts: incoming bits depend only on the old register. */
    if(!count) return sr;
    return ((sr<<count)|(((sr^(sr<<5))>>(23-count))&((1u<<count)-1)))&0x7fffffu;
}
void rg_synth_init(RgSynth *s,unsigned rate) {
    memset(s,0,sizeof *s);
    s->rate=rate?rate:20833;
    s->clock_base=CLOCK/s->rate; s->clock_mod=CLOCK%s->rate;
    for(unsigned i=0;i<16;i++) {
        /* 64-bit division only at startup, never in the sample loop. */
        s->attack[i]=(uint32_t)(((uint64_t)PEAK*1000+attack_ms[i]*s->rate/2)/(attack_ms[i]*s->rate));
        s->decay[i]=(uint32_t)(((uint64_t)PEAK*1000+decay_ms[i]*s->rate/2)/(decay_ms[i]*s->rate));
    }
    for(unsigned i=0;i<MUSIC_VOICES;i++) { s->osc[i].lfsr=0x7fffff; s->osc[i].state=RELEASE; }
}
void rg_synth_snapshot(RgVoice v[MUSIC_VOICES],const Game *g) {
    for(unsigned i=0;i<MUSIC_VOICES;i++) {
        v[i].freq=g->sid_freq[i]; v[i].pw=g->sid_pw[i];
        v[i].wave=g->sid_ctrl[i]&~SID_GATE; v[i].gate=!!(g->sid_ctrl[i]&SID_GATE);
        v[i].ad=g->sid_ad[i]; v[i].sr=g->sid_sr[i]; v[i].gen=g->sid_gen[i];
    }
}
static int noise(uint32_t sr) {
    unsigned n=((sr&0x400000)>>15)|((sr&0x100000)>>14)|((sr&0x10000)>>11)|((sr&0x2000)>>9)|((sr&0x800)>>8)|((sr&0x80)>>5)|((sr&0x20)>>3)|((sr&4)>>2);
    return ((int)n-128)*256;
}
static int envelope(RgSynth *s,RgOsc *o,const RgVoice *v,uint32_t *gain,unsigned count,int allow_fixed) {
    if((v->gen!=o->gen || !o->gate) && v->gate) { o->state=ATTACK; o->level=0; }
    else if(!v->gate && o->gate) o->state=RELEASE;
    o->gen=v->gen; o->gate=v->gate;
    uint32_t sustain=(v->sr>>4)*(PEAK/15u),level=o->level;
    if((v->sr>>4)==15) sustain=PEAK;
    unsigned state=o->state,up=s->attack[v->ad>>4],down=s->decay[v->ad&15],release=s->decay[v->sr&15];
    if(allow_fixed && state==RELEASE && !level) { gain[0]=0; return 1; }
    if(allow_fixed && state==SUSTAIN) { gain[0]=sustain>>9; o->level=sustain; return 1; }
#ifdef __arm__
    if(allow_fixed) {
        extern void rg_env_linear(RgOsc *,uint32_t *,unsigned,unsigned,unsigned,unsigned,unsigned);
        o->state=state;
        rg_env_linear(o,gain,count,up,down,release,sustain);
        return 0;
    }
#endif
    for(unsigned f=0;f<count;f++) {
        switch(state) {
        case ATTACK: level+=up; if(level>=PEAK) { level=PEAK; state=DECAY; } break;
        case DECAY: if(level<=sustain+down) { level=sustain; state=SUSTAIN; } else level-=down; break;
        case SUSTAIN: level=sustain; break;
        default: level=level>release?level-release:0; break;
        }
        gain[f]=(uint32_t)(level>>9);
    }
    o->level=level; o->state=state; return 0;
}
static inline __attribute__((always_inline)) int scaled(int sample,unsigned gain) {
#ifdef __arm__
    int product;
    /* ARM2 early termination examines Rs: use the positive 16-bit gain. */
    __asm__("mul %0,%1,%2" : "=&r"(product) : "r"(sample),"r"(gain));
    return product>>15;
#else
    return (sample*(int)gain)>>15;
#endif
}
static inline __attribute__((always_inline)) void oscillator(RgOsc *o,const RgVoice *v,unsigned base,
        const uint8_t *extra,const uint32_t *gain,int32_t *mix,unsigned count,unsigned wave) {
    uint32_t phase=o->phase,lfsr=o->lfsr,delta=base*v->freq;
    unsigned freq=v->freq,pw=v->pw&4095;
    for(unsigned f=0;f<count;f++) {
        uint32_t old=phase,advance=delta+(extra[f]?freq:0);
        phase=(old+advance)&0xffffff;
        int sample=0;
        if(wave==SID_WAVE_NOISE) {
            unsigned k=((old+advance+0x80000)>>20)-((old+0x80000)>>20);
            while(k>4) { lfsr=rg_noise_jump(lfsr,4); k-=4; }
            if(k) lfsr=((lfsr<<k)|(((lfsr^(lfsr<<5))>>(23-k))&((1u<<k)-1)))&0x7fffff;
            sample=noise(lfsr);
        } else if(wave==SID_WAVE_PULSE) sample=(phase>>12)>=pw?32767:-32768;
        else if(wave==SID_WAVE_SAW) sample=(int)(phase>>8)-32768;
        else if(wave==SID_WAVE_TRI) { uint32_t fold=(phase&0x800000)?phase^0xffffff:phase; sample=(int)(fold>>7)-32768; }
        mix[f]+=scaled(sample,gain[f]);
    }
    o->phase=phase; o->lfsr=lfsr;
}
#define OSC(name,wave) static void name(RgOsc *o,const RgVoice *v,unsigned base,const uint8_t *extra,const uint32_t *gain,int32_t *mix,unsigned count) { oscillator(o,v,base,extra,gain,mix,count,wave); }
OSC(osc_noise,SID_WAVE_NOISE)
OSC(osc_pulse,SID_WAVE_PULSE)
OSC(osc_saw,SID_WAVE_SAW)
OSC(osc_tri,SID_WAVE_TRI)
OSC(osc_silent,0)
#ifdef __arm__
#define NATIVE_OSC(name) extern void name(RgOsc *,const RgVoice *,unsigned,const uint8_t *,const uint32_t *,int32_t *,unsigned);
extern void rg_zero_mix(int32_t *);
NATIVE_OSC(rg_osc_pulse) NATIVE_OSC(rg_osc_saw) NATIVE_OSC(rg_osc_tri) NATIVE_OSC(rg_osc_noise)
#endif
static RgSynthTimings *profile;
static uint32_t (*profile_timer)(void);
void rg_synth_profile(RgSynthTimings *timings,uint32_t (*timer)(void)) { profile=timings; profile_timer=timer; }
static void render_block(RgSynth *s,const RgVoice v[MUSIC_VOICES],int16_t *mono,unsigned count,int native) {
    uint32_t begin=profile?profile_timer():0;
    int32_t mix[208]; uint8_t extra[208] __attribute__((aligned(4))); uint32_t gain[208];
#ifdef __arm__
    if(native) rg_zero_mix(mix); else memset(mix,0,sizeof mix);
#else
    memset(mix,0,sizeof mix);
#endif
    unsigned remainder=s->clock_rem;
#ifdef __arm__
    extern unsigned rg_clock_extras(unsigned,unsigned,unsigned,uint8_t *,unsigned);
    if(native) remainder=rg_clock_extras(s->rate,s->clock_mod,remainder,extra,count);
    else
#endif
    for(unsigned f=0;f<count;f++) {
        remainder+=s->clock_mod; extra[f]=(uint8_t)(remainder>=s->rate);
        if(extra[f]) remainder-=s->rate;
    }
    s->clock_rem=remainder;
    if(profile) profile->clocks+=profile_timer()-begin;
    for(unsigned i=0;i<MUSIC_VOICES;i++) {
        if(profile) begin=profile_timer();
        int allow_fixed=0;
#ifdef __arm__
        allow_fixed=native;
#endif
        int fixed=envelope(s,&s->osc[i],&v[i],gain,count,allow_fixed);
        if(profile) { profile->envelope+=profile_timer()-begin; begin=profile_timer(); }
        void (*osc)(RgOsc *,const RgVoice *,unsigned,const uint8_t *,const uint32_t *,int32_t *,unsigned)=osc_silent;
        unsigned wave=v[i].wave;
        if(native && (!(wave&(SID_WAVE_NOISE|SID_WAVE_PULSE|SID_WAVE_SAW|SID_WAVE_TRI)) || (fixed && !gain[0]))) {
            unsigned clocks=s->clock_base*count;
            for(unsigned f=0;f<count;f++) clocks+=extra[f];
            unsigned advance=clocks*v[i].freq,old=s->osc[i].phase;
            if(wave&SID_WAVE_NOISE) {
                unsigned k=((old+advance+0x80000)>>20)-((old+0x80000)>>20);
                while(k>4) { s->osc[i].lfsr=rg_noise_jump(s->osc[i].lfsr,4); k-=4; }
                s->osc[i].lfsr=rg_noise_jump(s->osc[i].lfsr,k);
            }
            s->osc[i].phase=(old+advance)&0xffffff;
            if(profile) profile->oscillator+=profile_timer()-begin;
            continue;
        }
        if(wave&SID_WAVE_NOISE) osc=osc_noise;
        else if(wave&SID_WAVE_PULSE) osc=osc_pulse;
        else if(wave&SID_WAVE_SAW) osc=osc_saw;
        else if(wave&SID_WAVE_TRI) osc=osc_tri;
#ifdef __arm__
        if(native) {
            if(wave&SID_WAVE_NOISE) osc=rg_osc_noise;
            else if(wave&SID_WAVE_PULSE) osc=rg_osc_pulse;
            else if(wave&SID_WAVE_SAW) osc=rg_osc_saw;
            else if(wave&SID_WAVE_TRI) osc=rg_osc_tri;
        }
#else
        (void)native;
#endif
        const uint32_t *gain_source=gain;
#ifdef __arm__
        if(native && fixed && (wave&SID_WAVE_NOISE)) {
            RgOsc *o=&s->osc[i];
            if(o->cached_gain!=gain[0]) {
                for(unsigned n=0;n<256;n++) o->noise_scaled[n]=scaled(((int)n-128)*256,gain[0]);
                o->cached_gain=gain[0];
            }
            gain_source=(const uint32_t *)o->noise_scaled;
        }
#endif
        osc(&s->osc[i],&v[i],s->clock_base,extra,gain_source,mix,count|(fixed?0x80000000u:0));
        if(profile) profile->oscillator+=profile_timer()-begin;
    }
    if(profile) begin=profile_timer();
    for(unsigned f=0;f<count;f++) mono[f]=(int16_t)((mix[f]*21845)>>16);
    if(profile) profile->mix+=profile_timer()-begin;
}
void rg_synth_render(RgSynth *s,const RgVoice v[MUSIC_VOICES],int16_t *mono,unsigned count) {
    while(count) {
        unsigned n=count>208?208:count;
        render_block(s,v,mono,n,1); mono+=n; count-=n;
    }
}

void rg_synth_render_scalar(RgSynth *s,const RgVoice v[MUSIC_VOICES],int16_t *mono,unsigned count) {
    while(count) { unsigned n=count>208?208:count; render_block(s,v,mono,n,0); mono+=n; count-=n; }
}

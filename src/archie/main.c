/* Phase 1 diagnostic, deliberately not a silent playable release. */
#include "video.h"
#include "sim.h"
#include "render.h"
#include "game_init.h"
#include "stage.h"
#include "mode.h"
#include "audio.h"
#include "input.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static Game game,late_game;
static void late_init(void) {
    sim_init(&late_game); game_init_enter(&late_game);
    late_game.level=MAX_LEVEL; stage_init_enter(&late_game);
}
static void late_tick(unsigned frame) {
    late_game.input_fire=1;
    late_game.input_dirs=(uint8_t)(1u<<((frame/125)&3));
    sim_tick(&late_game);
}
static ArchieRender renderer;
static RgAudio audio;
static void audio_checkpoint(const char *stage) {
    FILE *f=fopen("<RGDiag$Dir>.G3-checkpoint","w");
    if(f) { fputs(stage,f); fclose(f); }
}
static void audio_voices(RgVoice v[3],unsigned frame) {
    for(unsigned i=0;i<3;i++) {
        v[i]=(RgVoice){(uint16_t)(i==2?0x1400:0x1800+i*0x400+(frame&255)),(uint16_t)(900+i*800),
            (uint8_t)(i==2?SID_WAVE_NOISE:SID_WAVE_PULSE),1,0x02,0xf2,1};
    }
}
static int audio_diagnostic(void) {
    ArchieVideo video; RgVoice voices[3];
    audio_checkpoint("video startup\n");
    if(!archie_video_open(&video)) { fprintf(stderr,"%s\n",archie_video_error()); return 1; }
    audio_checkpoint("sound startup\n");
    if(!rg_audio_open(&audio)) { archie_video_close(); fprintf(stderr,"Audio: %s\n",rg_audio_error()); return 1; }
    audio_checkpoint("native scalar synthesis audit\n");
    RgSynth scalar; rg_synth_init(&scalar,audio.rate);
    int16_t expected[208];
    const unsigned waves[4]={SID_WAVE_PULSE,SID_WAVE_TRI,SID_WAVE_SAW,SID_WAVE_NOISE};
    for(unsigned f=0;f<128;f++) {
        for(unsigned i=0;i<3;i++) voices[i]=(RgVoice){(uint16_t)(65535-f*113-i*1900),(uint16_t)(f*17+i*911),
            (uint8_t)waves[(f/8+i)&3],(uint8_t)(f%29<22),(uint8_t)(0x12+i*0x11),(uint8_t)(0x84+i*0x21),f/23};
        rg_synth_render(&audio.synth,voices,audio.samples,208);
        rg_synth_render_scalar(&scalar,voices,expected,208);
        for(unsigned j=0;j<208;j++) if(audio.samples[j]!=expected[j]) {
            if(!rg_audio_close(&audio)) abort();
            archie_video_close();
            fprintf(stderr,"Native audio mismatch block %u sample %u: %d vs %d\n",f,j,audio.samples[j],expected[j]); return 1;
        }
        for(unsigned i=0;i<3;i++) if(audio.synth.osc[i].phase!=scalar.osc[i].phase || audio.synth.osc[i].lfsr!=scalar.osc[i].lfsr) {
            if(!rg_audio_close(&audio)) abort();
            archie_video_close();
            fprintf(stderr,"Native oscillator state mismatch block %u voice %u\n",f,i); return 1;
        }
    }
    rg_synth_init(&audio.synth,audio.rate);
    audio_checkpoint("synthesis batch\n");
    audio_voices(voices,0);
    uint32_t start=archie_time();
    for(unsigned f=0;f<1000;f++) {
        audio_voices(voices,f);
        audio.ring->read=audio.ring->write;
        rg_audio_generate(&audio,voices,416);
    }
    uint32_t batch=archie_time()-start;
    FILE *batch_report=fopen("<RGDiag$Dir>.G3-batch","w");
    if(batch_report) {
        fprintf(batch_report,"synth_encode_cs=%lu intervals=1000 rate=%u clock_base=%u clock_mod=%u native_scalar_audit_blocks=128\n",(unsigned long)batch,audio.rate,audio.synth.clock_base,audio.synth.clock_mod);
        fclose(batch_report);
    }
    RgSynthTimings stages={0};
    rg_synth_profile(&stages,archie_time);
    for(unsigned f=0;f<1000;f++) {
        audio_voices(voices,f); audio.ring->read=audio.ring->write;
        rg_audio_generate(&audio,voices,416);
    }
    rg_synth_profile(NULL,NULL);
    FILE *stage_report=fopen("<RGDiag$Dir>.G3-stages","w");
    if(stage_report) { fprintf(stage_report,"intervals=1000 clock_cs=%lu envelope_cs=%lu oscillator_cs=%lu mix_cs=%lu\n",(unsigned long)stages.clocks,(unsigned long)stages.envelope,(unsigned long)stages.oscillator,(unsigned long)stages.mix); fclose(stage_report); }
    audio_checkpoint("start native output\n");
    audio.ring->read=audio.ring->write=0;
    rg_synth_init(&audio.synth,audio.rate);
    audio_voices(voices,0);
    audio_checkpoint("paced output repeat; no active-output file I/O\n");
    rg_audio_refill(&audio,voices);
    archie_video_present(&video);
    int ok=rg_audio_start(&audio,voices);
    uint32_t refill_cs=0,missed=0,previous=archie_vsync_count();
    start=archie_time(); unsigned frames=0;
    unsigned limit=batch>400?100:3050;
    for(unsigned f=0;ok && f<limit;f++) {
        audio_voices(voices,f);
        uint32_t before=archie_time(); rg_audio_refill(&audio,voices); refill_cs+=archie_time()-before;
        ok=archie_video_present(&video);
        uint32_t now=archie_vsync_count(); if(now-previous>1) missed+=now-previous-1;
        previous=now; frames++;
    }
    uint32_t elapsed=archie_time()-start;
    ok&=rg_audio_stop(&audio);
    uint32_t dma_end=audio.ring->dma_end,dma_start=audio.ring->dma_start,stride=audio.ring->stride,last_count=audio.ring->last_count;
    uint32_t underruns=audio.ring->underruns,played=audio.ring->played,calls=audio.ring->calls,period=audio.ring->period;
    ok&=rg_audio_close(&audio);
    audio_checkpoint("sound cleanup complete\n");
    archie_video_close(); ok&=archie_video_restore_ok();
    FILE *report=fopen("<RGDiag$Dir>.G3-report","w"); if(!report) report=stdout;
    fprintf(report,"G3 native audio diagnostic\nrate=%u period_us=%u callback_config_raw=%lu dma_bytes=%u queue_target_ms=40 ring_bytes=1024\n"
        "two_pulse_one_noise_game_frequencies synth_encode_batch_cs=%lu intervals=1000 samples_per_interval=416\n"
        "frames=%u elapsed_cs=%lu refill_coarse_cs=%lu vsync_misses=%lu\nunderrun_samples=%lu played_samples=%lu fill_calls=%lu cleanup_ok=%d\n",
        audio.rate,audio.period,(unsigned long)period,audio.buffer_bytes,(unsigned long)batch,frames,(unsigned long)elapsed,(unsigned long)refill_cs,(unsigned long)missed,(unsigned long)underruns,(unsigned long)played,(unsigned long)calls,ok);
    fprintf(report,"dma_start=%08lx dma_end=%08lx stride=%lu last_count=%lu\n",(unsigned long)dma_start,(unsigned long)dma_end,(unsigned long)stride,(unsigned long)last_count);
    if(report!=stdout) fclose(report);
    puts("Native audio diagnostic finished; see G3-report.");
    return ok?0:1;
}
static void stress(unsigned f) {
    game.present=PRESENT_TEXT; game.mode=MODE_PLAY;
    unsigned x=f%345,y=f%210,c=(f*7)%1000,kind=0;
    for(unsigned s=0;s<24;s++) {
        Object *o=&game.objects[s];
        o->flags=OBJF_RENDER; o->kind=(uint8_t)kind;
        o->sprite_ptr=s==0?SPR_PTR_PLAYER_0:(uint8_t)(0xc0+s);
        o->sprite_attr=OBJA_MULTICOLOR; o->sprite_color=(uint8_t)((f+s)&15);
        o->x_lo=(uint8_t)x; o->x_hi=(uint8_t)(x>>8);
        o->y_int=(uint8_t)(40+y);
        x+=13; if(x>=345) x-=345;
        y+=7; if(y>=210) y-=210;
        if(++kind==6) kind=0;
    }
    game.player_frame=(uint8_t)(f&3);
    for(unsigned b=0;b<16;b++) {
        uint8_t *cell=(uint8_t *)game.cells+c*sizeof(Cell);
        cell[0]=(uint8_t)(SC_BULLET_FIRST+((f+b)&15));
        cell[1]=(uint8_t)((f+b)&15);
        c+=43; if(c>=1000) c-=1000;
    }
}
static void checker(uint8_t *p, unsigned bank) {
    int y,x;
    memset(p,0,ARCHIE_SCREEN_BYTES);
    for(y=0;y<200;y++) for(x=0;x<160;x++)
        p[(y+28)*160+x] = ((x/8+y/16+(int)bank)&1) ? 0x55 : 0x66;
}
static void publish_voices(RgVoice v[3]) {
    for(unsigned i=0;i<3;i++) v[i]=(RgVoice){game.sid_freq[i],game.sid_pw[i],
        (uint8_t)(game.sid_ctrl[i]&~SID_GATE),(uint8_t)(game.sid_ctrl[i]&SID_GATE),
        game.sid_ad[i],game.sid_sr[i],game.sid_gen[i]};
}
static int play_game(unsigned limit,unsigned scenario) {
    ArchieVideo video; RgVoice voices[3];
    if(!archie_video_open(&video)) { fprintf(stderr,"Video: %s\n",archie_video_error()); return 1; }
    if(!rg_audio_open(&audio)) { archie_video_close(); fprintf(stderr,"Audio: %s\n",rg_audio_error()); return 1; }
    sim_init(&game); rg_render_init(&renderer); publish_voices(voices);
    if(scenario==1) {
        game_init_enter(&game); game.level=MAX_LEVEL; stage_init_enter(&game);
        publish_voices(voices);
    }
    if(scenario==2 || scenario==3) { late_init(); stress(0); audio_voices(voices,0); }
    rg_render_observe(&renderer,&game);
    rg_render_bank(&renderer,&game,video.hidden,video.bank[video.hidden]+ARCHIE_TOP*ARCHIE_STRIDE,ARCHIE_STRIDE);
    archie_video_present(&video);
    rg_render_bank(&renderer,&game,video.hidden,video.bank[video.hidden]+ARCHIE_TOP*ARCHIE_STRIDE,ARCHIE_STRIDE);
    rg_audio_refill(&audio,voices);
    archie_video_present(&video);
    int ok=rg_audio_start(&audio,voices);
    int profiling=scenario==4;
    unsigned frames=0; uint32_t work_cs=0,misses=0,start=archie_time(),previous=archie_vsync_count();
    uint32_t input_cs=0,audio_cs=0,render_cs=0;
    uint32_t changed_total=0,restored_total=0,sprites_total=0,scene_misses=0;
    unsigned sprites_peak=0;
    unsigned modes[MODE_COUNT]={0},late_frames[32],late_modes[32],late_cost[32],late_n=0;
    unsigned late_audio[32],late_render[32],late_changed[32],late_restore[32];
    while(ok && (!limit || frames<limit)) {
        uint32_t before=profiling?archie_time():0;
        if(rg_input_sample(&game)) break;
        if(scenario==2 || scenario==3) {
            late_tick(frames); stress(frames);
            if(scenario==2) for(unsigned i=8;i<24;i++) game.objects[i].flags=0;
            audio_voices(voices,frames);
        } else {
            if(scenario==1) {
                game.input_fire=game.mode==MODE_PLAY || (frames%20)==0;
                game.input_dirs=(uint8_t)(1u<<((frames/125)&3));
                game.input_key_s=game.input_key_i=game.input_runstop=0;
                if(game.mode==MODE_STAGE_INIT) game.level=MAX_LEVEL;
            }
            sim_tick(&game); publish_voices(voices);
        }
        modes[game.mode]++;
        uint32_t mark=profiling?archie_time():0; input_cs+=mark-before;
        rg_audio_refill(&audio,voices);
        uint32_t after_audio=profiling?archie_time():0; audio_cs+=after_audio-mark;
        rg_render_observe(&renderer,&game);
        rg_render_bank(&renderer,&game,video.hidden,video.bank[video.hidden]+ARCHIE_TOP*ARCHIE_STRIDE,ARCHIE_STRIDE);
        if(limit) {
            changed_total+=renderer.changed; restored_total+=renderer.restored; sprites_total+=renderer.sprites;
            if(renderer.sprites>sprites_peak) sprites_peak=renderer.sprites;
        }
        uint32_t after_render=profiling?archie_time():0; render_cs+=after_render-after_audio;
        work_cs+=after_render-before;
        ok=archie_video_present(&video);
        uint32_t now=archie_vsync_count(); if(now-previous>1) {
            misses+=now-previous-1;
            if(renderer.changed==1000) scene_misses+=now-previous-1;
            if(late_n<32) {
                late_frames[late_n]=frames; late_modes[late_n]=game.mode; late_cost[late_n]=after_render-before;
                late_audio[late_n]=after_audio-mark; late_render[late_n]=after_render-after_audio;
                late_changed[late_n]=renderer.changed; late_restore[late_n]=renderer.restored; late_n++;
            }
        }
        previous=now; frames++;
    }
    uint32_t elapsed=archie_time()-start;
    ok&=rg_audio_stop(&audio);
    uint32_t underruns=audio.ring->underruns;
    ok&=rg_audio_close(&audio);
    archie_video_close(); ok&=archie_video_restore_ok();
    if(limit) {
        const char *reports[5]={"<RGDiag$Dir>.G4-title","<RGDiag$Dir>.G4-actual","<RGDiag$Dir>.G4-eight","<RGDiag$Dir>.G4-capacity","<RGDiag$Dir>.G4-profile"};
        FILE *report=fopen(reports[scenario<5?scenario:0],"w"); if(!report) report=stdout;
        fprintf(report,"Integrated game: scenario=%u frames=%u elapsed_cs=%lu work_cs=%lu vsync_misses=%lu underrun_samples=%lu cleanup_ok=%d\n",scenario,frames,(unsigned long)elapsed,(unsigned long)work_cs,(unsigned long)misses,(unsigned long)underruns,ok);
        fprintf(report,"profiling=%d input_core_cs=%lu audio_cs=%lu render_cs=%lu\n",profiling,(unsigned long)input_cs,(unsigned long)audio_cs,(unsigned long)render_cs);
        fprintf(report,"scene_misses=%lu routine_misses=%lu changed_cells=%lu restored_tiles=%lu sprites=%lu sprites_peak=%u renderer_bytes=%u app_slot_kib=896\n",(unsigned long)scene_misses,(unsigned long)(misses-scene_misses),(unsigned long)changed_total,(unsigned long)restored_total,(unsigned long)sprites_total,sprites_peak,(unsigned)sizeof renderer);
        for(unsigned i=0;i<MODE_COUNT;i++) fprintf(report,"mode_%u_frames=%u\n",i,modes[i]);
        for(unsigned i=0;i<late_n;i++) fprintf(report,"late_frame=%u mode=%u coarse_work_cs=%u audio_cs=%u render_cs=%u changed=%u restored=%u\n",late_frames[i],late_modes[i],late_cost[i],late_audio[i],late_render[i],late_changed[i],late_restore[i]);
        if(report!=stdout) fclose(report);
    }
    return ok?0:1;
}
int main(int argc,char **argv) {
    if(argc==1 || !strcmp(argv[1],"play")) return play_game(0,0);
    if(!strcmp(argv[1],"integrated")) return play_game(argc>3?(unsigned)strtoul(argv[3],NULL,10):3050,argc>2?(unsigned)strtoul(argv[2],NULL,10):0);
    if(argc>1 && !strcmp(argv[1],"audio")) return audio_diagnostic();
    ArchieVideo v;
    uint32_t start,end,first,last,missed=0,previous;
    unsigned n,presents=0,limit=3050;
    unsigned late_frames[32],late_work_cs[32],late_pre_vsync[32],late_modes[32],late_count=0;
    unsigned late_play_ticks=0,late_objects_peak=0,logic_ticks=0;
    uint32_t graphics_cs=0,combined_cs=0,changed=0,restored=0,sprites=0;
    int graphics=argc>1 && (!strcmp(argv[1],"graphics") || !strcmp(argv[1],"profile"));
    int profile=argc>1 && !strcmp(argv[1],"profile");
    uint32_t observe_cs=0,bank_cs=0,restore_cs=0,objects_cs=0;
    unsigned profile_tiles=0,profile_sprites=0;
    int ok=1;
    unsigned audit_frames=0;
    FILE *f;
    if(!archie_video_open(&v)) {
        fprintf(stderr,"Video initialization: %s\n",archie_video_error());
        return 1;
    }
    checker(v.bank[0],0); checker(v.bank[1],1);
    sim_init(&game);
    rg_render_init(&renderer);
    if(graphics) {
        uint8_t *reference=malloc(RG_FRAME_BYTES);
        if(!reference) { archie_video_close(); fputs("Audit allocation failed\n",stderr); return 1; }
        for(n=0;n<256;n++) {
            if(n<128) {
                stress(n);
                for(unsigned s=1;s<24;s++) game.objects[s].sprite_ptr=(uint8_t)(0xc0+(n/8+s)%27);
                if(n==126 || n==127) game.present=PRESENT_HIRES_TITLE;
            } else {
                if(n==128) { sim_init(&game); mode_set(&game,MODE_TITLE_TEXT); }
                sim_tick(&game);
            }
            rg_render_observe(&renderer,&game);
            rg_render_bank(&renderer,&game,v.hidden,v.bank[v.hidden]+28*160,160);
            rg_render_full(&game,reference,160);
            unsigned mismatch=0;
            uint8_t *actual=v.bank[v.hidden]+28*160;
            /* This SDK's memcmp compares its first byte repeatedly. Volatile
             * scalar reads keep this independent of that library routine. */
            const volatile uint8_t *expected_bytes=reference,*actual_bytes=actual;
            while(mismatch<RG_FRAME_BYTES && expected_bytes[mismatch]==actual_bytes[mismatch]) mismatch++;
            if(mismatch<RG_FRAME_BYTES) {
                unsigned expected=reference[mismatch],got=actual[mismatch];
                f=fopen("<RGDiag$Dir>.Native-reference","wb");
                if(f) { fwrite(reference,1,RG_FRAME_BYTES,f); fclose(f); }
                f=fopen("<RGDiag$Dir>.Native-fast","wb");
                if(f) { fwrite(actual,1,RG_FRAME_BYTES,f); fclose(f); }
                free(reference); archie_video_close();
                fprintf(stderr,"Native mismatch frame %u byte %u expected %02x got %02x\n",n,mismatch,expected,got);
                return 1;
            }
            audit_frames++;
        }
        free(reference);
        start=archie_time();
        for(n=0;n<1000;n++) {
            stress(n); rg_render_observe(&renderer,&game);
            rg_render_bank(&renderer,&game,v.hidden,v.bank[v.hidden]+28*160,160);
        }
        graphics_cs=archie_time()-start;
        late_init();
        start=archie_time();
        for(n=0;n<1000;n++) {
            late_tick(n);
            if(late_game.mode==MODE_PLAY) late_play_ticks++;
            unsigned allocated=0;
            for(unsigned s=0;s<OBJECT_CAPACITY;s++) allocated+=!!(late_game.objects[s].flags&OBJF_ALLOCATED);
            if(allocated>late_objects_peak) late_objects_peak=allocated;
            stress(n); rg_render_observe(&renderer,&game);
            rg_render_bank(&renderer,&game,v.hidden,v.bank[v.hidden]+28*160,160);
        }
        combined_cs=archie_time()-start;
        f=fopen("<RGDiag$Dir>.G2-batch","w");
        if(f) { fprintf(f,"frames=1000 graphics_cs=%lu combined_cs=%lu\n",(unsigned long)graphics_cs,(unsigned long)combined_cs); fclose(f); }
        if(profile) {
            start=archie_time();
            for(n=0;n<1000;n++) { stress(n); rg_render_observe(&renderer,&game); }
            observe_cs=archie_time()-start;
            start=archie_time();
            for(n=0;n<1000;n++) { stress(n); rg_render_bank(&renderer,&game,v.hidden,v.bank[v.hidden]+28*160,160); }
            bank_cs=archie_time()-start;
            uint8_t damage[RG_DAMAGE_BYTES];
            stress(500); rg_render_observe(&renderer,&game);
            rg_render_bank(&renderer,&game,v.hidden,v.bank[v.hidden]+28*160,160);
            memcpy(damage,renderer.footprints[v.hidden],sizeof damage);
            start=archie_time();
            for(n=0;n<1000;n++) {
                memcpy(renderer.footprints[v.hidden],damage,sizeof damage);
                rg_render_restore(&renderer,v.hidden,v.bank[v.hidden]+28*160,160);
            }
            restore_cs=archie_time()-start; profile_tiles=renderer.restored;
            start=archie_time();
            for(n=0;n<1000;n++) rg_render_objects(&renderer,&game,v.hidden,v.bank[v.hidden]+28*160,160);
            objects_cs=archie_time()-start; profile_sprites=renderer.sprites;

        }
        sim_init(&game);
        late_init();
        rg_render_init(&renderer);
    }
    archie_video_present(&v); /* align start to a VSync */
    first=previous=archie_vsync_count();
    start=archie_time();
    /* A failed average already fails G2; do not spend minutes on a paced
     * repeat of a known over-budget build. Passing averages require it. */
    if(graphics && (graphics_cs>800 || combined_cs>1200)) limit=0;
    for(n=0;n<limit;n++) {
        uint32_t work_start=archie_time();
        uint8_t *p=v.bank[v.hidden];
        unsigned x=(n%156)*2;
        /* Erase and replace marker only in the selected hidden bank. */
        if(!graphics) {
            memset(p+128*160,0,160*8);
            for(unsigned y=128;y<136;y++) memset(p+y*160+x/2,0xff,4);
        }
        if(graphics) late_tick(n); else sim_tick(&game);
        logic_ticks++;
        if(graphics) {
            stress(n); rg_render_observe(&renderer,&game);
            rg_render_bank(&renderer,&game,v.hidden,p+28*160,160);
            changed+=renderer.changed; restored+=renderer.restored; sprites+=renderer.sprites;
        }
        uint32_t work_end=archie_time(),pre_vsync=archie_vsync_count();
        if(!archie_video_present(&v)) { ok=0; break; }
        last=archie_vsync_count();
        if(last-previous>1) {
            missed+=last-previous-1;
            if(late_count<32) {
                late_frames[late_count]=n;
                late_work_cs[late_count]=work_end-work_start;
                late_pre_vsync[late_count]=pre_vsync-previous;
                late_modes[late_count]=graphics?late_game.mode:game.mode;
                late_count++;
            }
        }
        previous=last;
        presents++;
    }
    end=archie_time();
    last=archie_vsync_count();
    archie_video_close();
    ok &= archie_video_restore_ok();
    f=fopen(graphics?"<RGDiag$Dir>.G2-report":"<RGDiag$Dir>.G1-report","w");
    if(!f) f=stdout;
    fprintf(f,"Phase 1 diagnostic\nMode=9 ARM2 flags=-O2 -msoft-float\n"
              "banks=%p,%p allocation=%lu stride=160 geometry=320x256\n"
              "logic_ticks=%lu presents=%u elapsed_cs=%lu swi_ok=%d\n"
              "vsyncs=%lu missed=%lu\n"
              "Fine timing: unavailable; no percentile claim\n",
              (void *)v.bank[0],(void *)v.bank[1],(unsigned long)v.allocated,
              (unsigned long)logic_ticks,presents,(unsigned long)(end-start),ok,
              (unsigned long)(last-first),(unsigned long)missed);
    fprintf(f,"screen_allocation_before=%lu restored=%lu cleanup_ok=%d\n",(unsigned long)archie_video_previous_size(),(unsigned long)archie_video_restored_size(),archie_video_restore_ok());
    if(graphics) fprintf(f,"graphics_batch_cs=%lu combined_batch_cs=%lu batch_frames=1000\nchanged=%lu restored=%lu sprites=%lu renderer_bytes=%u\n",(unsigned long)graphics_cs,(unsigned long)combined_cs,(unsigned long)changed,(unsigned long)restored,(unsigned long)sprites,(unsigned)sizeof renderer);
    for(n=0;n<late_count;n++) fprintf(f,"late_frame=%u coarse_work_cs=%u pre_wait_vsyncs=%u core_mode=%u\n",late_frames[n],late_work_cs[n],late_pre_vsync[n],late_modes[n]);
    if(graphics) fprintf(f,"native_scalar_audit_frames=%u\nseeded_level15_play_ticks=%u allocated_peak=%u combined_frames=1000\n",audit_frames,late_play_ticks,late_objects_peak);
    if(profile) fprintf(f,"observe_batch_cs=%lu bank_batch_cs=%lu (both include scenario generation)\n",(unsigned long)observe_cs,(unsigned long)bank_cs);
    if(profile) fprintf(f,"fixed_scene_restore_cs=%lu tiles=%u objects_cs=%lu sprites=%u frames=1000\n",(unsigned long)restore_cs,profile_tiles,(unsigned long)objects_cs,profile_sprites);
    for(n=0;n<16;n++) fprintf(f,"palette%u=%08lx\n",n,(unsigned long)v.palette[n]);
    if(f!=stdout) fclose(f);
    puts(graphics?"Graphics diagnostic finished; see G2-report.":"Bank diagnostic finished; see G1-report.");
    return ok?0:1;
}

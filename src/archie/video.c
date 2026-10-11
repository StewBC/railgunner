/* Bank discovery follows Time Pilot's public-domain archie.c.
 * SWI contracts: ArchieSDK headers and RISC OS 3 PRM, VDU Drivers.
 * No fixed framebuffer address; every bank is queried after selection. */
#include "video.h"
#include <kernel.h>
#include <swis.h>
#include <stdlib.h>
#include <string.h>
static int previous_mode = -1, previous_pointer = -1, active;
static char error_text[252];
static uint32_t previous_size,restored_size,old_palette[16][2],old_border,old_pointer[3];
static unsigned old_colors;
static int previous_write=1,previous_display=1,restore_ok;
int archie_video_restore_ok(void) { return restore_ok; }
uint32_t archie_video_previous_size(void) { return previous_size; }
uint32_t archie_video_restored_size(void) { return restored_size; }
static volatile uint32_t vsyncs;
static int claimed, events_enabled;
extern void archie_vsync_handler(void);
uint32_t archie_vsync_count(void) { return vsyncs; }
static int checked(int swi, _kernel_swi_regs *r) {
    _kernel_oserror *e = _kernel_swi(swi, r, r);
    if (!e) return 1;
    memcpy(error_text, e->errmess, sizeof error_text);
    error_text[sizeof error_text - 1] = 0;
    return 0;
}
static int byte(int reason, int x, int y, int *old) {
    _kernel_swi_regs r = {{0}};
    r.r[0] = reason; r.r[1] = x; r.r[2] = y;
    if (!checked(OS_Byte, &r)) return 0;
    if (old) *old = r.r[1];
    return 1;
}
static int mode(int m) {
    _kernel_swi_regs r = {{0}};
    r.r[0] = 22;
    if (!checked(OS_WriteC, &r)) return 0;
    r.r[0] = m;
    return checked(OS_WriteC, &r);
}
static int variable(int n, uint32_t *out) {
    int list[2] = {n, -1};
    _kernel_swi_regs r = {{0}};
    r.r[0] = (int)list; r.r[1] = (int)out;
    return checked(OS_ReadVduVariables, &r);
}
static int palette_read(unsigned logical,unsigned kind,uint32_t *first,uint32_t *second) {
    _kernel_swi_regs r={{0}};
    r.r[0]=(int)logical; r.r[1]=(int)kind;
    if(!checked(OS_ReadPalette,&r)) return 0;
    *first=(uint32_t)r.r[2]; if(second) *second=(uint32_t)r.r[3];
    return 1;
}
static int palette_write(unsigned logical,unsigned kind,uint32_t rgb) {
    uint8_t block[5]={(uint8_t)logical,(uint8_t)(kind|(rgb&128)),
                     (uint8_t)(rgb>>8),(uint8_t)(rgb>>16),(uint8_t)(rgb>>24)};
    _kernel_swi_regs r={{0}};
    r.r[0]=12; r.r[1]=(int)block;
    return checked(OS_Word,&r);
}
uint32_t archie_time(void) {
    _kernel_swi_regs r = {{0}};
    if (!checked(OS_ReadMonotonicTime, &r)) return 0;
    return (uint32_t)r.r[0];
}
const char *archie_video_error(void) { return error_text; }
void archie_video_close(void) {
    if (!active) return;
    restore_ok=1;
    if (events_enabled) { restore_ok &= byte(13,4,0,NULL); events_enabled=0; }
    if (claimed) {
        _kernel_swi_regs r={{0}};
        r.r[0]=16; r.r[1]=(int)archie_vsync_handler; r.r[2]=(int)&vsyncs;
        if (!checked(OS_Release,&r)) abort(); /* Cannot return with a dangling IRQ. */
        claimed=0;
    }
    restore_ok &= byte(113,1,0,NULL); restore_ok &= byte(112,1,0,NULL);
    if(previous_mode>=0) restore_ok &= mode(previous_mode);
    if(variable(150,&restored_size)) {
        if(restored_size!=previous_size) {
            _kernel_swi_regs r={{0}};
            r.r[0]=2; r.r[1]=(int)previous_size-(int)restored_size;
            restore_ok &= checked(OS_ChangeDynamicArea,&r);
            restore_ok &= variable(150,&restored_size);
        }
        restore_ok &= restored_size==previous_size;
    } else restore_ok=0;
    restore_ok &= byte(112,previous_write,0,NULL);
    restore_ok &= byte(113,previous_display,0,NULL);
    for(unsigned i=0;i<old_colors;i++) {
        if(old_palette[i][0]==old_palette[i][1])
            restore_ok &= palette_write(i,16,old_palette[i][0]);
        else {
            restore_ok &= palette_write(i,17,old_palette[i][0]);
            restore_ok &= palette_write(i,18,old_palette[i][1]);
        }
    }
    restore_ok &= palette_write(0,24,old_border);
    for(unsigned i=0;i<3;i++) restore_ok &= palette_write(i+1,25,old_pointer[i]);
    if(previous_pointer>=0) restore_ok &= byte(106,previous_pointer,0,NULL);
    restore_ok &= byte(21,0,0,NULL); restore_ok &= byte(124,0,0,NULL);
    active = 0;
}
int archie_video_open(ArchieVideo *v) {
    static const uint32_t rgb[16] = {
        0x000000,0xffffff,0x68372b,0x70a4b2,0x6f3d86,0x588d43,
        0x352879,0xb8c76f,0x6f4f25,0x433900,0x9a6759,0x444444,
        0x6c6c6c,0x9ad284,0x6c5eb5,0x959595
    };
    _kernel_swi_regs r = {{0}};
    uint32_t x, y, stride, bpp, size, addr;
    unsigned i;
    memset(v, 0, sizeof *v);
    r.r[0] = 135;
    if (!checked(OS_Byte, &r)) return 0;
    previous_mode = r.r[2];
    restore_ok=0;
    if(!variable(150,&previous_size) || !variable(3,&x) ||
       !byte(250,0,255,&previous_write) || !byte(251,0,255,&previous_display)) return 0;
    old_colors=x>=15?16:(unsigned)x+1;
    for(i=0;i<old_colors;i++)
        if(!palette_read(i,16,&old_palette[i][0],&old_palette[i][1])) return 0;
    if(!palette_read(0,24,&old_border,NULL)) return 0;
    for(i=0;i<3;i++) if(!palette_read(i+1,25,&old_pointer[i],NULL)) return 0;
    if (!byte(106, 0, 0, &previous_pointer)) return 0;
    active = 1;
    atexit(archie_video_close);
    /* Preallocate through Mode 15, then choose temporary shadow Mode 9.
     * Does not change configured ScreenSize or persistent Shadow state. */
    if (!mode(15) || !mode(137)) goto fail;
    if (!variable(11,&x) || !variable(12,&y) || !variable(6,&stride) ||
        !variable(9,&bpp) || !variable(7,&size) || !variable(150,&v->allocated)) goto fail;
    if (x != 319 || y != 255 || stride != 160 || bpp != 2 || size != 40960 || v->allocated < 81920) {
        strcpy(error_text, "Mode 9 geometry or two-bank allocation unavailable"); goto fail;
    }
    for (i=0;i<2;i++) {
        if (!byte(112,(int)i+1,0,NULL) || !variable(148,&addr)) goto fail;
        v->bank[i] = (uint8_t *)addr;
        if (!addr || (addr & 3)) { strcpy(error_text,"Invalid bank address"); goto fail; }
    }
    if (!((uintptr_t)v->bank[0]+size <= (uintptr_t)v->bank[1] ||
          (uintptr_t)v->bank[1]+size <= (uintptr_t)v->bank[0])) {
        strcpy(error_text,"Overlapping screen banks"); goto fail;
    }
    for (i=0;i<16;i++) {
        int block[2] = {0,0};
        uint8_t *p = (uint8_t *)block;
        p[0]=(uint8_t)i; p[1]=16;
        p[2]=(uint8_t)(((rgb[i]>>16)+8)/17*17);
        p[3]=(uint8_t)((((rgb[i]>>8)&255)+8)/17*17);
        p[4]=(uint8_t)(((rgb[i]&255)+8)/17*17);
        r.r[0]=12; r.r[1]=(int)block;
        if (!checked(OS_Word,&r)) goto fail;
        r.r[0]=(int)i; r.r[1]=16;
        if (!checked(OS_ReadPalette,&r)) goto fail;
        v->palette[i]=(uint32_t)r.r[2];
    }
    /* Black border (logical colour 0), hide text cursor after mode changes. */
    {
        static const char commands[] = {19,16,0,0,0,0,23,1,0,0,0,0,0,0,0,0};
        r.r[0]=(int)commands; r.r[1]=sizeof commands;
        if (!checked(OS_WriteN,&r)) goto fail;
    }
    memset(v->bank[0],0,ARCHIE_SCREEN_BYTES);
    memset(v->bank[1],0,ARCHIE_SCREEN_BYTES);
    if (!byte(113,1,0,NULL) || !variable(149,&addr) || addr != (uint32_t)v->bank[0]) goto fail;
    if (!byte(112,2,0,NULL)) goto fail;
    /* Mode changes reset pointer selection. Hide it again afterwards. */
    if (!byte(106,0,0,NULL)) goto fail;
    vsyncs=0;
    r.r[0]=16; r.r[1]=(int)archie_vsync_handler; r.r[2]=(int)&vsyncs;
    if (!checked(OS_Claim,&r)) goto fail;
    claimed=1;
    if (!byte(14,4,0,NULL)) goto fail;
    events_enabled=1;
    v->hidden=1;
    return 1;
fail:
    archie_video_close();
    return 0;
}
int archie_video_present(ArchieVideo *v) {
    /* Addresses and bank selection were checked at startup. Avoid querying
     * the VDU variable table on every frame; keep SWI errors checked. */
    extern _kernel_oserror *rg_present_banks(unsigned,unsigned);
    _kernel_oserror *e=rg_present_banks(v->hidden+1,(v->hidden^1)+1);
    if(e) {
        memcpy(error_text,e->errmess,sizeof error_text); error_text[sizeof error_text-1]=0;
        return 0;
    }
    v->hidden ^= 1;
    return 1;
}

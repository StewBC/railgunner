/* Include the unchanged SDL compositor as an independent visual oracle.
 * Its static 320x200 pre-scale buffer is compared by palette index. */
#include "../../src/sdl/blit.c"
#include "render.h"
#include "mode.h"
#include <assert.h>
#include <stdlib.h>
static ArchieRender r;
static uint8_t banks[2][RG_FRAME_BYTES+32], full[RG_FRAME_BYTES];
static unsigned frames;
static void check(Game *g,unsigned bank) {
    rg_render_observe(&r,g);
    rg_render_bank(&r,g,bank,banks[bank]+16,160);
    rg_render_full(g,full,160);
    if(g->present==PRESENT_HIRES_TITLE) blit_title();
    else { blit_cells(g); blit_sprites(g); }
    assert(!memcmp(full,banks[bank]+16,sizeof full));
    for(unsigned p=0;p<64000;p++) {
        unsigned c=(full[p/2]>>((p&1)*4))&15;
        assert(palette[c]==logic_px[p]);
    }
    for(unsigned p=0;p<16;p++) {
        assert(banks[bank][p]==0xa5);
        assert(banks[bank][RG_FRAME_BYTES+16+p]==0xa5);
    }
    frames++;
}
int main(void) {
    Game g;
    assert(blit_load()==0);
    memset(banks,0xa5,sizeof banks);
    rg_render_init(&r); sim_init(&g);
    check(&g,0); check(&g,1);
    g.present=PRESENT_TEXT; g.mode=MODE_PLAY;
    for(unsigned y=0;y<25;y++) for(unsigned x=0;x<40;x++) {
        g.cells[y][x].glyph=(uint8_t)(y*40+x);
        g.cells[y][x].color=(uint8_t)(x+y);
    }
    /* Every pointer, both pixel parities, all colors and four player frames. */
    for(unsigned ptr=0;ptr<256;ptr++) for(unsigned parity=0;parity<2;parity++) {
        Object *o=&g.objects[0];
        memset(o,0,sizeof *o); o->flags=OBJF_RENDER;
        o->sprite_ptr=(uint8_t)ptr; o->sprite_attr=OBJA_MULTICOLOR;
        o->x_lo=(uint8_t)(101+parity); o->y_int=97;
        for(unsigned color=0;color<16;color++) {
            o->sprite_color=(uint8_t)color; g.player_frame=(uint8_t)(color&3);
            check(&g,color&1);
        }
    }
    /* Deterministic moving/overlapping/hidden/reused slots and every edge.
     * Damage continues to accumulate while one bank is not being drawn. */
    for(unsigned f=0;f<1200;f++) {
        g.present=f%101==0?PRESENT_HIRES_TITLE:PRESENT_TEXT;
        g.mode=(uint8_t)((f/23)%MODE_COUNT);
        g.player_frame=(uint8_t)(f&3);
        for(unsigned s=0;s<24;s++) {
            Object *o=&g.objects[s];
            unsigned x=(f+s*17)%365;
            o->flags=(f+s)%7?OBJF_RENDER:0; o->kind=(uint8_t)(s%7);
            o->sprite_ptr=s==0?SPR_PTR_PLAYER_0:(uint8_t)(0xc0+(f+s)%27);
            o->sprite_color=(uint8_t)((f+s)&15);
            o->sprite_attr=(uint8_t)(s&1);
            o->x_lo=(uint8_t)x; o->x_hi=(uint8_t)(x>>8);
            o->y_int=(uint8_t)((f*3+s*7)%256);
        }
        for(unsigned c=0;c<16;c++) {
            unsigned i=(f*37+c*19)%1000;
            g.cells[i/40][i%40].glyph=(uint8_t)(SC_BULLET_FIRST+(f+c)%16);
            g.cells[i/40][i%40].color=(uint8_t)((f+c)&15);
        }
        rg_render_observe(&r,&g);
        if(f%5) check(&g,(f/31)&1);
    }
    memset(g.objects,0,sizeof g.objects); g.present=PRESENT_TEXT; g.mode=MODE_PLAY;
    check(&g,0); check(&g,1); check(&g,0);
    assert(r.restored==0 && r.changed==0);
    /* The real menu recolors many empty cells every ten ticks. */
    sim_init(&g); mode_set(&g,MODE_TITLE_TEXT); rg_render_init(&r);
    for(unsigned f=0;f<1000;f++) { sim_tick(&g); check(&g,f&1); }
    memset(g.objects,0,sizeof g.objects); g.present=PRESENT_TEXT; g.mode=MODE_PLAY;
    for(unsigned y=0;y<25;y++) for(unsigned x=0;x<40;x++)
        g.cells[y][x]=(Cell){SC_SPACE,1};
    check(&g,0); check(&g,1);
    for(unsigned y=0;y<25;y++) for(unsigned x=0;x<40;x++) g.cells[y][x].color=7;
    check(&g,0); assert(r.changed==0 && r.restored==0);
    check(&g,1); assert(r.changed==0 && r.restored==0);
    {
        uint8_t odd[161*200+32];
        memset(odd,0xa5,sizeof odd);
        rg_render_init(&r); rg_render_observe(&r,&g);
        rg_render_bank(&r,&g,0,odd+1,161);
        rg_render_full(&g,full,160);
        for(unsigned y=0;y<200;y++) {
            assert(!memcmp(odd+1+y*161,full+y*160,160));
            assert(odd[1+y*161+160]==0xa5);
        }
        assert(odd[0]==0xa5);
        for(unsigned p=1+161*200;p<sizeof odd;p++) assert(odd[p]==0xa5);
    }
    printf("ok %u frames: SDL/full/incremental indices, clipping, damage, guards, static zero restore\n",frames);
    return 0;
}

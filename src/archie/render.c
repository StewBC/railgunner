#include "render.h"
#include "assets.h"
#include <string.h>
/* GCC/Clang alias type permits aligned transfers from byte-owned storage. */
typedef uint32_t RGWord __attribute__((may_alias));
#ifdef __arm__
extern void rg_paint_glyph(uint8_t *,const uint32_t *,unsigned);
extern void rg_background_text(uint8_t *,const Cell *,const uint32_t [16][256][8]);
extern void rg_background_dirty(uint8_t *,const Cell *,const uint32_t [16][256][8],const uint8_t *);
extern void rg_copy_words(uint32_t *,const uint32_t *,unsigned);
#else
static void rg_paint_glyph(uint8_t *dst,const uint32_t *glyph,unsigned stride) {
    for(unsigned y=0;y<8;y++,dst+=stride) *(RGWord *)dst=glyph[y];
}
#endif
static const uint8_t rg_rank[6]={3,2,1,0,0,3};
static void mark(uint8_t *bits,unsigned cell) { bits[cell>>3] |= (uint8_t)(1u<<(cell&7)); }
static void rg_pixel(uint8_t *dst,unsigned stride,int x,int y,uint8_t c) {
    uint8_t *p;
    if((unsigned)x>=320 || (unsigned)y>=200) return;
    p=dst+(unsigned)y*stride+(unsigned)x/2;
    if(x&1) *p=(uint8_t)((*p&15)|(c<<4));
    else *p=(uint8_t)((*p&240)|c);
}
static const uint32_t glyph_mask[256] = {
    0x00000000u,0xf0000000u,0x0f000000u,0xff000000u,0x00f00000u,0xf0f00000u,0x0ff00000u,0xfff00000u,
    0x000f0000u,0xf00f0000u,0x0f0f0000u,0xff0f0000u,0x00ff0000u,0xf0ff0000u,0x0fff0000u,0xffff0000u,
    0x0000f000u,0xf000f000u,0x0f00f000u,0xff00f000u,0x00f0f000u,0xf0f0f000u,0x0ff0f000u,0xfff0f000u,
    0x000ff000u,0xf00ff000u,0x0f0ff000u,0xff0ff000u,0x00fff000u,0xf0fff000u,0x0ffff000u,0xfffff000u,
    0x00000f00u,0xf0000f00u,0x0f000f00u,0xff000f00u,0x00f00f00u,0xf0f00f00u,0x0ff00f00u,0xfff00f00u,
    0x000f0f00u,0xf00f0f00u,0x0f0f0f00u,0xff0f0f00u,0x00ff0f00u,0xf0ff0f00u,0x0fff0f00u,0xffff0f00u,
    0x0000ff00u,0xf000ff00u,0x0f00ff00u,0xff00ff00u,0x00f0ff00u,0xf0f0ff00u,0x0ff0ff00u,0xfff0ff00u,
    0x000fff00u,0xf00fff00u,0x0f0fff00u,0xff0fff00u,0x00ffff00u,0xf0ffff00u,0x0fffff00u,0xffffff00u,
    0x000000f0u,0xf00000f0u,0x0f0000f0u,0xff0000f0u,0x00f000f0u,0xf0f000f0u,0x0ff000f0u,0xfff000f0u,
    0x000f00f0u,0xf00f00f0u,0x0f0f00f0u,0xff0f00f0u,0x00ff00f0u,0xf0ff00f0u,0x0fff00f0u,0xffff00f0u,
    0x0000f0f0u,0xf000f0f0u,0x0f00f0f0u,0xff00f0f0u,0x00f0f0f0u,0xf0f0f0f0u,0x0ff0f0f0u,0xfff0f0f0u,
    0x000ff0f0u,0xf00ff0f0u,0x0f0ff0f0u,0xff0ff0f0u,0x00fff0f0u,0xf0fff0f0u,0x0ffff0f0u,0xfffff0f0u,
    0x00000ff0u,0xf0000ff0u,0x0f000ff0u,0xff000ff0u,0x00f00ff0u,0xf0f00ff0u,0x0ff00ff0u,0xfff00ff0u,
    0x000f0ff0u,0xf00f0ff0u,0x0f0f0ff0u,0xff0f0ff0u,0x00ff0ff0u,0xf0ff0ff0u,0x0fff0ff0u,0xffff0ff0u,
    0x0000fff0u,0xf000fff0u,0x0f00fff0u,0xff00fff0u,0x00f0fff0u,0xf0f0fff0u,0x0ff0fff0u,0xfff0fff0u,
    0x000ffff0u,0xf00ffff0u,0x0f0ffff0u,0xff0ffff0u,0x00fffff0u,0xf0fffff0u,0x0ffffff0u,0xfffffff0u,
    0x0000000fu,0xf000000fu,0x0f00000fu,0xff00000fu,0x00f0000fu,0xf0f0000fu,0x0ff0000fu,0xfff0000fu,
    0x000f000fu,0xf00f000fu,0x0f0f000fu,0xff0f000fu,0x00ff000fu,0xf0ff000fu,0x0fff000fu,0xffff000fu,
    0x0000f00fu,0xf000f00fu,0x0f00f00fu,0xff00f00fu,0x00f0f00fu,0xf0f0f00fu,0x0ff0f00fu,0xfff0f00fu,
    0x000ff00fu,0xf00ff00fu,0x0f0ff00fu,0xff0ff00fu,0x00fff00fu,0xf0fff00fu,0x0ffff00fu,0xfffff00fu,
    0x00000f0fu,0xf0000f0fu,0x0f000f0fu,0xff000f0fu,0x00f00f0fu,0xf0f00f0fu,0x0ff00f0fu,0xfff00f0fu,
    0x000f0f0fu,0xf00f0f0fu,0x0f0f0f0fu,0xff0f0f0fu,0x00ff0f0fu,0xf0ff0f0fu,0x0fff0f0fu,0xffff0f0fu,
    0x0000ff0fu,0xf000ff0fu,0x0f00ff0fu,0xff00ff0fu,0x00f0ff0fu,0xf0f0ff0fu,0x0ff0ff0fu,0xfff0ff0fu,
    0x000fff0fu,0xf00fff0fu,0x0f0fff0fu,0xff0fff0fu,0x00ffff0fu,0xf0ffff0fu,0x0fffff0fu,0xffffff0fu,
    0x000000ffu,0xf00000ffu,0x0f0000ffu,0xff0000ffu,0x00f000ffu,0xf0f000ffu,0x0ff000ffu,0xfff000ffu,
    0x000f00ffu,0xf00f00ffu,0x0f0f00ffu,0xff0f00ffu,0x00ff00ffu,0xf0ff00ffu,0x0fff00ffu,0xffff00ffu,
    0x0000f0ffu,0xf000f0ffu,0x0f00f0ffu,0xff00f0ffu,0x00f0f0ffu,0xf0f0f0ffu,0x0ff0f0ffu,0xfff0f0ffu,
    0x000ff0ffu,0xf00ff0ffu,0x0f0ff0ffu,0xff0ff0ffu,0x00fff0ffu,0xf0fff0ffu,0x0ffff0ffu,0xfffff0ffu,
    0x00000fffu,0xf0000fffu,0x0f000fffu,0xff000fffu,0x00f00fffu,0xf0f00fffu,0x0ff00fffu,0xfff00fffu,
    0x000f0fffu,0xf00f0fffu,0x0f0f0fffu,0xff0f0fffu,0x00ff0fffu,0xf0ff0fffu,0x0fff0fffu,0xffff0fffu,
    0x0000ffffu,0xf000ffffu,0x0f00ffffu,0xff00ffffu,0x00f0ffffu,0xf0f0ffffu,0x0ff0ffffu,0xfff0ffffu,
    0x000fffffu,0xf00fffffu,0x0f0fffffu,0xff0fffffu,0x00ffffffu,0xf0ffffffu,0x0fffffffu,0xffffffffu,
};
static void tile(const Game *g,unsigned cx,unsigned cy,uint8_t *dst,unsigned stride,int title,int fast) {
    unsigned cell=cy*40+cx,y,x;
    Cell c=g->cells[cy][cx];
    const uint8_t *bits=title ? rg_title+cell*8 : rg_charset+(unsigned)c.glyph*8;
    uint8_t fg=title ? rg_title_colors[cell]>>4 : c.color&15;
    uint8_t bg=title ? rg_title_colors[cell]&15 : 0;
    if(fast && !(((uintptr_t)dst|stride)&3)) {
        if(!title) {
            rg_paint_glyph(dst+cy*8*stride+cx*4,rg_text_tiles[fg][c.glyph],stride);
            return;
        }
        uint32_t ink=fg*0x11111111u, paper=bg*0x11111111u;
        RGWord *d=(RGWord *)(dst+cy*8*stride+cx*4);
        for(y=0;y<8;y++,d+=stride/4) {
            uint32_t mask=glyph_mask[bits[y]];
            *d=(mask&ink)|(~mask&paper);
        }
        return;
    }
    for(y=0;y<8;y++) for(x=0;x<4;x++) {
        uint8_t b=bits[y];
        dst[(cy*8+y)*stride+cx*4+x]=(uint8_t)(
            ((b&(128u>>(x*2)))?fg:bg) | (((b&(64u>>(x*2)))?fg:bg)<<4));
    }
}
#ifdef __arm__
extern void rg_copy_tiles(uint8_t *,const uint8_t *,unsigned,unsigned);
extern void rg_cells_blocks(const uint32_t *,const uint32_t *,uint8_t *,unsigned);
#else
static void rg_cells_blocks(const uint32_t *src,const uint32_t *old,uint8_t *blocks,unsigned count) {
    for(unsigned b=0;b<count;b++,src+=4,old+=4)
        blocks[b]=(uint8_t)!!((src[0]^old[0])|(src[1]^old[1])|(src[2]^old[2])|(src[3]^old[3]));
}
static void rg_copy_tiles(uint8_t *d,const uint8_t *b,unsigned count,unsigned stride) {
    for(unsigned y=0;y<8;y++,d+=stride,b+=160) memcpy(d,b,count*4);
}
#endif
#ifdef __arm__
extern void rg_blit_words(RGWord *,const uint32_t *,const uint32_t (*)[2],unsigned,unsigned,unsigned);
#else
static void rg_blit_words(RGWord *d,const uint32_t *t,const uint32_t (*pairs)[2],unsigned rows,unsigned stride,unsigned width) {
    for(unsigned row=0;row<rows;row++,d+=stride/4,t+=4)
        for(unsigned x=0;x<width;x++) if(t[x])
            d[x]=(d[x]&~pairs[t[x]][0])|pairs[t[x]][1];
}
#endif
static const uint8_t *rg_sprite_bytes(const Game *g,const Object *o) {
    if(o->sprite_ptr==SPR_PTR_PLAYER_0 || o->sprite_ptr==SPR_PTR_PLAYER_1)
        return rg_players[g->player_frame&3];
    return rg_sprites[o->sprite_ptr];
}
static void footprint(uint8_t *bits,int x,int y) {
    int left=x<0?0:x,top=y<0?0:y;
    int right=x+24>320?320:x+24,bottom=y+21>200?200:y+21;
    int cx,cy;
    if(left>=right || top>=bottom) return;
    for(cy=top/8;cy<=(bottom-1)/8;cy++)
        for(cx=left/8;cx<=(right-1)/8;cx++) mark(bits,(unsigned)(cy*40+cx));
}
static void rg_draw_objects(const Game *g,uint8_t *dst,unsigned stride,uint8_t *damage,uint32_t *count,int fast) {
    int rank;
    if(g->present==PRESENT_HIRES_TITLE) return;
    for(rank=3;rank>=0;rank--) for(unsigned slot=0;slot<OBJECT_CAPACITY;slot++) {
        const Object *o=&g->objects[slot];
        const uint8_t *data;
        int sx,sy;
        if(!(o->flags&OBJF_RENDER) || (o->kind<6?rg_rank[o->kind]:3)!=rank) continue;
        data=rg_sprite_bytes(g,o);
        if(!data) continue;
        sx=(int)(o->x_lo|((unsigned)o->x_hi<<8))-24;
        sy=(int)o->y_int-50;
        if(sx>=320 || sx+24<=0 || sy>=200 || sy+21<=0) continue;
        if(count) (*count)++;
        if(damage) footprint(damage,sx,sy);
        /* Align outward to an 8-pixel word. Masks preserve neighboring pixels;
         * four words must fit entirely within the physical row. */
        if(fast && (o->sprite_attr&OBJA_MULTICOLOR) && !(((uintptr_t)dst | stride)&3)) {
            const uint32_t (*tokens)[84] =
                (o->sprite_ptr==SPR_PTR_PLAYER_0 || o->sprite_ptr==SPR_PTR_PLAYER_1)
                ? rg_player_word_tokens[g->player_frame&3] : rg_sprite_word_tokens[o->sprite_ptr];
            if(tokens) {
                int base=sx>=0?sx/8:-((-sx+7)/8);
                unsigned first=base<0?(unsigned)-base:0;
                unsigned last=base+4>40?(unsigned)(40-base):4;
                unsigned top=sy<0?(unsigned)-sy:0;
                unsigned bottom=sy+21>200?(unsigned)(200-sy):21;
                const uint32_t *t=tokens[(unsigned)sx&7]+top*4;
                const uint32_t (*pairs)[2]=rg_word_pairs[o->sprite_color&15];
                RGWord *rowd=(RGWord *)(dst+(unsigned)(sy+(int)top)*stride)+(base+(int)first);
#ifdef __arm__
                if(stride==160 && first==0 && last==4 && top==0 && bottom==21) {
                    RGCompiledSprite compiled=(o->sprite_ptr==SPR_PTR_PLAYER_0 || o->sprite_ptr==SPR_PTR_PLAYER_1)
                        ? rg_compiled_players[g->player_frame&3][(unsigned)sx&7]
                        : rg_compiled_sprites[o->sprite_ptr][(unsigned)sx&7];
                    if(compiled) { compiled(rowd,pairs); continue; }
                }
#endif
                rg_blit_words(rowd,t+first,pairs,bottom-top,stride,last-first);
                continue;
            }
        }
        if(fast && (o->sprite_attr&OBJA_MULTICOLOR) && sx>=0 && sx+24<=320 && sy>=0 && sy+21<=200) {
            const uint32_t (*tokens)[273] =
                (o->sprite_ptr==SPR_PTR_PLAYER_0 || o->sprite_ptr==SPR_PTR_PLAYER_1)
                ? rg_player_tokens[g->player_frame&3] : rg_sprite_tokens[o->sprite_ptr];
            if(tokens) {
                const uint32_t *t=tokens[sx&1];
                unsigned width=(sx&1)?13:12;
                uint8_t ink=(uint8_t)((o->sprite_color&15)*17);
                for(unsigned row=0;row<21;row++) {
                    uint8_t *d=dst+(unsigned)(sy+(int)row)*stride+(unsigned)sx/2;
                    for(unsigned x=0;x<width;x++) {
                        uint32_t v=t[x];
                        if(!v) continue;
                        d[x]=(uint8_t)((d[x]&~(v>>16))|(v&255)|((v>>8)&ink));
                    }
                    t+=13;
                }
                continue;
            }
        }
        for(unsigned row=0;row<21;row++) for(unsigned bi=0;bi<3;bi++) {
            if((unsigned)(sy+(int)row)>=200) continue;
            uint8_t b=data[row*3+bi];
            if(o->sprite_attr&OBJA_MULTICOLOR) {
                for(unsigned pair=0;pair<4;pair++) {
                    uint8_t part=(b>>(6-pair*2))&3;
                    uint8_t c=part==1?SPR_MC0_COLOR:part==2?o->sprite_color&15:SPR_MC1_COLOR;
                    int x=sx+(int)(bi*8+pair*2);
                    if(!part) continue;
                    if((unsigned)x<319) {
                        uint8_t *p=dst+(unsigned)(sy+(int)row)*stride+(unsigned)x/2;
                        if(!(x&1)) *p=(uint8_t)(c|(c<<4));
                        else { p[0]=(uint8_t)((p[0]&15)|(c<<4)); p[1]=(uint8_t)((p[1]&240)|c); }
                    } else {
                        rg_pixel(dst,stride,x,sy+(int)row,c);
                        rg_pixel(dst,stride,x+1,sy+(int)row,c);
                    }
                }
            } else for(unsigned bit=0;bit<8;bit++)
                if(b&(128u>>bit)) rg_pixel(dst,stride,sx+(int)(bi*8+bit),sy+(int)row,o->sprite_color&15);
        }
    }
}
void rg_render_full(const Game *g,uint8_t *dst,unsigned stride) {
    for(unsigned cy=0;cy<25;cy++) for(unsigned cx=0;cx<40;cx++)
        tile(g,cx,cy,dst,stride,g->present==PRESENT_HIRES_TITLE,0);
    rg_draw_objects(g,dst,stride,NULL,NULL,0);
}
void rg_render_init(ArchieRender *r) {
    memset(r,0,sizeof *r);
    for(unsigned c=0;c<256;c++) {
        unsigned ink=0; for(unsigned y=0;y<8;y++) ink|=rg_charset[c*8+y];
        r->blank[c]=(uint8_t)!ink;
    }
}
#ifdef __arm__
static void rg_rebuild_background(ArchieRender *r,const Game *g,const RGWord *words) {
    rg_copy_words(r->observed,words,501);
    if(g->present==PRESENT_HIRES_TITLE)
        rg_copy_words((uint32_t *)r->background,rg_title_packed,8000);
    else rg_background_text(r->background,(const Cell *)g->cells,rg_text_tiles);
    memset(r->pending,255,sizeof r->pending);
    r->full[0]=r->full[1]=1;
    r->changed=1000;
    r->presentation=g->present; r->mode=g->mode; r->valid=1;
}
#endif
void rg_render_observe(ArchieRender *r,const Game *g) {
    int invalidate=!r->valid || r->presentation!=g->present || r->mode!=g->mode;
    if(invalidate) r->full[0]=r->full[1]=1;
    r->changed=0;
    const uint8_t *src=(const uint8_t *)g->cells;
    unsigned prefix=(uintptr_t)src&3;
    const RGWord *words=(const RGWord *)((uintptr_t)src&~(uintptr_t)3);
#ifdef __arm__
    if(invalidate) { rg_rebuild_background(r,g,words); return; }
    unsigned changing_cells=0;
#endif
    uint8_t changed[RG_DAMAGE_BYTES]={0},blocks[125];
    rg_cells_blocks(words,r->observed,blocks,125);
    for(unsigned block=0;block<126;block++) {
        unsigned base=block*4,count=base==500?1:4;
        if(count==4 && !blocks[block]) continue;
        for(unsigned j=0;j<count;j++) {
            unsigned i=base+j;
            uint32_t now=words[i],diff=now^r->observed[i];
            if(i==0) diff &= 0xffffffffu<<(prefix*8);
            if(!diff) continue;
            r->observed[i]=now;
            if(invalidate || g->present==PRESENT_HIRES_TITLE) continue;
            for(unsigned b=0;b<4;b++) if(diff&(255u<<(b*8))) {
                int index=(int)(i*4+b)-(int)prefix;
                if((unsigned)index<2000) {
                    unsigned cell=(unsigned)index/2;
                    /* A color-only change on an empty glyph has no pixels. */
                    if((index&1) && !(diff&(255u<<((b^1)*8))) &&
                       r->blank[((const Cell *)g->cells)[cell].glyph]) continue;
#ifdef __arm__
                    unsigned mask=1u<<(cell&7);
                    if(!(changed[cell>>3]&mask) && ++changing_cells>=768) {
                        rg_rebuild_background(r,g,words); return;
                    }
#endif
                    mark(changed,cell);
                }
            }
        }
    }
#ifdef __arm__
    if(g->present!=PRESENT_HIRES_TITLE)
        rg_background_dirty(r->background,(const Cell *)g->cells,rg_text_tiles,changed);
#endif
    for(unsigned y=0;y<25;y++) for(unsigned group=0;group<5;group++) {
        unsigned bits=invalidate?255:changed[y*5+group];
        if(!bits) continue;
        for(unsigned bit=0;bit<8;bit++,bits>>=1) if(bits&1) {
            unsigned x=group*8+bit,c=y*40+x;
#ifndef __arm__
            tile(g,x,y,r->background,160,g->present==PRESENT_HIRES_TITLE,1);
#endif
            mark(r->pending[0],c); mark(r->pending[1],c); r->changed++;
        }
    }
    r->presentation=g->present; r->mode=g->mode; r->valid=1;
}
void rg_render_restore(ArchieRender *r,unsigned bank,uint8_t *dst,unsigned stride) {
    r->restored=0;
    if(bank>1) return;
    if(r->full[bank] && stride==160 && !((uintptr_t)dst&3)) {
#ifdef __arm__
        rg_copy_words((uint32_t *)dst,(const uint32_t *)r->background,8000);
#else
        memcpy(dst,r->background,RG_FRAME_BYTES);
#endif
        r->restored=1000;
        goto restored;
    }
    for(unsigned cy=0;cy<25;cy++) for(unsigned group=0;group<5;group++) {
        unsigned index=cy*5+group;
        unsigned dirty=r->pending[bank][index]|r->footprints[bank][index];
        if(!dirty) continue;
        for(unsigned bit=0;bit<8;) {
            if(!(dirty&(1u<<bit))) { bit++; continue; }
            unsigned first=bit;
            do { bit++; } while(bit<8 && (dirty&(1u<<bit)));
            unsigned cx=group*8+first,count=bit-first;
            uint8_t *d=dst+cy*8*stride+cx*4;
            const uint8_t *b=r->background+cy*1280+cx*4;
            if(!(((uintptr_t)d | (uintptr_t)b | stride)&3))
                rg_copy_tiles(d,b,count,stride);
            else for(unsigned y=0;y<8;y++,d+=stride,b+=160)
                memcpy(d,b,count*4);
            r->restored+=count;
        }
    }
restored:
    r->full[bank]=0;
    memset(r->pending[bank],0,RG_DAMAGE_BYTES);
    memset(r->footprints[bank],0,RG_DAMAGE_BYTES);
}
void rg_render_objects(ArchieRender *r,const Game *g,unsigned bank,uint8_t *dst,unsigned stride) {
    r->sprites=0;
    if(bank>1) return;
    rg_draw_objects(g,dst,stride,r->footprints[bank],&r->sprites,1);
}
void rg_render_bank(ArchieRender *r,const Game *g,unsigned bank,uint8_t *dst,unsigned stride) {
    rg_render_restore(r,bank,dst,stride);
    rg_render_objects(r,g,bank,dst,stride);
}

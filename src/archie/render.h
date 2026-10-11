#ifndef RG_ARCHIE_RENDER_H
#define RG_ARCHIE_RENDER_H
#include "sim.h"
#define RG_FRAME_BYTES 32000
#define RG_DAMAGE_BYTES 125
typedef struct {
    uint8_t background[RG_FRAME_BYTES];
    uint32_t observed[501]; /* aligned core bytes, including edge padding */
    uint8_t pending[2][RG_DAMAGE_BYTES];
    uint8_t footprints[2][RG_DAMAGE_BYTES];
    uint8_t valid, presentation, mode;
    uint8_t blank[256],full[2];
    uint32_t changed, restored, sprites;
} ArchieRender;
void rg_render_init(ArchieRender *r);
void rg_render_observe(ArchieRender *r, const Game *g);
void rg_render_bank(ArchieRender *r,const Game *g,unsigned bank,uint8_t *dst,unsigned stride);
void rg_render_restore(ArchieRender *,unsigned,uint8_t *,unsigned);
void rg_render_objects(ArchieRender *,const Game *,unsigned,uint8_t *,unsigned);
void rg_render_full(const Game *g,uint8_t *dst,unsigned stride);
#endif

#include "blit.h"

#include "data/tables.h"

#include <stdio.h>
#include <string.h>

#define LOGIC_W 320
#define LOGIC_H 200
#define SCALE 2
#define WINDOW_W (LOGIC_W * SCALE)
#define WINDOW_H (LOGIC_H * SCALE)

/* Pepto sRGB approximations. One table for the bitmap, the cells, and sprites. */
static const uint32_t palette[16] = {
    0xFF000000, /* 0 black */
    0xFFFFFFFF, /* 1 white */
    0xFF68372B, /* 2 red */
    0xFF70A4B2, /* 3 cyan */
    0xFF6F3D86, /* 4 purple */
    0xFF588D43, /* 5 green */
    0xFF352879, /* 6 blue */
    0xFFB8C76F, /* 7 yellow */
    0xFF6F4F25, /* 8 orange */
    0xFF433900, /* 9 brown */
    0xFF9A6759, /* 10 light red */
    0xFF444444, /* 11 dark gray */
    0xFF6C6C6C, /* 12 mid gray */
    0xFF9AD284, /* 13 light green */
    0xFF6C5EB5, /* 14 light blue */
    0xFF959595, /* 15 light gray */
};

static uint8_t charset[2048];
static uint8_t title_bmp[8000];
static uint8_t title_col[1000];
static uint8_t sprite_store[SPR_FRAMES_SRC_COUNT][SPR_FRAME_BYTES];
static const uint8_t *sprite_ptr_data[256];
static uint8_t player_frames[4][SPR_FRAME_BYTES];
static uint32_t logic_px[LOGIC_W * LOGIC_H];

/* mux_build.asm kind_priority: lower rank is drawn in front. Player is back. */
static const uint8_t kind_rank[6] = {3, 2, 1, 0, 0, 3};

static int read_file(const char *path, uint8_t *dst, size_t n) {
    FILE *f = fopen(path, "rb");
    size_t got;
    if (f == NULL) {
        perror(path);
        return -1;
    }
    got = fread(dst, 1, n, f);
    fclose(f);
    if (got != n) {
        fprintf(stderr, "%s: expected %zu bytes, got %zu\n", path, n, got);
        return -1;
    }
    return 0;
}

static void asset_path(char *out, size_t n, const char *rel) {
    snprintf(out, n, "%s/%s", RAILGUNNER_ROOT, rel);
}

int blit_load(void) {
    char path[512];
    uint8_t i;

    asset_path(path, sizeof path, "assets/c64/charset/railgunner_charset.bin");
    if (read_file(path, charset, sizeof charset) != 0) {
        return -1;
    }
    asset_path(path, sizeof path, "assets/c64/screens/title_hires.bin");
    if (read_file(path, title_bmp, sizeof title_bmp) != 0) {
        return -1;
    }
    asset_path(path, sizeof path, "assets/c64/screens/title_hires_col.bin");
    if (read_file(path, title_col, sizeof title_col) != 0) {
        return -1;
    }
    memset(sprite_ptr_data, 0, sizeof sprite_ptr_data);
    for (i = 0; i < SPR_FRAMES_SRC_COUNT; i++) {
        const char *name = spr_frame_bins[i].bin_name;
        uint8_t id = spr_frame_bins[i].ptr_id;
        if (name == NULL) {
            sprite_ptr_data[id] = spr_cargo_disc;
            continue;
        }
        snprintf(path, sizeof path, "%s/assets/c64/sprites/%s", RAILGUNNER_ROOT, name);
        if (read_file(path, sprite_store[i], SPR_FRAME_BYTES) != 0) {
            return -1;
        }
        sprite_ptr_data[id] = sprite_store[i];
    }
    for (i = 0; i < 4; i++) {
        snprintf(path, sizeof path, "%s/assets/c64/sprites/%s", RAILGUNNER_ROOT,
                 spr_player_bins[i]);
        if (read_file(path, player_frames[i], SPR_FRAME_BYTES) != 0) {
            return -1;
        }
    }
    return 0;
}

static void put_px(int x, int y, uint32_t color) {
    if ((unsigned)x >= LOGIC_W || (unsigned)y >= LOGIC_H) {
        return;
    }
    logic_px[y * LOGIC_W + x] = color;
}

static void blit_title(void) {
    int cy;
    int cx;
    for (cy = 0; cy < SCREEN_H; cy++) {
        for (cx = 0; cx < SCREEN_W; cx++) {
            int cell = cy * SCREEN_W + cx;
            uint8_t col = title_col[cell];
            uint32_t fg = palette[col >> 4];
            uint32_t bg = palette[col & 0x0F];
            const uint8_t *bits = title_bmp + cell * 8;
            int row;
            for (row = 0; row < 8; row++) {
                uint8_t byte = bits[row];
                int colb;
                for (colb = 0; colb < 8; colb++) {
                    uint32_t color = (byte & (uint8_t)(0x80 >> colb)) ? fg : bg;
                    put_px(cx * 8 + colb, cy * 8 + row, color);
                }
            }
        }
    }
}

static void blit_cells(const Game *g) {
    int row;
    int col;
    for (row = 0; row < SCREEN_H; row++) {
        for (col = 0; col < SCREEN_W; col++) {
            uint8_t glyph = g->cells[row][col].glyph;
            uint32_t ink = palette[g->cells[row][col].color & 0x0F];
            const uint8_t *bits = charset + (size_t)glyph * 8u;
            int y;
            for (y = 0; y < 8; y++) {
                uint8_t byte = bits[y];
                int x;
                for (x = 0; x < 8; x++) {
                    uint32_t color = (byte & (uint8_t)(0x80 >> x)) ? ink : palette[0];
                    put_px(col * 8 + x, row * 8 + y, color);
                }
            }
        }
    }
}

static const uint8_t *sprite_bytes(const Game *g, const Object *o) {
    if (o->sprite_ptr == SPR_PTR_PLAYER_0 || o->sprite_ptr == SPR_PTR_PLAYER_1) {
        return player_frames[g->player_frame & 3];
    }
    return sprite_ptr_data[o->sprite_ptr];
}

static void blit_sprite(const Game *g, const Object *o) {
    const uint8_t *data = sprite_bytes(g, o);
    int sx;
    int sy;
    int multicolor;
    int row;
    if (data == NULL) {
        return;
    }
    sx = (int)(o->x_lo | ((unsigned)o->x_hi << 8)) - 24;
    sy = (int)o->y_int - 50;
    multicolor = (o->sprite_attr & OBJA_MULTICOLOR) != 0;
    for (row = 0; row < 21; row++) {
        int byte_i;
        for (byte_i = 0; byte_i < 3; byte_i++) {
            uint8_t bits = data[row * 3 + byte_i];
            if (multicolor) {
                int pair;
                for (pair = 0; pair < 4; pair++) {
                    uint8_t part = (uint8_t)((bits >> (6 - pair * 2)) & 3);
                    uint32_t color;
                    int px;
                    if (part == 0) {
                        continue;
                    }
                    if (part == 1) {
                        color = palette[SPR_MC0_COLOR & 0x0F];
                    } else if (part == 2) {
                        color = palette[o->sprite_color & 0x0F];
                    } else {
                        color = palette[SPR_MC1_COLOR & 0x0F];
                    }
                    px = byte_i * 8 + pair * 2;
                    put_px(sx + px, sy + row, color);
                    put_px(sx + px + 1, sy + row, color);
                }
            } else {
                int bit;
                for (bit = 0; bit < 8; bit++) {
                    if (bits & (uint8_t)(0x80 >> bit)) {
                        put_px(sx + byte_i * 8 + bit, sy + row,
                               palette[o->sprite_color & 0x0F]);
                    }
                }
            }
        }
    }
}

static void blit_sprites(const Game *g) {
    int rank;
    /* Higher rank first, so the lower mux rank (C, parcels) ends on top. */
    for (rank = 3; rank >= 0; rank--) {
        uint8_t slot;
        for (slot = 0; slot < OBJECT_CAPACITY; slot++) {
            const Object *o = &g->objects[slot];
            uint8_t kind_r;
            if ((o->flags & OBJF_RENDER) == 0) {
                continue;
            }
            kind_r = (o->kind < 6) ? kind_rank[o->kind] : 3;
            if (kind_r == rank) {
                blit_sprite(g, o);
            }
        }
    }
}

void blit_frame(SDL_Texture *tex, const Game *g) {
    void *pixels;
    int pitch;
    int y;
    if (g->present == PRESENT_HIRES_TITLE) {
        blit_title();
    } else {
        blit_cells(g);
        blit_sprites(g);
    }
    if (SDL_LockTexture(tex, NULL, &pixels, &pitch) != 0) {
        return;
    }
    for (y = 0; y < LOGIC_H; y++) {
        int x;
        for (x = 0; x < LOGIC_W; x++) {
            uint32_t color = logic_px[y * LOGIC_W + x];
            int dy;
            int dx;
            for (dy = 0; dy < SCALE; dy++) {
                uint32_t *row = (uint32_t *)((uint8_t *)pixels +
                                             (size_t)(y * SCALE + dy) * (size_t)pitch);
                for (dx = 0; dx < SCALE; dx++) {
                    row[x * SCALE + dx] = color;
                }
            }
        }
    }
    SDL_UnlockTexture(tex);
}

#ifndef RAILGUNNER_CELLS_H
#define RAILGUNNER_CELLS_H

#include "const.h"

#include <stdint.h>

/* One playfield cell. glyph is a C64 screen code. color is a VIC nybble. */
typedef struct Cell {
    uint8_t glyph;
    uint8_t color;
} Cell;

typedef struct Game Game;

void cells_clear(Game *g);

/* screen.asm helpers, aimed at the cell buffer. Column is X, row is Y. */
void screen_clear(Game *g);
void screen_put_xy(Game *g, uint8_t col, uint8_t row, uint8_t glyph);
uint8_t screen_get_xy(const Game *g, uint8_t col, uint8_t row);
void screen_color_xy(Game *g, uint8_t col, uint8_t row, uint8_t color);
void screen_color_row(Game *g, uint8_t row, uint8_t color);
void screen_print(Game *g, uint8_t col, uint8_t row, const char *text);
void screen_draw_playfield(Game *g);
/* Score and pilots white, progress bar cyan. */
void hud_color_static(Game *g);
uint8_t ascii_to_screen(uint8_t ch);

#endif

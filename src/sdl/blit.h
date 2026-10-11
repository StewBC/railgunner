#ifndef RAILGUNNER_BLIT_H
#define RAILGUNNER_BLIT_H

#include "sim.h"

#include <SDL.h>

/* Load charset, title bitmap, and sprite bins. 0 on success. */
int blit_load(void);

/* Paint one host frame into a 640×400 texture (2× nearest of 320×200). */
void blit_frame(SDL_Texture *tex, const Game *g);

#endif

#include "life.h"

#include "mode.h"

/* Reserved mode. Mines spend the reserve; this enter is game over. */
void next_life_enter(Game *g) {
    mode_set(g, MODE_GAME_OVER);
}

void next_life_update(Game *g) {
    (void)g;
}

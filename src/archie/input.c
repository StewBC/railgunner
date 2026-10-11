#include "input.h"
#include <archie/keyboard.h>
extern int rg_key_held(unsigned key);
#define k_checkKeypress rg_key_held
int rg_input_sample(Game *g) {
    unsigned s=k_checkKeypress(KEY_S);
    g->input_dirs=(k_checkKeypress(KEY_W)||k_checkKeypress(KEY_UP)?JOY_UP:0)
        |(s||k_checkKeypress(KEY_DOWN)?JOY_DOWN:0)
        |(k_checkKeypress(KEY_A)||k_checkKeypress(KEY_LEFT)?JOY_LEFT:0)
        |(k_checkKeypress(KEY_D)||k_checkKeypress(KEY_RIGHT)?JOY_RIGHT:0);
    g->input_fire=k_checkKeypress(KEY_SPACE);
    g->input_key_s=s;
    g->input_key_i=k_checkKeypress(KEY_I);
    g->input_runstop=k_checkKeypress(KEY_ESCAPE);
    return k_checkKeypress(KEY_CTRL)&&k_checkKeypress(KEY_Q);
}

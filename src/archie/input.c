#include "input.h"
#include <archie/keyboard.h>
extern int rg_key_held(unsigned key);
extern int rg_joystick_read(unsigned port);
#define k_checkKeypress rg_key_held
int rg_input_sample(Game *g) {
    static unsigned joystick_ports=3;
    unsigned s=k_checkKeypress(KEY_S);
    g->input_dirs=(k_checkKeypress(KEY_W)||k_checkKeypress(KEY_UP)?JOY_UP:0)
        |(s||k_checkKeypress(KEY_DOWN)?JOY_DOWN:0)
        |(k_checkKeypress(KEY_A)||k_checkKeypress(KEY_LEFT)?JOY_LEFT:0)
        |(k_checkKeypress(KEY_D)||k_checkKeypress(KEY_RIGHT)?JOY_RIGHT:0);
    g->input_fire=k_checkKeypress(KEY_SPACE);
    for(unsigned port=0;port<2;++port) {
        unsigned mask=1u<<port;
        if(!(joystick_ports&mask)) continue;
        int state=rg_joystick_read(port);
        if(state==-1) { joystick_ports&=~mask; continue; }
        int y=(int)((unsigned)state&255u);
        int x=(int)(((unsigned)state>>8)&255u);
        if(y>=128) y-=256;
        if(x>=128) x-=256;
        g->input_dirs|=(y>32?JOY_UP:0)|(y< -32?JOY_DOWN:0)
            |(x< -32?JOY_LEFT:0)|(x>32?JOY_RIGHT:0);
        g->input_fire|=((unsigned)state>>16)&1u;
    }
    g->input_key_s=s;
    g->input_key_i=k_checkKeypress(KEY_I);
    g->input_runstop=k_checkKeypress(KEY_ESCAPE);
    return k_checkKeypress(KEY_CTRL)&&k_checkKeypress(KEY_Q);
}

/* Exercise native input with independent keyboard/joystick device fixtures. */
#include <assert.h>
#include <string.h>
#include <archie/keyboard.h>
#include "../../src/archie/input.h"
static unsigned keys[256], calls[2];
static int sticks[2];
int rg_key_held(unsigned key) { return keys[key]; }
int rg_joystick_read(unsigned port) { ++calls[port]; return sticks[port]; }
static int state(int x,int y,int fire) {
    return (y&255)|((x&255)<<8)|(fire<<16);
}
int main(void) {
    Game g; memset(&g,0,sizeof g);
    assert(!rg_input_sample(&g) && !g.input_dirs && !g.input_fire);
    sticks[0]=state(-64,64,1); sticks[1]=state(64,-64,0);
    assert(!rg_input_sample(&g));
    assert(g.input_dirs==(JOY_UP|JOY_DOWN|JOY_LEFT|JOY_RIGHT) && g.input_fire);
    sticks[0]=state(-32,32,0); sticks[1]=state(32,-32,0);
    rg_input_sample(&g); assert(!g.input_dirs && !g.input_fire);
    sticks[0]=state(-33,33,0); sticks[1]=0;
    keys[KEY_D]=1; keys[KEY_SPACE]=1; keys[KEY_S]=1; keys[KEY_I]=1;
    keys[KEY_ESCAPE]=1; keys[KEY_CTRL]=1; keys[KEY_Q]=1;
    assert(rg_input_sample(&g));
    assert(g.input_dirs==(JOY_UP|JOY_DOWN|JOY_LEFT|JOY_RIGHT));
    assert(g.input_fire && g.input_key_s && g.input_key_i && g.input_runstop);
    memset(keys,0,sizeof keys); sticks[0]=-1; sticks[1]=state(64,0,1);
    rg_input_sample(&g); assert(g.input_dirs==JOY_RIGHT && g.input_fire);
    unsigned old=calls[0];
    rg_input_sample(&g); assert(calls[0]==old && g.input_dirs==JOY_RIGHT);
    sticks[1]=-1; rg_input_sample(&g); old=calls[1];
    rg_input_sample(&g); assert(calls[1]==old && !g.input_dirs && !g.input_fire);
    keys[KEY_UP]=1; keys[KEY_SPACE]=1;
    rg_input_sample(&g); assert(g.input_dirs==JOY_UP && g.input_fire);
    return 0;
}

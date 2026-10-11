/* Host oracle compares the compositor's pre-scale pixels; texture upload is
 * unused. Avoid starting Cocoa/SDL or requiring a window in the test runner. */
#ifndef RG_TEST_SDL_H
#define RG_TEST_SDL_H
typedef struct SDL_Texture SDL_Texture;
static inline int SDL_LockTexture(SDL_Texture *t, const void *r,void **p,int *pitch) {
    (void)t;(void)r;(void)p;(void)pitch; return -1;
}
static inline void SDL_UnlockTexture(SDL_Texture *t) { (void)t; }
#endif

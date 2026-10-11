#include "audio.h"
#include "blit.h"
#include "sim.h"

#include <SDL.h>
#include <stdio.h>

/* The 50 Hz tick already advanced the sequencers. Publish registers only. */
static void audio_after_tick(const Game *g) {
    audio_publish(g);
}

static void sample_input(Game *g) {
    const uint8_t *k = SDL_GetKeyboardState(NULL);
    uint8_t dirs = 0;
    if (k[SDL_SCANCODE_W] || k[SDL_SCANCODE_UP]) {
        dirs = (uint8_t)(dirs | JOY_UP);
    }
    if (k[SDL_SCANCODE_S] || k[SDL_SCANCODE_DOWN]) {
        dirs = (uint8_t)(dirs | JOY_DOWN);
    }
    if (k[SDL_SCANCODE_A] || k[SDL_SCANCODE_LEFT]) {
        dirs = (uint8_t)(dirs | JOY_LEFT);
    }
    if (k[SDL_SCANCODE_D] || k[SDL_SCANCODE_RIGHT]) {
        dirs = (uint8_t)(dirs | JOY_RIGHT);
    }
    g->input_dirs = dirs;
    g->input_fire = k[SDL_SCANCODE_SPACE] ? 1 : 0;
    /* S is also JOY_DOWN. Title uses the key edge; play uses the direction. */
    g->input_key_s = k[SDL_SCANCODE_S] ? 1 : 0;
    g->input_key_i = k[SDL_SCANCODE_I] ? 1 : 0;
    g->input_runstop = k[SDL_SCANCODE_ESCAPE] ? 1 : 0;
}

int main(int argc, char **argv) {
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_Texture *tex;
    Game game;
    uint32_t next;
    int run = 1;

    (void)argc;
    (void)argv;
    SDL_SetHint(SDL_HINT_VIDEO_HIGHDPI_DISABLED, "1");
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    if (blit_load() != 0) {
        SDL_Quit();
        return 1;
    }
    window = SDL_CreateWindow("RailGunner", SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED, 640, 400, 0);
    if (window == NULL) {
        fprintf(stderr, "SDL_CreateWindow: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    tex = renderer ? SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                       SDL_TEXTUREACCESS_STREAMING, 640, 400)
                   : NULL;
    if (renderer == NULL || tex == NULL) {
        fprintf(stderr, "SDL renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    sim_init(&game);
    if (audio_open() != 0) {
        fprintf(stderr, "audio disabled: %s\n", SDL_GetError());
    }
    audio_publish(&game);
    next = SDL_GetTicks();
    while (run) {
        SDL_Event event;
        uint32_t now;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                run = 0;
            }
        }
        now = SDL_GetTicks();
        /* One 20 ms tick per host frame. Leftover backlog is dropped. */
        if ((int32_t)(now - next) >= 0) {
            sample_input(&game);
            sim_tick(&game);
            audio_after_tick(&game);
            next += 20;
            if ((int32_t)(now - next) > 0) {
                next = now;
            }
        }
        blit_frame(tex, &game);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, tex, NULL, NULL);
        SDL_RenderPresent(renderer);
        SDL_Delay(1);
    }
    audio_close();
    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}

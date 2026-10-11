#include "sim.h"

#include "mode.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void dump_game(const Game *g) {
    uint8_t row;
    uint8_t col;
    uint8_t i;

    printf("frame %u\n", (unsigned)g->frame);
    printf("mode %u %s\n", g->mode, mode_name(g->mode));
    printf("present %s\n",
           g->present == PRESENT_HIRES_TITLE ? "HIRES" : "TEXT");
    printf("music %u\n", g->music_active);
    for (i = 0; i < MUSIC_VOICES; i++) {
        uint8_t ctrl = g->sid_ctrl[i];
        printf("voice %u wave %u freq %u gate %u ad %u sr %u pw %u\n", i,
               ctrl & (unsigned)~SID_GATE, (unsigned)g->sid_freq[i],
               ctrl & SID_GATE, g->sid_ad[i], g->sid_sr[i],
               (unsigned)g->sid_pw[i]);
    }
    printf("guard %u\n", g->mode_timer);
    printf("free %u\n", g->free_count);
    printf("player rail %u rest %u frame %u dir %u x %u y %u lives %u deploy %u\n",
           g->player_rail, g->player_rest_dir, g->player_frame, g->player_move_dir,
           (unsigned)(g->objects[0].x_lo | ((unsigned)g->objects[0].x_hi << 8)),
           g->objects[0].y_int, g->lives, g->deploy_timer);
    printf("score %u %u %u\n", g->score0, g->score1, g->score2);
    printf("kills %u quota %u\n", g->level_kills, g->level_quota);
    printf("tally shots %u a %u b %u c %u\n", (unsigned)g->tally_shots,
           (unsigned)g->tally_kill_a, (unsigned)g->tally_kill_b,
           (unsigned)g->tally_kill_c);
    printf("power %u twox %u clear %u repair %u\n", g->power_2x, g->score_2x,
           g->clear_armed, g->repair_timer);
    for (i = 0; i < OBJECT_CAPACITY; i++) {
        const Object *o = &g->objects[i];
        if (o->flags == 0) {
            continue;
        }
        printf("obj %u %u %u %u %u %u %u %u\n", i, o->flags, o->kind,
               o->x_hi, o->x_lo, o->y_int, o->sprite_ptr, o->reserved);
    }
    for (row = 0; row < SCREEN_H; row++) {
        for (col = 0; col < SCREEN_W; col++) {
            uint8_t glyph = g->cells[row][col].glyph;
            if (glyph == 0 || glyph == SC_SPACE) {
                continue;
            }
            printf("cell %u %u %u %u\n", row, col, glyph,
                   g->cells[row][col].color);
        }
    }
}

static int handle_dir(Game *g, const char *arg) {
    if (strcmp(arg, "U") == 0) {
        g->input_dirs = JOY_UP;
    } else if (strcmp(arg, "D") == 0) {
        g->input_dirs = JOY_DOWN;
    } else if (strcmp(arg, "L") == 0) {
        g->input_dirs = JOY_LEFT;
    } else if (strcmp(arg, "R") == 0) {
        g->input_dirs = JOY_RIGHT;
    } else if (strcmp(arg, "N") == 0) {
        g->input_dirs = 0;
    } else {
        fprintf(stderr, "unknown dir: %s\n", arg);
        return 1;
    }
    return 0;
}

static int handle_key(Game *g, const char *which, int held) {
    uint8_t bit = held ? 1 : 0;
    if (strcmp(which, "S") == 0) {
        g->input_key_s = bit;
    } else if (strcmp(which, "I") == 0) {
        g->input_key_i = bit;
    } else if (strcmp(which, "RUNSTOP") == 0) {
        g->input_runstop = bit;
    } else {
        fprintf(stderr, "unknown key: %s\n", which);
        return 1;
    }
    return 0;
}

static int handle_line(Game *g, const char *line, int *saw_dump) {
    char which[16];
    int held;

    if (line[0] == '\0' || line[0] == '#') {
        return 0;
    }
    if (strcmp(line, "tick") == 0) {
        sim_tick(g);
        return 0;
    }
    if (strcmp(line, "dump") == 0) {
        dump_game(g);
        *saw_dump = 1;
        return 0;
    }
    if (sscanf(line, "dir %15s", which) == 1 && strncmp(line, "dir ", 4) == 0) {
        return handle_dir(g, which);
    }
    if (sscanf(line, "fire %d", &held) == 1 && strncmp(line, "fire ", 5) == 0) {
        g->input_fire = held ? 1 : 0;
        return 0;
    }
    if (sscanf(line, "key %15s %d", which, &held) == 2 && strncmp(line, "key ", 4) == 0) {
        return handle_key(g, which, held);
    }
    fprintf(stderr, "unknown trace command: %s\n", line);
    return 1;
}

static int run_trace(FILE *in, Game *g) {
    char buf[256];
    int saw_dump = 0;

    while (fgets(buf, sizeof(buf), in) != NULL) {
        size_t n = strlen(buf);
        while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) {
            buf[--n] = '\0';
        }
        if (handle_line(g, buf, &saw_dump) != 0) {
            return 1;
        }
    }
    if (!saw_dump) {
        dump_game(g);
    }
    return 0;
}

int main(int argc, char **argv) {
    Game game;
    FILE *in;
    int rc;

    sim_init(&game);
    if (argc < 2) {
        return run_trace(stdin, &game);
    }
    in = fopen(argv[1], "r");
    if (in == NULL) {
        perror(argv[1]);
        return 1;
    }
    rc = run_trace(in, &game);
    fclose(in);
    return rc;
}

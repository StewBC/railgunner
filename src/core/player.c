#include "player.h"

#include "cargo.h"
#include "cells.h"
#include "data/tables.h"
#include "drones.h"
#include "message.h"
#include "objects.h"
#include "rail.h"
#include "sfx.h"
#include "waves.h"

static uint16_t player_x(const Game *g) {
    return (uint16_t)(g->objects[0].x_lo | ((uint16_t)g->objects[0].x_hi << 8));
}

static void player_set_x(Game *g, uint16_t x) {
    g->objects[0].x_lo = (uint8_t)x;
    g->objects[0].x_hi = (uint8_t)(x >> 8);
}

static void install_frame(Game *g, uint8_t dir) {
    /* The assembly copies 64 bytes into the player buffer at $F8.
     * player_frame is which source that copy used. */
    g->player_frame = dir;
    g->objects[0].sprite_ptr = SPR_PTR_PLAYER_0;
}

static void install_frame_for_rest(Game *g) {
    install_frame(g, g->player_rest_dir);
}

static void player_init(Game *g) {
    Object *p = &g->objects[0];

    g->player_rail = PLAYER_RAIL_H;
    g->player_rest_dir = SPR_DIR_UP;
    g->player_swing_t = 0;
    g->player_swing_to = 0;
    g->player_move_dir = PLAYER_DIR_NONE;
    g->player_cross_decided = 0;
    g->player_dead = 0;
    g->player_was_centre = 0;
    g->deploy_timer = 0;

    p->kind = OBJ_PLAYER;
    p->sprite_color = SPR_COLOR_PLAYER;
    p->sprite_attr = OBJA_MULTICOLOR;
    p->sprite_ptr = SPR_PTR_PLAYER_0;
    player_set_x(g, PLAYER_X_START);
    p->x_frac = 0;
    p->y_frac = 0;
    p->y_int = PLAYER_Y_HRAIL;
    p->flags = (uint8_t)(OBJF_ALLOCATED | OBJF_RENDER);
    install_frame_for_rest(g);
}

void player_begin_deploy(Game *g) {
    player_init(g);
    g->objects[0].flags = OBJF_ALLOCATED;
    g->deploy_timer = DEPLOY_HOLD_FRAMES;
    g->hud_status_dirty = 1;
}

static void deploy_tick(Game *g) {
    g->deploy_timer--;
    if (g->deploy_timer != 0) {
        return;
    }
    if (g->lives != 0) {
        g->lives--;
        g->hud_status_dirty = 1;
    }
    g->objects[0].sprite_color = SPR_COLOR_PLAYER;
    g->objects[0].flags = (uint8_t)(OBJF_ALLOCATED | OBJF_RENDER);
    install_frame_for_rest(g);
}

static int in_centre_gap_x(uint16_t x) {
    if ((x >> 8) != 0) {
        return 0;
    }
    if (x <= PLAYER_ARM_LEFT_MAX) {
        return 0;
    }
    if (x >= PLAYER_ARM_RIGHT_MIN) {
        return 0;
    }
    return 1;
}

static int in_centre_gap_y(uint8_t y) {
    if (y <= PLAYER_ARM_TOP_MAX) {
        return 0;
    }
    if (y >= PLAYER_ARM_BOT_MIN) {
        return 0;
    }
    return 1;
}

int player_at_intersection(const Game *g) {
    if (g->player_rail == PLAYER_RAIL_V) {
        return in_centre_gap_y(g->objects[0].y_int);
    }
    return in_centre_gap_x(player_x(g));
}

static int side_of_mid_h(const Game *g) {
    uint16_t x = player_x(g);
    if ((x >> 8) != 0) {
        return 1;
    }
    return x >= PLAYER_GAP_MID;
}

static int side_of_mid_v(const Game *g) {
    return g->objects[0].y_int >= PLAYER_Y_HRAIL;
}

static void step_h(Game *g) {
    uint16_t x = player_x(g);
    if (g->player_move_dir == PLAYER_DIR_RIGHT) {
        if (x > (uint16_t)(PLAYER_X_MAX - PLAYER_MOVE_STEP)) {
            x = PLAYER_X_MAX;
        } else {
            x = (uint16_t)(x + PLAYER_MOVE_STEP);
        }
    } else if (g->player_move_dir == PLAYER_DIR_LEFT) {
        if (x < (uint16_t)(PLAYER_X_MIN + PLAYER_MOVE_STEP)) {
            x = PLAYER_X_MIN;
        } else {
            x = (uint16_t)(x - PLAYER_MOVE_STEP);
        }
    } else {
        return;
    }
    player_set_x(g, x);
    g->objects[0].y_int = PLAYER_Y_HRAIL;
}

static void step_v(Game *g) {
    uint8_t y = g->objects[0].y_int;
    if (g->player_move_dir == PLAYER_DIR_UP) {
        if (y < (uint8_t)(PLAYER_Y_MIN + PLAYER_MOVE_STEP)) {
            y = PLAYER_Y_MIN;
        } else {
            y = (uint8_t)(y - PLAYER_MOVE_STEP);
        }
    } else if (g->player_move_dir == PLAYER_DIR_DOWN) {
        if (y > (uint8_t)(PLAYER_Y_MAX - PLAYER_MOVE_STEP)) {
            y = PLAYER_Y_MAX;
        } else {
            y = (uint8_t)(y + PLAYER_MOVE_STEP);
        }
    } else {
        return;
    }
    g->objects[0].y_int = y;
    player_set_x(g, PLAYER_X_VRAIL);
}

static void remap_to_v(Game *g) {
    if (g->player_rest_dir == SPR_DIR_UP) {
        g->player_rest_dir = SPR_DIR_LEFT;
    } else if (g->player_rest_dir == SPR_DIR_DOWN) {
        g->player_rest_dir = SPR_DIR_RIGHT;
    }
}

static void remap_to_h(Game *g) {
    if (g->player_rest_dir == SPR_DIR_LEFT) {
        g->player_rest_dir = SPR_DIR_UP;
    } else if (g->player_rest_dir == SPR_DIR_RIGHT) {
        g->player_rest_dir = SPR_DIR_DOWN;
    }
}

static void do_mount_v(Game *g) {
    g->player_swing_t = 0;
    remap_to_v(g);
    g->player_rail = PLAYER_RAIL_V;
    player_set_x(g, PLAYER_X_VRAIL);
    g->objects[0].y_int = PLAYER_Y_HRAIL;
    install_frame_for_rest(g);
}

static void do_mount_h(Game *g) {
    g->player_swing_t = 0;
    remap_to_h(g);
    g->player_rail = PLAYER_RAIL_H;
    player_set_x(g, PLAYER_X_VRAIL);
    g->objects[0].y_int = PLAYER_Y_HRAIL;
    install_frame_for_rest(g);
}

static void eval_center_h(Game *g) {
    if (g->input_dirs & JOY_UP) {
        g->player_move_dir = PLAYER_DIR_UP;
        do_mount_v(g);
        step_v(g);
        return;
    }
    if (g->input_dirs & JOY_DOWN) {
        g->player_move_dir = PLAYER_DIR_DOWN;
        do_mount_v(g);
        step_v(g);
        return;
    }
    if (g->player_move_dir == PLAYER_DIR_RIGHT) {
        if (g->input_dirs & JOY_LEFT) {
            g->player_move_dir = PLAYER_DIR_LEFT;
        }
        return;
    }
    if (g->input_dirs & JOY_RIGHT) {
        g->player_move_dir = PLAYER_DIR_RIGHT;
    }
}

static void eval_center_v(Game *g) {
    if (g->input_dirs & JOY_LEFT) {
        g->player_move_dir = PLAYER_DIR_LEFT;
        do_mount_h(g);
        step_h(g);
        return;
    }
    if (g->input_dirs & JOY_RIGHT) {
        g->player_move_dir = PLAYER_DIR_RIGHT;
        do_mount_h(g);
        step_h(g);
        return;
    }
    if (g->player_move_dir == PLAYER_DIR_UP) {
        if (g->input_dirs & JOY_DOWN) {
            g->player_move_dir = PLAYER_DIR_DOWN;
        }
        return;
    }
    if (g->input_dirs & JOY_UP) {
        g->player_move_dir = PLAYER_DIR_UP;
    }
}

static void move_on_h(Game *g) {
    int side_before;
    if (!in_centre_gap_x(player_x(g))) {
        g->player_cross_decided = 0;
        if (g->input_dirs & JOY_RIGHT) {
            g->player_move_dir = PLAYER_DIR_RIGHT;
            step_h(g);
        } else if (g->input_dirs & JOY_LEFT) {
            g->player_move_dir = PLAYER_DIR_LEFT;
            step_h(g);
        }
        return;
    }
    if (g->player_cross_decided) {
        if (g->player_move_dir != 0) {
            step_h(g);
        }
        return;
    }
    if (g->input_dirs & JOY_RIGHT) {
        g->player_move_dir = PLAYER_DIR_RIGHT;
    } else if (g->input_dirs & JOY_LEFT) {
        g->player_move_dir = PLAYER_DIR_LEFT;
    } else if (g->player_move_dir == 0) {
        if (player_x(g) < PLAYER_GAP_MID) {
            g->player_move_dir = PLAYER_DIR_LEFT;
        } else {
            g->player_move_dir = PLAYER_DIR_RIGHT;
        }
    }
    side_before = side_of_mid_h(g);
    step_h(g);
    if (g->player_cross_decided) {
        return;
    }
    if (side_of_mid_h(g) == side_before) {
        return;
    }
    eval_center_h(g);
    g->player_cross_decided = 1;
}

static void move_on_v(Game *g) {
    int side_before;
    if (!in_centre_gap_y(g->objects[0].y_int)) {
        g->player_cross_decided = 0;
        if (g->input_dirs & JOY_UP) {
            g->player_move_dir = PLAYER_DIR_UP;
            step_v(g);
        } else if (g->input_dirs & JOY_DOWN) {
            g->player_move_dir = PLAYER_DIR_DOWN;
            step_v(g);
        }
        return;
    }
    if (g->player_cross_decided) {
        if (g->player_move_dir != 0) {
            step_v(g);
        }
        return;
    }
    if (g->input_dirs & JOY_UP) {
        g->player_move_dir = PLAYER_DIR_UP;
    } else if (g->input_dirs & JOY_DOWN) {
        g->player_move_dir = PLAYER_DIR_DOWN;
    } else if (g->player_move_dir == 0) {
        if (g->objects[0].y_int < PLAYER_Y_HRAIL) {
            g->player_move_dir = PLAYER_DIR_UP;
        } else {
            g->player_move_dir = PLAYER_DIR_DOWN;
        }
    }
    side_before = side_of_mid_v(g);
    step_v(g);
    if (g->player_cross_decided) {
        return;
    }
    if (side_of_mid_v(g) == side_before) {
        return;
    }
    eval_center_v(g);
    g->player_cross_decided = 1;
}

static void start_swing(Game *g, uint8_t mid_dir) {
    install_frame(g, mid_dir);
    g->player_swing_t = PLAYER_SWING_MID_FRAMES;
}

static void update_barrel(Game *g) {
    if (g->player_swing_t != 0) {
        g->player_swing_t--;
        if (g->player_swing_t == 0) {
            g->player_rest_dir = g->player_swing_to;
            install_frame_for_rest(g);
        }
        return;
    }
    if (player_at_intersection(g)) {
        return;
    }
    if (g->player_rail == PLAYER_RAIL_V) {
        if (g->player_rest_dir == SPR_DIR_LEFT && (g->input_dirs & JOY_RIGHT)) {
            g->player_swing_to = SPR_DIR_RIGHT;
            start_swing(g, SPR_DIR_UP);
        } else if (g->player_rest_dir == SPR_DIR_RIGHT && (g->input_dirs & JOY_LEFT)) {
            g->player_swing_to = SPR_DIR_LEFT;
            start_swing(g, SPR_DIR_DOWN);
        }
        return;
    }
    if (g->player_rest_dir == SPR_DIR_UP && (g->input_dirs & JOY_DOWN)) {
        g->player_swing_to = SPR_DIR_DOWN;
        start_swing(g, SPR_DIR_RIGHT);
    } else if (g->player_rest_dir == SPR_DIR_DOWN && (g->input_dirs & JOY_UP)) {
        g->player_swing_to = SPR_DIR_UP;
        start_swing(g, SPR_DIR_LEFT);
    }
}

static const uint8_t explode_seq[DEATH_EXPLODE_STEPS] = {0, 1, 2, 1, 2, 1, 0};
static const uint8_t explode_ptr[DEATH_EXPLODE_FRAMES] = {
    SPR_PTR_EXPLODE_1, SPR_PTR_EXPLODE_2, SPR_PTR_EXPLODE_3};

static void show_player_explode(Game *g) {
    uint8_t art = explode_seq[g->death_phase];
    Object *p = &g->objects[0];
    if (art >= DEATH_EXPLODE_FRAMES) {
        art = DEATH_EXPLODE_FRAMES - 1;
    }
    p->sprite_ptr = explode_ptr[art];
    p->sprite_color = SPR_COLOR_EXPLODE;
    p->sprite_attr = OBJA_MULTICOLOR;
    p->flags = (uint8_t)(OBJF_ALLOCATED | OBJF_RENDER);
}

static void clear_banner_zone(Game *g) {
    uint8_t col;
    for (col = HUD_BANNER_COL; col < HUD_BANNER_END; col++) {
        screen_put_xy(g, col, HUD_ROW, SC_SPACE);
    }
}

static void paint_death_banner_color(Game *g) {
    uint8_t color;
    uint8_t col;
    uint8_t left;
    if (g->death_fatal) {
        color = g->death_flash ? COL_LT_RED : COL_RED;
    } else {
        color = g->death_flash ? COL_WHITE : COL_DK_GRAY;
    }
    col = g->death_banner_col;
    left = g->death_banner_len;
    while (left != 0) {
        screen_color_xy(g, col, HUD_ROW, color);
        col++;
        left--;
    }
}

static void paint_death_banner(Game *g) {
    const char *text;
    uint8_t len;
    clear_banner_zone(g);
    if (g->death_fatal) {
        text = str_game_over_banner;
        len = DEATH_GO_BANNER_LEN;
    } else {
        text = str_rip_pilot_banner;
        len = DEATH_RIP_BANNER_LEN;
    }
    g->death_banner_len = len;
    g->death_banner_col =
        (uint8_t)(HUD_BANNER_COL + (HUD_BANNER_ZONE_LEN - len) / 2);
    screen_print(g, g->death_banner_col, HUD_ROW, text);
    paint_death_banner_color(g);
}

static void death_go_flash_tick(Game *g) {
    g->death_flash_t--;
    if (g->death_flash_t != 0) {
        return;
    }
    g->death_flash_t = DEATH_GO_FLASH_FRAMES;
    g->death_flash = (uint8_t)(g->death_flash ^ 1);
    paint_death_banner_color(g);
}

static void finish_death(Game *g) {
    if (g->death_fatal) {
        g->player_dead = 0;
        g->pending_mode = MODE_GAME_OVER;
        return;
    }
    drones_clear_field(g);
    cargo_despawn_sprite(g);
    g->clear_armed = 0;
    g->power_2x = 0;
    g->score_2x = 0;
    g->repair_timer = 0;
    rail_clear_heal_marks(g);
    waves_load(g);
    player_begin_deploy(g);
    message_restore_hud_line(g);
}

static void death_tick(Game *g) {
    if (g->death_phase == DEATH_HOLD_PHASE) {
        death_go_flash_tick(g);
    }
    g->death_timer--;
    if (g->death_timer != 0) {
        return;
    }
    if (g->death_phase == DEATH_HOLD_PHASE) {
        finish_death(g);
        return;
    }
    if (g->death_phase == DEATH_EXPLODE_STEPS - 1) {
        g->death_phase = DEATH_HOLD_PHASE;
        g->death_timer = DEATH_HOLD_FRAMES;
        g->objects[0].flags = OBJF_ALLOCATED;
        g->death_flash = 0;
        g->death_flash_t = DEATH_GO_FLASH_FRAMES;
        paint_death_banner(g);
        return;
    }
    g->death_phase++;
    show_player_explode(g);
    g->death_timer = DEATH_EXPLODE_HOLD;
}

static void begin_death(Game *g, uint8_t fatal) {
    if (g->player_dead) {
        return;
    }
    g->death_fatal = fatal;
    g->player_dead = 1;
    g->death_phase = 0;
    g->repair_timer = 0;
    g->death_timer = DEATH_EXPLODE_HOLD;
    rail_clear_heal_marks(g);
    show_player_explode(g);
    sfx_play(g, SFX_PLAYER_DIE);
}

void player_begin_death_fatal(Game *g) {
    begin_death(g, 1);
}

void player_begin_death_respawn(Game *g) {
    begin_death(g, 0);
}

/* Rising edge of the centre gap. Clear wipes the hubs; mines detonate. */
static void check_clear_centre(Game *g) {
    if (!player_at_intersection(g)) {
        g->player_was_centre = 0;
        return;
    }
    if (g->player_was_centre) {
        return;
    }
    if (g->clear_armed) {
        g->clear_armed = 0;
        cargo_clear_stacks(g);
    } else if (g->mine_armed) {
        cargo_detonate(g);
    }
    g->player_was_centre = 1;
}

void player_update(Game *g) {
    if (g->player_dead) {
        death_tick(g);
        return;
    }
    if (g->deploy_timer != 0) {
        deploy_tick(g);
        return;
    }
    update_barrel(g);
    if (g->player_rail == PLAYER_RAIL_V) {
        move_on_v(g);
    } else {
        move_on_h(g);
    }
    check_clear_centre(g);
    rail_repair_tick(g);
}

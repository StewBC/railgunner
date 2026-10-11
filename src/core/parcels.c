#include "parcels.h"

#include "drones.h"
#include "objects.h"
#include "player.h"
#include "rail.h"
#include "score.h"
#include "sfx.h"

static const uint8_t type_ptr[6] = {
    SPR_PTR_ADD_SCORE, SPR_PTR_ADD_2X,  SPR_PTR_ADD_2X,
    SPR_PTR_ADD_CLEAR, SPR_PTR_ADD_EXTRA, SPR_PTR_ADD_REPAIR};
static const uint8_t type_color[6] = {
    SPR_COLOR_PARCEL_SCORE,   SPR_COLOR_PARCEL_SCORE2X,
    SPR_COLOR_PARCEL_POWER2X, SPR_COLOR_PARCEL_CLEAR,
    SPR_COLOR_PARCEL_EXTRA,   SPR_COLOR_PARCEL_REPAIR};
static const uint8_t score_parcel_points[15] = {
    5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75};

static void try_spawn(Game *g);
static void despawn(Game *g);

void parcels_init(Game *g) {
    g->parcel_slot = 0xFF;
    g->parcel_due = 0;
    g->parcel_flip = 0;
    g->parcel_drop_mask = 0;
    g->parcel_dir = 0;
    g->parcel_flags = 0;
    g->parcel_type = 0;
}

void parcels_level_reset(Game *g) {
    g->parcel_due = 0;
    g->parcel_drop_mask = 0;
}

static uint8_t div3(uint8_t value) {
    uint8_t count = 0;
    while (value >= 3) {
        value = (uint8_t)(value - 3);
        count++;
    }
    return count;
}

static uint8_t cargo_pressure(const Game *g) {
    uint8_t n = 0;
    uint8_t i;
    for (i = 0; i < 4; i++) {
        if (g->ghij_stack[i] != 0) {
            n++;
        }
    }
    return n;
}

static void choose_type(Game *g) {
    uint8_t pressure;
    uint8_t flags = g->parcel_flags;
    Object *o;

    if ((flags & PARCEL_FLAG_BLOCK_CLEAR) == 0) {
        pressure = cargo_pressure(g);
        if (pressure >= 3 ||
            (pressure == 2 && (drones_rng8(g) & 1) != 0)) {
            g->parcel_type = PARCEL_TYPE_CLEAR;
            g->parcel_flags = (uint8_t)((flags & (uint8_t)~PARCEL_FLAG_CLEAR) |
                                        PARCEL_FLAG_BLOCK_CLEAR);
            goto art;
        }
    }

    if (flags & PARCEL_FLAG_REPAIR) {
        g->parcel_type = PARCEL_TYPE_REPAIR;
        g->parcel_flags = (uint8_t)(flags & (uint8_t)~(PARCEL_FLAG_REPAIR |
                                                       PARCEL_FLAG_BLOCK_CLEAR));
        goto art;
    }

    if (flags & PARCEL_FLAG_EXTRA) {
        if (g->lives >= MAX_RESERVE_LIVES) {
            flags = (uint8_t)(flags & (uint8_t)~PARCEL_FLAG_EXTRA);
            g->parcel_flags = flags;
        } else {
            g->parcel_type = PARCEL_TYPE_EXTRA;
            g->parcel_flags =
                (uint8_t)(flags & (uint8_t)~(PARCEL_FLAG_EXTRA |
                                             PARCEL_FLAG_BLOCK_CLEAR));
            goto art;
        }
    }

    if (drones_rng8(g) < 128) {
        g->parcel_type = PARCEL_TYPE_POINTS;
    } else if (drones_rng8(g) & 1) {
        g->parcel_type = PARCEL_TYPE_SCORE2X;
    } else {
        g->parcel_type = PARCEL_TYPE_POWER2X;
    }
    g->parcel_flags = (uint8_t)(g->parcel_flags & (uint8_t)~PARCEL_FLAG_BLOCK_CLEAR);

art:
    o = &g->objects[g->parcel_slot];
    o->sprite_ptr = type_ptr[g->parcel_type];
    o->sprite_color = type_color[g->parcel_type];
}

/* 9-bit velocity of −PARCEL_SPEED. The high byte keeps bit 0 only. */
static void set_vx_neg(Object *o) {
    uint8_t borrow = (uint8_t)(PARCEL_SPEED != 0);
    o->vx_frac = 0;
    o->vx_lo = (uint8_t)(0 - PARCEL_SPEED);
    o->vx_hi = (uint8_t)((uint8_t)(0 - borrow) & 1);
}

static void set_vy_neg(Object *o) {
    o->vy_frac = 0;
    o->vy_int = (uint8_t)(0 - PARCEL_SPEED);
}

static void pick_arm_and_place(Game *g) {
    uint8_t axis;
    Object *o;

    if (!player_at_intersection(g)) {
        axis = (uint8_t)(g->player_rail == PLAYER_RAIL_V ? 0 : 1);
    } else if (g->player_move_dir == PLAYER_DIR_UP ||
               g->player_move_dir == PLAYER_DIR_DOWN) {
        axis = 0;
    } else if (g->player_move_dir == PLAYER_DIR_LEFT ||
               g->player_move_dir == PLAYER_DIR_RIGHT) {
        axis = 1;
    } else if (g->player_rail == PLAYER_RAIL_V) {
        axis = 0;
    } else {
        axis = 1;
    }

    g->parcel_flip = (uint8_t)(g->parcel_flip ^ 1);
    o = &g->objects[g->parcel_slot];
    if (axis == 0) {
        o->y_int = PLAYER_Y_HRAIL;
        if (g->parcel_flip != 0) {
            o->x_lo = DRONE_SPAWN_X_EDGE_R_LO;
            o->x_hi = DRONE_SPAWN_X_EDGE_R_HI;
            set_vx_neg(o);
            g->parcel_dir = SPR_DIR_LEFT;
        } else {
            o->x_lo = DRONE_SPAWN_X_EDGE_L_LO;
            o->x_hi = DRONE_SPAWN_X_EDGE_L_HI;
            o->vx_frac = 0;
            o->vx_hi = 0;
            o->vx_lo = PARCEL_SPEED;
            g->parcel_dir = SPR_DIR_RIGHT;
        }
    } else {
        o->x_lo = (uint8_t)PLAYER_X_VRAIL;
        o->x_hi = 0;
        if (g->parcel_flip != 0) {
            o->y_int = DRONE_SPAWN_Y_FROM_BOT;
            set_vy_neg(o);
            g->parcel_dir = SPR_DIR_UP;
        } else {
            o->y_int = DRONE_SPAWN_Y_FROM_TOP;
            o->vy_frac = 0;
            o->vy_int = PARCEL_SPEED;
            g->parcel_dir = SPR_DIR_DOWN;
        }
    }
    o->user = g->parcel_dir;
}

static void try_spawn(Game *g) {
    uint8_t slot;
    Object *o;

    if (g->parcel_slot != 0xFF) {
        g->parcel_due = 1;
        return;
    }
    if (objects_alloc(g, &slot) != 0) {
        g->parcel_due = 1;
        return;
    }
    g->parcel_slot = slot;
    choose_type(g);
    o = &g->objects[slot];
    o->kind = OBJ_BONUS;
    o->sprite_attr = OBJA_MULTICOLOR;
    o->reserved = g->parcel_type;
    o->x_frac = 0;
    o->y_frac = 0;
    o->vx_frac = 0;
    o->vx_lo = 0;
    o->vx_hi = 0;
    o->vy_frac = 0;
    o->vy_int = 0;
    pick_arm_and_place(g);
    g->objects[g->parcel_slot].flags = (uint8_t)(OBJF_ALLOCATED | OBJF_RENDER);
    sfx_play(g, SFX_PARCEL);
}

static void request_drop(Game *g) {
    if (g->parcel_slot == 0xFF) {
        try_spawn(g);
        return;
    }
    g->parcel_due = 1;
}

void parcels_on_kill(Game *g) {
    uint8_t quota;
    uint8_t kills;
    uint8_t sum;
    uint8_t mark;

    if (g->level_quota < 3) {
        return;
    }
    quota = g->level_quota;
    kills = g->level_kills;
    sum = (uint8_t)(quota + 2);
    if (quota > (uint8_t)(255 - 2)) {
        sum = 255;
    }
    mark = div3(sum);
    if ((g->parcel_drop_mask & PARCEL_DROP_T1) == 0 && kills >= mark) {
        g->parcel_drop_mask = (uint8_t)(g->parcel_drop_mask | PARCEL_DROP_T1);
        request_drop(g);
    }

    if (quota & 0x80) {
        sum = 255;
    } else {
        sum = (uint8_t)(quota << 1);
        if (sum > (uint8_t)(255 - 2)) {
            sum = 255;
        } else {
            sum = (uint8_t)(sum + 2);
        }
    }
    mark = div3(sum);
    if ((g->parcel_drop_mask & PARCEL_DROP_T2) == 0 && kills >= mark) {
        g->parcel_drop_mask = (uint8_t)(g->parcel_drop_mask | PARCEL_DROP_T2);
        if ((g->level & 1) == 0) {
            g->parcel_flags = (uint8_t)(g->parcel_flags | PARCEL_FLAG_REPAIR);
        }
        request_drop(g);
    }
}

static void integrate(Object *o) {
    uint16_t sum = (uint16_t)o->x_frac + o->vx_frac;
    o->x_frac = (uint8_t)sum;
    sum = (uint16_t)o->x_lo + o->vx_lo + (sum >> 8);
    o->x_lo = (uint8_t)sum;
    sum = (uint16_t)o->x_hi + o->vx_hi + (sum >> 8);
    o->x_hi = (uint8_t)(sum & 1);
    sum = (uint16_t)o->y_frac + o->vy_frac;
    o->y_frac = (uint8_t)sum;
    o->y_int = (uint8_t)(o->y_int + o->vy_int + (sum >> 8));
}

/* 1 while the sprite is still inside the field. */
static int still_on_field(const Game *g, const Object *o) {
    if (g->parcel_dir == SPR_DIR_RIGHT) {
        if (o->x_hi == 0) {
            return 1;
        }
        return o->x_lo < DRONE_SPAWN_X_EDGE_R_LO;
    }
    if (g->parcel_dir == SPR_DIR_LEFT) {
        if (o->x_hi != 0) {
            return 1;
        }
        return o->x_lo >= 4;
    }
    if (g->parcel_dir == SPR_DIR_DOWN) {
        return o->y_int < DRONE_SPAWN_Y_FROM_BOT;
    }
    return o->y_int >= DRONE_SPAWN_Y_FROM_TOP;
}

/* Lo-byte X test, matching the live path in the assembly. */
static int hits_player(const Game *g) {
    const Object *parcel = &g->objects[g->parcel_slot];
    const Object *player = &g->objects[0];
    uint8_t top = (uint8_t)(parcel->y_int + PARCEL_HIT_Y0);
    uint8_t bot = (uint8_t)(parcel->y_int + PARCEL_HIT_Y1);
    uint8_t ptop = (uint8_t)(player->y_int + 3);
    uint8_t pbot = (uint8_t)(player->y_int + 18);
    uint8_t left;
    uint8_t right;
    uint8_t pleft;
    uint8_t pright;

    if (top >= pbot || ptop >= bot) {
        return 0;
    }
    left = (uint8_t)(parcel->x_lo + PARCEL_HIT_X0);
    right = (uint8_t)(parcel->x_lo + PARCEL_HIT_X1);
    pleft = (uint8_t)(player->x_lo + 4);
    pright = (uint8_t)(player->x_lo + 20);
    if (left >= pright || pleft >= right) {
        return 0;
    }
    return 1;
}

static void award_payload(Game *g) {
    uint8_t level;
    if (g->parcel_type == PARCEL_TYPE_EXTRA) {
        sfx_play(g, SFX_EXTRA);
    } else {
        sfx_play(g, SFX_PING);
    }
    if (g->parcel_type == PARCEL_TYPE_SCORE2X) {
        g->score_2x = 1;
        return;
    }
    if (g->parcel_type == PARCEL_TYPE_POWER2X) {
        g->power_2x = 1;
        return;
    }
    if (g->parcel_type == PARCEL_TYPE_CLEAR) {
        g->clear_armed = 1;
        return;
    }
    if (g->parcel_type == PARCEL_TYPE_EXTRA) {
        if (g->lives < MAX_RESERVE_LIVES) {
            g->lives++;
            g->hud_status_dirty = 1;
        }
        return;
    }
    if (g->parcel_type == PARCEL_TYPE_REPAIR) {
        rail_begin_repair(g);
        return;
    }
    level = g->level;
    if (level == 0) {
        level = 1;
    }
    if (level > MAX_LEVEL) {
        level = MAX_LEVEL;
    }
    score_add_n(g, score_parcel_points[level - 1]);
}

static void despawn(Game *g) {
    if (g->parcel_slot != 0xFF) {
        objects_retire(g, g->parcel_slot);
        g->parcel_slot = 0xFF;
    }
    if (g->parcel_due) {
        g->parcel_due = 0;
        try_spawn(g);
    }
}

static void award_and_despawn(Game *g) {
    award_payload(g);
    despawn(g);
}

void parcels_update(Game *g) {
    Object *o;
    if (g->parcel_slot == 0xFF) {
        if (g->parcel_due == 0) {
            return;
        }
        g->parcel_due = 0;
        try_spawn(g);
        return;
    }
    o = &g->objects[g->parcel_slot];
    if ((o->flags & OBJF_ALLOCATED) == 0) {
        g->parcel_slot = 0xFF;
        return;
    }
    integrate(o);
    if (!still_on_field(g, o)) {
        despawn(g);
        return;
    }
    if (hits_player(g)) {
        award_and_despawn(g);
    }
}

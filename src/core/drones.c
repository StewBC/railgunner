#include "drones.h"

#include "cargo.h"
#include "data/tables.h"
#include "objects.h"
#include "rail.h"
#include "score.h"
#include "sfx.h"
#include "tallies.h"
#include "waves.h"

static const uint8_t explode_dv[3] = {
    SPR_PTR_EXPLODE_DV_1, SPR_PTR_EXPLODE_DV_2, SPR_PTR_EXPLODE_DV_3};
static const uint8_t explode_dh[3] = {
    SPR_PTR_EXPLODE_DH_1, SPR_PTR_EXPLODE_DH_2, SPR_PTR_EXPLODE_DH_3};

static int is_drone(const Object *o) {
    return o->kind >= OBJ_DRONE_A && o->kind < OBJ_BONUS;
}

static int is_live(const Object *o) {
    return (o->flags & (OBJF_ALLOCATED | OBJF_RETIRING)) == OBJF_ALLOCATED;
}

uint8_t drones_rng8(Game *g) {
    uint8_t a = g->rng_state;
    if (a == 0) {
        a = (uint8_t)(g->frame_count | 1);
    }
    if (a & 0x80) {
        a = (uint8_t)((uint8_t)(a << 1) ^ 0x1D);
    } else {
        a = (uint8_t)(a << 1);
    }
    g->rng_state = a;
    return a;
}

static uint8_t pick_speed_tier(Game *g, uint8_t kind) {
    uint8_t cap = g->drone_speed_cap;
    uint8_t max_tier;
    if (cap == 0) {
        cap = 1;
    }
    if (cap > MAX_LEVEL) {
        cap = MAX_LEVEL;
    }
    max_tier = cap;
    if (kind == OBJ_DRONE_A) {
        max_tier = (cap >= DRONE_TIER_OFF_A) ? (uint8_t)(cap - DRONE_TIER_OFF_A) : 1;
    } else if (kind == OBJ_DRONE_B) {
        max_tier = (cap >= DRONE_TIER_OFF_B) ? (uint8_t)(cap - DRONE_TIER_OFF_B) : 1;
    }
    if (max_tier < 1) {
        max_tier = 1;
    }
    while (max_tier >= 2) {
        if (drones_rng8(g) & 1) {
            break;
        }
        max_tier--;
    }
    return (uint8_t)(max_tier - 1);
}

static void speed_mag(Game *g, uint8_t kind, uint8_t approach, uint8_t *frac,
                      uint8_t *integ) {
    unsigned idx = (unsigned)pick_speed_tier(g, kind) * 8u + (unsigned)approach * 2u;
    *frac = drone_vel_tier[idx];
    *integ = drone_vel_tier[idx + 1];
    if (*frac == 0 && *integ == 0) {
        *frac = 1;
    }
}

static uint8_t ptr_for(uint8_t kind, uint8_t approach) {
    if (approach == DRONE_APPROACH_DOWN) {
        if (kind == OBJ_DRONE_A) {
            return SPR_PTR_DRONE_A_DOWN;
        }
        if (kind == OBJ_DRONE_B) {
            return SPR_PTR_DRONE_B_DOWN;
        }
        return SPR_PTR_DRONE_C_DOWN;
    }
    if (approach == DRONE_APPROACH_UP) {
        if (kind == OBJ_DRONE_A) {
            return SPR_PTR_DRONE_A_UP;
        }
        if (kind == OBJ_DRONE_B) {
            return SPR_PTR_DRONE_B_UP;
        }
        return SPR_PTR_DRONE_C_UP;
    }
    if (approach == DRONE_APPROACH_RIGHT) {
        if (kind == OBJ_DRONE_C) {
            return SPR_PTR_DRONE_C_RIGHT;
        }
        if (kind == OBJ_DRONE_A) {
            return SPR_PTR_DRONE_A_RIGHT;
        }
        return SPR_PTR_DRONE_B_RIGHT;
    }
    if (kind == OBJ_DRONE_C) {
        return SPR_PTR_DRONE_C_LEFT;
    }
    if (kind == OBJ_DRONE_A) {
        return SPR_PTR_DRONE_A_LEFT;
    }
    return SPR_PTR_DRONE_B_LEFT;
}

static void apply_speed(Game *g, Object *o, uint8_t kind, uint8_t approach) {
    uint8_t frac;
    uint8_t integ;
    speed_mag(g, kind, approach, &frac, &integ);
    if (approach == DRONE_APPROACH_DOWN) {
        o->vy_frac = frac;
        o->vy_int = integ;
    } else if (approach == DRONE_APPROACH_UP) {
        uint8_t borrow = frac != 0;
        o->vy_frac = (uint8_t)(0u - frac);
        o->vy_int = (uint8_t)(0u - integ - borrow);
    } else if (approach == DRONE_APPROACH_RIGHT) {
        o->vx_frac = frac;
        o->vx_lo = integ;
        o->vx_hi = 0;
    } else {
        uint8_t borrow = frac != 0;
        o->vx_frac = (uint8_t)(0u - frac);
        o->vx_lo = (uint8_t)(0u - integ - borrow);
        o->vx_hi = (integ != 0 || borrow) ? 1 : 0;
    }
}

uint8_t drones_count_active(const Game *g) {
    uint8_t slot;
    uint8_t n = 0;
    for (slot = 1; slot < OBJECT_CAPACITY; slot++) {
        const Object *o = &g->objects[slot];
        if (is_live(o) && is_drone(o)) {
            n++;
        }
    }
    return n;
}

static uint8_t rng_mod(Game *g, uint8_t max) {
    uint8_t a;
    if (max == 0) {
        return 0;
    }
    a = drones_rng8(g);
    while (a >= max) {
        a = (uint8_t)(a - max);
    }
    return a;
}

void drones_roll_cooldown(Game *g) {
    uint8_t span = (uint8_t)(g->wave_cd_max - g->wave_cd_min + 1);
    g->drone_spawn_timer = (uint8_t)(rng_mod(g, span) + g->wave_cd_min);
}

static uint8_t band_pick(Game *g, uint8_t lo, uint8_t hi) {
    uint8_t span = (uint8_t)(hi - lo + 1);
    return (uint8_t)(rng_mod(g, span) + lo);
}

/* Q1 and Q2 use the right vertical band. Q3 and Q4 use the left. */
static void place_x_for_quad(Game *g, Object *o, uint8_t quad) {
    if (quad == 0 || quad == 1) {
        o->x_lo = band_pick(g, DRONE_BAND_X_R0, DRONE_BAND_X_R1);
    } else {
        o->x_lo = band_pick(g, DRONE_BAND_X_L0, DRONE_BAND_X_L1);
    }
    o->x_hi = 0;
}

/* Q2 and Q3 use the bottom horizontal band. Q1 and Q4 use the top. */
static void place_y_for_quad(Game *g, Object *o, uint8_t quad) {
    if (quad == 1 || quad == 2) {
        o->y_int = band_pick(g, DRONE_BAND_Y_B0, DRONE_BAND_Y_B1);
    } else {
        o->y_int = band_pick(g, DRONE_BAND_Y_T0, DRONE_BAND_Y_T1);
    }
}

/* 0 on success. The mux's fail-closed discard is not ported. */
static int spawn_drone(Game *g, uint8_t kind, uint8_t quad, uint8_t approach) {
    uint8_t slot;
    Object *o;
    if (objects_alloc(g, &slot) != 0) {
        return 1;
    }
    o = &g->objects[slot];
    o->kind = kind;
    o->sprite_attr = OBJA_MULTICOLOR;
    o->anim_state = 0;
    if (kind == OBJ_DRONE_A) {
        o->sprite_color = SPR_COLOR_DRONE_A;
        o->reserved = DRONE_HP_A;
    } else if (kind == OBJ_DRONE_B) {
        o->sprite_color = SPR_COLOR_DRONE_B;
        o->reserved = DRONE_HP_B;
    } else {
        o->sprite_color = SPR_COLOR_DRONE_C;
        o->reserved = DRONE_HP_C;
    }
    o->x_frac = 0;
    o->y_frac = 0;
    o->vx_frac = 0;
    o->vx_lo = 0;
    o->vx_hi = 0;
    o->vy_frac = 0;
    o->vy_int = 0;
    o->user = approach;
    o->sprite_ptr = ptr_for(kind, approach);
    if (approach == DRONE_APPROACH_DOWN) {
        place_x_for_quad(g, o, quad);
        o->y_int = DRONE_SPAWN_Y_FROM_TOP;
    } else if (approach == DRONE_APPROACH_UP) {
        place_x_for_quad(g, o, quad);
        o->y_int = DRONE_SPAWN_Y_FROM_BOT;
    } else if (approach == DRONE_APPROACH_RIGHT) {
        o->x_lo = DRONE_SPAWN_X_EDGE_L_LO;
        o->x_hi = DRONE_SPAWN_X_EDGE_L_HI;
        place_y_for_quad(g, o, quad);
    } else {
        o->x_lo = DRONE_SPAWN_X_EDGE_R_LO;
        o->x_hi = DRONE_SPAWN_X_EDGE_R_HI;
        place_y_for_quad(g, o, quad);
    }
    apply_speed(g, o, kind, approach);
    o->flags = (uint8_t)(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST);
    return 0;
}

static void color_for_hp(Object *o) {
    if (o->kind < OBJ_DRONE_A || o->kind >= OBJ_BONUS || o->kind == OBJ_DRONE_C) {
        return;
    }
    if (o->reserved >= 3) {
        o->sprite_color = SPR_COLOR_HP3;
    } else if (o->reserved >= 2) {
        o->sprite_color = SPR_COLOR_HP2;
    } else {
        o->sprite_color = SPR_COLOR_HP1;
    }
}

static void show_explode_frame(Object *o) {
    uint8_t phase = (uint8_t)(o->anim_state & 0x7F);
    if (phase > 2) {
        phase = 2;
    }
    if (o->user < DRONE_APPROACH_RIGHT) {
        o->sprite_ptr = explode_dv[phase];
    } else {
        o->sprite_ptr = explode_dh[phase];
    }
}

static void begin_explode(Game *g, uint8_t slot) {
    Object *o = &g->objects[slot];
    o->vx_frac = 0;
    o->vx_lo = 0;
    o->vx_hi = 0;
    o->vy_frac = 0;
    o->vy_int = 0;
    o->flags = (uint8_t)((o->flags & (uint8_t)~OBJF_BG_INTEREST) | OBJF_RENDER);
    o->anim_state = DRONE_DYING_BIT;
    o->reserved = DEATH_EXPLODE_HOLD;
    o->sprite_color = SPR_COLOR_EXPLODE;
    o->sprite_attr = OBJA_MULTICOLOR;
    show_explode_frame(o);
    sfx_play(g, SFX_DRONE_DIE);
}

static void death_tick(Game *g, uint8_t slot) {
    Object *o = &g->objects[slot];
    uint8_t phase;
    o->reserved--;
    if (o->reserved != 0) {
        return;
    }
    phase = (uint8_t)(o->anim_state & 0x7F);
    if (phase >= 2) {
        objects_retire(g, slot);
        return;
    }
    o->anim_state = (uint8_t)((phase + 1) | DRONE_DYING_BIT);
    show_explode_frame(o);
    o->reserved = DEATH_EXPLODE_HOLD;
}

static void integrate_slot(Object *o) {
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

static void check_rail_arrival(Game *g, uint8_t slot) {
    Object *o = &g->objects[slot];
    int hit = 0;
    if (o->user == DRONE_APPROACH_DOWN) {
        hit = o->y_int >= DRONE_RAIL_ARRIVE_Y;
    } else if (o->user == DRONE_APPROACH_UP) {
        hit = o->y_int <= DRONE_RAIL_ARRIVE_Y_UP;
    } else if (o->user == DRONE_APPROACH_RIGHT) {
        hit = o->x_hi != 0 || o->x_lo >= DRONE_RAIL_ARRIVE_X_R;
    } else {
        hit = o->x_hi == 0 && o->x_lo <= DRONE_RAIL_ARRIVE_X_L;
    }
    if (!hit) {
        return;
    }
    if ((o->anim_state & DRONE_DYING_BIT) == 0 && !g->player_dead) {
        if (o->kind == OBJ_DRONE_C) {
            cargo_on_c_impact(g, slot);
        } else if (o->kind == OBJ_DRONE_A || o->kind == OBJ_DRONE_B) {
            drones_apply_rail_strikes(g, slot);
        }
    }
    objects_retire(g, slot);
}

void drones_apply_rail_strikes(Game *g, uint8_t slot) {
    uint8_t hp = g->objects[slot].reserved;
    if (hp == 0) {
        hp = 1;
    }
    if (hp > 3) {
        hp = 3;
    }
    g->rail_dmg_amt = hp;
    rail_apply_ab_hit(g, slot);
}

void drones_apply_bullet_hit(Game *g, uint8_t slot) {
    Object *o = &g->objects[slot];
    uint8_t damage = g->power_2x ? 2 : 1;
    if (o->anim_state & DRONE_DYING_BIT) {
        return;
    }
    score_add_hit(g);
    if (o->reserved != 0) {
        if (o->reserved > damage) {
            o->reserved = (uint8_t)(o->reserved - damage);
        } else {
            o->reserved = 0;
        }
    }
    if (o->reserved == 0) {
        tallies_note_kill(g, slot);
        waves_note_kill(g);
        begin_explode(g, slot);
        return;
    }
    color_for_hp(o);
}

void drones_clear_field(Game *g) {
    uint8_t slot;
    for (slot = 1; slot < OBJECT_CAPACITY; slot++) {
        if (g->objects[slot].flags & OBJF_ALLOCATED) {
            objects_retire(g, slot);
        }
    }
    g->cargo_slot = 0xFF;
    g->parcel_slot = 0xFF;
}

static const uint8_t quad_bit[4] = {WAVE_Q1, WAVE_Q2, WAVE_Q3, WAVE_Q4};

/* Q1 UR, Q2 LR, Q3 LL, Q4 UL. Two legal approaches each. */
static const uint8_t approach_pair[8] = {
    DRONE_APPROACH_DOWN, DRONE_APPROACH_LEFT, DRONE_APPROACH_UP, DRONE_APPROACH_LEFT,
    DRONE_APPROACH_UP, DRONE_APPROACH_RIGHT, DRONE_APPROACH_DOWN, DRONE_APPROACH_RIGHT};

static uint8_t count_quad_bits(const Game *g) {
    uint8_t n = 0;
    uint8_t i;
    for (i = 0; i < 4; i++) {
        if (quad_bit[i] & g->wave_quad_mask) {
            n++;
        }
    }
    return n;
}

static uint8_t kills_remaining(const Game *g) {
    if (g->deploy_timer != 0 || g->level_banner_t != 0) {
        return 0;
    }
    if (g->level_kills >= g->level_quota) {
        return 0;
    }
    return 1;
}

static uint8_t roll_type(Game *g) {
    uint8_t weight_c = 0;
    uint8_t weight_b = 0;
    uint8_t weight_a = 0;
    uint8_t sum;
    uint8_t roll;
    if (g->wave_flags & WAVE_F_MAIN_C) {
        weight_c = 4;
    }
    if (g->level_kills >= (uint8_t)(g->level_quota >> 2)) {
        weight_b = 4;
        if (g->level_kills >= (uint8_t)(g->level_quota >> 1)) {
            weight_a = 3;
        }
    }
    sum = (uint8_t)(weight_c + weight_b + weight_a);
    if (sum == 0) {
        return 0;
    }
    roll = rng_mod(g, sum);
    if (roll < weight_c) {
        return OBJ_DRONE_C;
    }
    roll = (uint8_t)(roll - weight_c);
    if (roll < weight_b) {
        return OBJ_DRONE_B;
    }
    return OBJ_DRONE_A;
}

static uint8_t roll_quad(Game *g) {
    uint8_t list[4];
    uint8_t count = 0;
    uint8_t i;
    for (i = 0; i < 4; i++) {
        if ((quad_bit[i] & g->wave_quad_mask) == 0) {
            continue;
        }
        if (i == g->spawn_last_quad && count != 0 && count_quad_bits(g) >= 2) {
            continue;
        }
        list[count++] = i;
    }
    if (count == 0) {
        return 3;
    }
    return list[rng_mod(g, count)];
}

static uint8_t roll_approach(Game *g, uint8_t quad) {
    uint8_t choice = (uint8_t)(drones_rng8(g) & 1);
    return approach_pair[quad * 2u + choice];
}

static void schedule_piggy(Game *g, uint8_t quad, uint8_t approach) {
    if (g->piggy_timer != 0) {
        return;
    }
    g->piggy_timer = (uint8_t)(rng_mod(g, WAVE_PIGGY_SPAN) + WAVE_PIGGY_MIN);
    g->piggy_quad = quad;
    g->piggy_approach = approach;
}

static void spawn_tick_main(Game *g) {
    uint8_t kind;
    uint8_t quad;
    uint8_t approach;
    if (g->drone_spawn_timer != 0) {
        g->drone_spawn_timer--;
        return;
    }
    drones_roll_cooldown(g);
    if (!kills_remaining(g)) {
        return;
    }
    if (drones_count_active(g) >= g->wave_max_active) {
        return;
    }
    kind = roll_type(g);
    if (kind == 0) {
        return;
    }
    quad = roll_quad(g);
    approach = roll_approach(g, quad);
    if (spawn_drone(g, kind, quad, approach) != 0) {
        return;
    }
    g->spawn_last_quad = quad;
    if (kind == OBJ_DRONE_C) {
        return;
    }
    if ((g->wave_flags & WAVE_F_PIGGY_C) == 0) {
        return;
    }
    schedule_piggy(g, quad, approach);
}

static void spawn_tick_piggy(Game *g) {
    uint8_t approach;
    if (g->piggy_timer == 0) {
        return;
    }
    g->piggy_timer--;
    if (g->piggy_timer != 0) {
        return;
    }
    if (drones_count_active(g) >= g->wave_max_active) {
        return;
    }
    if (drones_rng8(g) & 1) {
        approach = roll_approach(g, g->piggy_quad);
    } else {
        approach = g->piggy_approach;
    }
    spawn_drone(g, OBJ_DRONE_C, g->piggy_quad, approach);
}

void drones_init(Game *g) {
    (void)g;
}

void drones_update(Game *g) {
    uint8_t slot;
    for (slot = 1; slot < OBJECT_CAPACITY; slot++) {
        Object *o = &g->objects[slot];
        if (!is_live(o) || !is_drone(o)) {
            continue;
        }
        if (o->anim_state & DRONE_DYING_BIT) {
            death_tick(g, slot);
            continue;
        }
        integrate_slot(o);
        check_rail_arrival(g, slot);
    }
    spawn_tick_main(g);
    spawn_tick_piggy(g);
}

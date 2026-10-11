#include "objects.h"

#include "sim.h"

#include <string.h>

void objects_clear_slot(Game *g, uint8_t slot) {
    memset(&g->objects[slot], 0, sizeof(g->objects[slot]));
}

void objects_init(Game *g) {
    uint8_t i;

    memset(g->objects, 0, sizeof(g->objects));
    g->objects[0].flags = OBJF_ALLOCATED;
    g->objects[0].kind = OBJ_PLAYER;
    g->objects[0].sprite_ptr = SPR_PTR_PLAYER_0;

    /* stack[22] = 1 ... stack[0] = 23. Pop yields the lowest free slot. */
    for (i = 0; i < OBJECT_FREE_CAPACITY; i++) {
        g->free_stack[i] = (uint8_t)(OBJECT_LAST - i);
    }
    g->free_count = OBJECT_FREE_CAPACITY;
}

int objects_alloc(Game *g, uint8_t *slot) {
    uint8_t picked;

    if (g->free_count == 0) {
        return OBJ_ERR_POOL_FULL;
    }
    g->free_count--;
    picked = g->free_stack[g->free_count];
    objects_clear_slot(g, picked);
    g->objects[picked].flags = OBJF_ALLOCATED;
    *slot = picked;
    return 0;
}

void objects_discard_new(Game *g, uint8_t slot) {
    objects_clear_slot(g, slot);
    g->free_stack[g->free_count] = slot;
    g->free_count++;
}

int objects_retire(Game *g, uint8_t slot) {
    uint8_t flags;

    if (slot == 0) {
        return OBJ_ERR_PLAYER_FIXED;
    }
    flags = g->objects[slot].flags;
    if ((flags & OBJF_ALLOCATED) == 0) {
        return 0;
    }
    flags = (uint8_t)((flags & (uint8_t)~OBJF_RENDER) | OBJF_RETIRING);
    g->objects[slot].flags = flags;
    return 0;
}

void objects_hide_all(Game *g) {
    uint8_t slot;

    for (slot = 0; slot < OBJECT_CAPACITY; slot++) {
        if (g->objects[slot].flags & OBJF_ALLOCATED) {
            g->objects[slot].flags =
                (uint8_t)(g->objects[slot].flags & (uint8_t)~OBJF_RENDER);
        }
    }
}

void objects_reap(Game *g) {
    uint8_t slot;

    for (slot = 1; slot < OBJECT_CAPACITY; slot++) {
        uint8_t flags = g->objects[slot].flags;
        if ((flags & (OBJF_ALLOCATED | OBJF_RETIRING)) !=
            (OBJF_ALLOCATED | OBJF_RETIRING)) {
            continue;
        }
        /* No VIC plan can still be showing this slot. */
        objects_clear_slot(g, slot);
        g->free_stack[g->free_count] = slot;
        g->free_count++;
    }
}

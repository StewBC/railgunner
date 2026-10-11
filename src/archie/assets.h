#ifndef RG_ARCHIE_ASSETS_H
#define RG_ARCHIE_ASSETS_H
#include <stdint.h>
extern const uint32_t (*const rg_word_pairs[16])[2];
extern const uint32_t rg_title_packed[8000];
extern const uint32_t rg_text_tiles[16][256][8];
extern const uint8_t rg_charset[2048], rg_title[8000], rg_title_colors[1000];
extern const uint8_t *const rg_sprites[256], *const rg_players[4];
extern const uint32_t (*const rg_sprite_tokens[256])[273];
extern const uint32_t (*const rg_player_tokens[4])[273];
extern const uint32_t (*const rg_sprite_word_tokens[256])[84];
extern const uint32_t (*const rg_player_word_tokens[4])[84];
#ifdef __arm__
typedef void (*RGCompiledSprite)(uint32_t *,const uint32_t (*)[2]);
extern const RGCompiledSprite rg_compiled_sprites[256][8],rg_compiled_players[4][8];
#endif
#endif

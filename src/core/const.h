#ifndef RAILGUNNER_CONST_H
#define RAILGUNNER_CONST_H

/* Game constants copied from src/c64/sys/const.asm.
 * VIC, CIA, and SID register addresses, the keyboard matrix,
 * the sprite multiplexer, and the profiler ids are not here. */

#define SID_WAVE_TRI 0x10
#define SID_WAVE_SAW 0x20
#define SID_WAVE_PULSE 0x40
#define SID_WAVE_NOISE 0x80
#define SID_GATE 0x01
#define SID_VOL_MAX 0x0F  /* no filter mode bits */
// One-shot SFX ids — also priority (lower number = higher priority).
// No continuous gun fire / spindown (by design).
#define SFX_UI_FIRE 0  /* menu FIRE acknowledge (soft thump) */
#define SFX_HS_TICK 1  /* high-score initial scroll tick */
#define SFX_WAVE 2  /* wave / level start whoop×3 */
#define SFX_MINE 3  /* cargo hubs arm → mine clink */
#define SFX_PARCEL 4  /* bonus parcel launched swoosh */
#define SFX_PLAYER_DIE 5  /* player explode rumble (noise) */
#define SFX_EXTRA 6  /* extra life parcel collect cha-ching */
#define SFX_HEAL 7  /* rail heal swish */
#define SFX_DRONE_DIE 8  /* drone explode pop */
#define SFX_PING 9  /* non-extra parcel collect (friendly ping) */
#define SFX_COUNT 10
#define SFX_FREE 0xFF  /* voice idle marker */
#define BITMAP_SIZE 8000  /* 320×200 / 8 */
#define BITMAP_COLOR_SIZE 1000  /* 40×25 colour matrix */
#define CHARSET_SIZE 2048  /* 256 glyphs × 8 bytes */
#define SPRITE_H_PX 21  /* VIC sprite height (lines) */
// Screen geometry
#define SCREEN_W 40
#define SCREEN_H 25
#define SCREEN_SIZE 1000  /* 40 * 25 */
// Default text colours (VIC colour nybbles)
#define COL_BLACK 0x00
#define COL_WHITE 0x01
#define COL_RED 0x02
#define COL_CYAN 0x03
#define COL_PURPLE 0x04
#define COL_GREEN 0x05
#define COL_BLUE 0x06
#define COL_YELLOW 0x07
#define COL_ORANGE 0x08
#define COL_BROWN 0x09
#define COL_LT_RED 0x0A
#define COL_DK_GRAY 0x0B
#define COL_GRAY 0x0C
#define COL_LT_GREEN 0x0D
#define COL_LT_BLUE 0x0E
#define COL_LT_GRAY 0x0F
/* input_dirs bitfield. These are the poll result, not the CIA matrix. */
#define JOY_UP 0x01
#define JOY_DOWN 0x02
#define JOY_LEFT 0x04
#define JOY_RIGHT 0x08
#define JOY_FIRE 0x10
// ---------------------------------------------------------------------------
// Game mode IDs (game_mode ZP)
// ---------------------------------------------------------------------------
#define MODE_TITLE_GFX 0  /* hires art attract page */
#define MODE_GAME_INIT 1
#define MODE_STAGE_INIT 2
#define MODE_PLAY 3
#define MODE_NEXT_WAVE 4
#define MODE_NEXT_LEVEL 5
#define MODE_NEXT_LIFE 6
#define MODE_GAME_OVER 7
#define MODE_HISCORE 8
#define MODE_TITLE_TEXT 9  /* text menu + high scores (primary frontend) */
#define MODE_STORY 10
#define MODE_INSTRUCTIONS 11
#define MODE_COUNT 12
// Alias: cold-start / return-from-game frontend entry
#define MODE_TITLE MODE_TITLE_TEXT
// ---------------------------------------------------------------------------
// Session defaults (roadmap placeholders)
// ---------------------------------------------------------------------------
// lives ZP = reserve ships on HUD (not the ship on the board).
// New game: START_LIVES icons shown, then deploy peels one → START_LIVES-1 reserve.
#define START_LIVES 3  /* pre-deploy HUD count */
#define MAX_RESERVE_LIVES 4  /* hard cap on reserve (extra life) */
#define DEPLOY_HOLD_FRAMES 45  /* ~0.9s @ 50Hz: show reserves, then peel */
#define START_LEVEL 1
#define MAX_LEVEL 15
#define EXTRA_KILL_EVERY 100  /* session kills → extra_due (mod counter) */
// Rank banner: was 50 (~1s); 50% longer + clean 10-colour wheel (high-score palette)
#define LEVEL_BANNER_FRAMES 75  /* ~1.5s (PAL 50Hz) */
#define BANNER_NUM_COLORS 10  /* score_color_table length */
#define BANNER_COLOR_HOLD 7  /* LEVEL_BANNER_FRAMES / BANNER_NUM_COLORS (int) */
#define BANNER_PAD_SPACES 2  /* leading+trailing spaces when room */
#define LEVEL_BAR_CELLS 8
#define LEVEL_BAR_STEPS 32  /* 8 cells × 4 UDG steps */
// Spawn quadrants / flags (level-driven; no player-facing waves)
#define WAVE_Q1 0x01
#define WAVE_Q2 0x02
#define WAVE_Q3 0x04
#define WAVE_Q4 0x08
#define WAVE_Q_TOP (WAVE_Q1 | WAVE_Q4)
#define WAVE_Q_ALL (WAVE_Q1 | WAVE_Q2 | WAVE_Q3 | WAVE_Q4)
#define WAVE_F_PIGGY_C 0x01
#define WAVE_F_MAIN_C 0x02
#define WAVE_AB_MAX 1
#define WAVE_PIGGY_MIN 6
#define WAVE_PIGGY_SPAN 36
#define WAVE_CD_MIN_FLOOR 12
#define WAVE_CD_SPAN_MIN 10
#define WAVE_MAX_ACTIVE_CAP 10
// C cargo (orange parcel sprite) → GHIJ hub stacks. K per tile to arm;
// default K=1 → 4 landings arm mines; centre pass while armed → death.
#define CARGO_SPEED 2  /* px/frame toward assigned G/H/I/J */
#define MINE_STACK_K 1
// Sprite top-left so parcel disc centres on GHIJ char cells (see cargo.asm)
#define CARGO_TGT_X0 160  /* G col18 */
#define CARGO_TGT_X1 176  /* H col20 */
#define CARGO_TGT_Y0 140  /* rows 12 (G/H) */
#define CARGO_TGT_Y1 156  /* rows 14 (I/J) */
// Pixel inset for drone→col (matches rail::apply_ab_hit body align)
#define DRONE_IMPACT_X_OFF 4
// Rail toughness (damage *taken* 0..HP; glyph mapped separately).
// Light/medium/heavy strikes = 1/2/3 (remaining drone HP). Tune here for fun.
#define RAIL_OUTER_HP 6  /* D/F/A/C full → destroyed */
#define RAIL_CORE_HP 5  /* E/B full → game over at this damage */
// Score: 1 registered hit = 1 point (not 1 bullet). Cap for 6-digit HUD.
// A/B/C kill totals = hit points (3/2/1) once multi-HP is live.
#define SCORE_HIT_POINTS 1
#define SCORE_MAX0 0x3F  /* 999999 = $0F423F (lo, mid, hi) */
#define SCORE_MAX1 0x42
#define SCORE_MAX2 0x0F
// ---------------------------------------------------------------------------
// Player (full cross — Step 8.1+)
// VIC sprite top-left. Char col C left edge ≈ 24+C*8.
// Gun aim X = sprite_x + PLAYER_GUN_X_OFF (centre of 24px sprite).
// 4px steps on a grid so aim hits left 2px or right 2px of a char cell:
//   (sprite_x + GUN_OFF - 24) mod 8 ∈ {0, 4}  →  OO...... / ....OO..
// ---------------------------------------------------------------------------
#define PLAYER_MOVE_STEP 4
#define PLAYER_SWING_MID_FRAMES 5
// H-rail mid (layout): sit on the E row band.
#define PLAYER_Y_HRAIL 146
// V-rail centerline X (4px grid; gun ≈ col 19). In H centre gap for mount.
#define PLAYER_X_VRAIL 169
// Aim X = sprite_x + GUN_OFF. One coordinate for move, clamp, fire, and draw.
// GUN_OFF 11: barrel tip (~px 10–11) meets half-cell bullet lanes on the 4px grid.
#define PLAYER_GUN_X_OFF 11
//
// H-rail stops (4px grid from X_MIN). Centre gap (LEFT_MAX, RIGHT_MIN) is the
// intersection in X — walk-through on H, mount zone for V.
#define PLAYER_X_MIN 13
#define PLAYER_X_MAX 329
#define PLAYER_ARM_LEFT_MAX 153
#define PLAYER_ARM_RIGHT_MIN 181
#define PLAYER_X_START 153
#define PLAYER_GAP_MID 167
// V-rail stops (4px grid ≡ 2 mod 4, matching Y_HRAIL). Centre gap in Y.
#define PLAYER_Y_MIN 58
#define PLAYER_Y_MAX 234
#define PLAYER_ARM_TOP_MAX 130
#define PLAYER_ARM_BOT_MIN 162
// player_rail
#define PLAYER_RAIL_H 0
#define PLAYER_RAIL_V 1
// player_move_dir values
#define PLAYER_DIR_NONE 0
#define PLAYER_DIR_RIGHT 1
#define PLAYER_DIR_LEFT 2
#define PLAYER_DIR_UP 3
#define PLAYER_DIR_DOWN 4
#define SPR_COLOR_PLAYER COL_PURPLE
// Attract loop: text ↔ graphics (PAL 50Hz × 15s)
#define ATTRACT_SECONDS 15
#define ATTRACT_HZ 50
#define ATTRACT_FRAMES (ATTRACT_SECONDS * ATTRACT_HZ)  /* 750 */
// Score-row colour wheel step (frames per shift; ~5 Hz on PAL)
#define SCORE_COLOR_PERIOD 10
// ---------------------------------------------------------------------------
// Video cadence
// ---------------------------------------------------------------------------
#define VIDEO_PAL 0
#define VIDEO_NTSC 1
#define LOGIC_HZ 50
#define PAL_DISPLAY_HZ 50
#define NTSC_DISPLAY_HZ 60
// ---------------------------------------------------------------------------
// Graphical-object pool
// ---------------------------------------------------------------------------
#define OBJECT_CAPACITY 24
#define OBJECT_LAST (OBJECT_CAPACITY - 1)
#define OBJECT_FREE_CAPACITY (OBJECT_CAPACITY - 1)
#define OBJECT_NONE 0xFF
#define OBJ_PLAYER 0
#define OBJ_DRONE_A 1  /* large, back */
#define OBJ_DRONE_B 2  /* medium */
#define OBJ_DRONE_C 3  /* small, front */
#define OBJ_BONUS 4
#define OBJ_EFFECT 5
#define OBJF_ALLOCATED 0x01
#define OBJF_RENDER 0x02
#define OBJF_RETIRING 0x04
#define OBJF_BG_INTEREST 0x08
#define OBJF_SS_INTEREST 0x10
#define OBJA_MULTICOLOR 0x01
#define OBJA_X_EXPAND 0x02
#define OBJA_Y_EXPAND 0x04
#define OBJA_BEHIND_BG 0x08
#define OBJE_BG 0x01
#define OBJE_SS 0x02
// Collision dogfood modes (see game/collision.asm):
//   0 = HW latch only ($D01F / OBJE_BG) — trust mux attribution
//   1 = hybrid (latch filter + software authority + mismatch borders)
//   2 = software always (ignore latch)
#define COLLISION_MODE 0
#define OBJ_ERR_POOL_FULL 1
#define OBJ_ERR_PLAYER_FIXED 2
// ---------------------------------------------------------------------------
// Sprite frames after sprite_frames_install → $3000 (64-byte stride)
// Source: DATA segment (src/c64/data/sprites.asm). Pointer = address / 64.
// ---------------------------------------------------------------------------
// Shared multicolour pair (all MC sprites; set once per stage / cold init)
#define SPR_MC0_COLOR COL_DK_GRAY  /* $D025 — bit-pair 01 (3rd-most in PNGs) */
#define SPR_MC1_COLOR COL_YELLOW  /* $D026 — bit-pair 11 (2nd-most in PNGs) */
// Per-kind individual colour (bit-pair 10 → $D027+n)
// A/B unique colour = remaining HP (3 blue / 2 green / 1 cyan). C fixed red.
#define SPR_COLOR_DRONE_C COL_RED  /* small / tiny (1 HP, no ladder) */
#define SPR_COLOR_HP3 COL_BLUE  /* 3 HP left (full A) */
#define SPR_COLOR_HP2 COL_GREEN  /* 2 HP left (full B or damaged A) */
#define SPR_COLOR_HP1 COL_CYAN  /* 1 HP left (last shot) */
#define SPR_COLOR_DRONE_B SPR_COLOR_HP2  /* spawn B at full HP */
#define SPR_COLOR_DRONE_A SPR_COLOR_HP3  /* spawn A at full HP */
// VIC sprite pointers for drone frames (order: left, right, up, down)
#define SPR_PTR_DRONE_C_LEFT 0xC0  /* $3000 */
#define SPR_PTR_DRONE_C_RIGHT 0xC1  /* $3040 */
#define SPR_PTR_DRONE_C_UP 0xC2  /* $3080 */
#define SPR_PTR_DRONE_C_DOWN 0xC3  /* $30C0 */
#define SPR_PTR_DRONE_B_LEFT 0xC4  /* $3100 */
#define SPR_PTR_DRONE_B_RIGHT 0xC5  /* $3140 */
#define SPR_PTR_DRONE_B_UP 0xC6  /* $3180 */
#define SPR_PTR_DRONE_B_DOWN 0xC7  /* $31C0 */
#define SPR_PTR_DRONE_A_LEFT 0xC8  /* $3200 */
#define SPR_PTR_DRONE_A_RIGHT 0xC9  /* $3240 */
#define SPR_PTR_DRONE_A_UP 0xCA  /* $3280 */
#define SPR_PTR_DRONE_A_DOWN 0xCB  /* $32C0 */
#define SPR_PTR_CARGO 0xCC  /* $3300 — hires disc (cargo only) */
#define SPR_PTR_ADD_SCORE 0xCD  /* $3340 — add_score.png (score parcel) */
#define SPR_PTR_ADD_REPAIR 0xCE  /* $3380 — add_repair.png (future) */
#define SPR_PTR_ADD_EXTRA 0xCF  /* $33C0 — add_extra.png (future life) */
#define SPR_PTR_ADD_CLEAR 0xD0  /* $3400 — add_clear.png (future cargo clear) */
#define SPR_PTR_ADD_2X 0xD1  /* $3440 — add_2x.png (future score ×2) */
#define SPR_PTR_EXPLODE_1 0xD2  /* $3480 — player death frame 1 */
#define SPR_PTR_EXPLODE_2 0xD3  /* $34C0 — player death frame 2 */
#define SPR_PTR_EXPLODE_3 0xD4  /* $3500 — player death frame 3 */
#define SPR_PTR_EXPLODE_DV_1 0xD5  /* vertical drone explode 1 */
#define SPR_PTR_EXPLODE_DV_2 0xD6
#define SPR_PTR_EXPLODE_DV_3 0xD7
#define SPR_PTR_EXPLODE_DH_1 0xD8  /* horizontal drone explode 1 */
#define SPR_PTR_EXPLODE_DH_2 0xD9
#define SPR_PTR_EXPLODE_DH_3 0xDA
// Live score parcel still uses SPR_PTR_PARCEL as the score pickup art
#define SPR_PTR_PARCEL SPR_PTR_ADD_SCORE
#define SPR_PTR_PLAYER_0 0xF8  /* $3E00 player buffer 0 */
#define SPR_PTR_PLAYER_1 0xF9  /* $3E40 player buffer 1 */
// Death sequence (player explode pattern 1-2-3-2-3-2-1, then hold).
#define DEATH_EXPLODE_FRAMES 3  /* distinct art frames */
#define DEATH_EXPLODE_STEPS 7  /* 1,2,3,2,3,2,1 */
#define DEATH_EXPLODE_HOLD 8  /* frames per step (~0.16s) */
#define DEATH_HOLD_PHASE 7  /* death_phase value during post-explode hold */
#define DEATH_HOLD_FRAMES 100  /* ~2s after explode sequence (player only) */
#define DEATH_GO_FLASH_FRAMES 12  /* ~0.25s @ 50Hz; light/dark ×2 over hold */
#define DEATH_GO_BANNER_LEN 9  /* "GAME OVER" */
#define DEATH_RIP_BANNER_LEN 10  /* "RIP  PILOT" */
#define SPR_COLOR_EXPLODE COL_RED
// obj_anim_state bit7 set while drone plays explode; low 2 bits = phase 0..2
#define DRONE_DYING_BIT 0x80
// Parcel / bonus types + unique colours (shared MC accent is yellow)
#define PARCEL_TYPE_POINTS 0  /* add_score — cheap points */
#define PARCEL_TYPE_SCORE2X 1  /* add_2x black — 2 points per hit */
#define PARCEL_TYPE_POWER2X 2  /* add_2x cyan — 2 HP per hit */
#define PARCEL_TYPE_CLEAR 3  /* add_clear brown — wipe GHIJ on next centre */
#define PARCEL_TYPE_EXTRA 4  /* add_extra green — +1 reserve */
#define PARCEL_TYPE_REPAIR 5  /* add_repair lt-gray — timed heal marks */
#define SPR_COLOR_PARCEL_SCORE COL_PURPLE
#define SPR_COLOR_PARCEL_SCORE2X COL_BLACK
#define SPR_COLOR_PARCEL_POWER2X COL_CYAN
#define SPR_COLOR_PARCEL_CLEAR COL_BROWN
#define SPR_COLOR_PARCEL_EXTRA COL_GREEN
#define SPR_COLOR_PARCEL_REPAIR COL_LT_GRAY
#define SPR_COLOR_CARGO COL_ORANGE
// Sticky policy flags (parcel_flags ZP) — not a deep queue
#define PARCEL_FLAG_CLEAR 0x01
#define PARCEL_FLAG_REPAIR 0x02
#define PARCEL_FLAG_EXTRA 0x04
#define PARCEL_FLAG_BLOCK_CLEAR 0x08  /* set after clear sent; cleared on next non-clear */
#define PARCEL_SPEED 1  /* half of prior 2; easy intercept */
// Soft collect AABB (sprite-relative pixels)
#define PARCEL_HIT_X0 6
#define PARCEL_HIT_X1 17
#define PARCEL_HIT_Y0 5
#define PARCEL_HIT_Y1 14
// Kill-progress drop marks (2 per *level*)
#define PARCEL_DROP_T1 0x01  /* ~1/3 of level debt */
#define PARCEL_DROP_T2 0x02  /* ~2/3 of level debt */
// Power/score 2× last until level banner ends (cleared in waves::load)
// Repair mark window then one-step heal on marked tiles
#define REPAIR_MARK_FRAMES 150  /* ~3s @ 50Hz (tune in R10) */
#define COL_RAIL COL_DK_GRAY
#define COL_RAIL_HEAL_MARK COL_LT_GRAY
// Direction index for future table lookups (matches left/right/up/down order)
#define SPR_DIR_LEFT 0
#define SPR_DIR_RIGHT 1
#define SPR_DIR_UP 2
#define SPR_DIR_DOWN 3
// Ignore fire for a few frames after entering a menu (held-button bleed)
#define MENU_FIRE_GUARD 20
// Story typewriter
#define STORY_MARGIN_X 1  /* left-justified inset */
#define STORY_START_Y 0
#define STORY_TYPE_DELAY 1  /* frames between glyphs (~50% faster than 2) */
#define STORY_STATE_TYPING 0
#define STORY_STATE_DONE 1
// Screen codes — text glyphs 0..63; UDG pack $40..$6F (see map below)
#define SC_SPACE 0x20  /* blank cell */
#define SC_STAR 0x2A  /* asterisk; the cargo stack no longer uses this */
#define SC_PLUS 0x2B  /* plus sign */
#define SC_DASH 0x2D  /* dash */
#define SC_ZERO 0x30  /* digit 0; digits are this code plus 0..9 */
#define SC_VBAR 0x5D  /* vertical bar (same screen code as the 6px HUD bar) */
#define SC_HASH 0x23  /* hash, the empty progress cell in the HUD template */
#define SC_LEFT_ARROW 0x1F  /* left arrow, the hiscore backspace glyph */
#define PET_LEFT_ARROW 0x5F  /* PETSCII source byte for the left arrow */
// Hiscore entry
#define HS_CHARSET_LEN 39  /* A–Z . 0–9 space ← */
#define HS_CHAR_BACK 38  /* index of ← in hs_charset */
#define HS_HOLD_FRAMES 50  /* ~1s @ 50Hz after 3rd initial */
#define HS_PROMPT_NAME_OFF 23  /* "ENTER YOUR NAME PILOT: " then name */
// Up/down auto-repeat (classic: long first delay, then steady scroll)
#define HS_REPEAT_DELAY 22  /* frames before first auto-step (~0.44s @ 50Hz) */
#define HS_REPEAT_RATE 5  /* frames between steps while held */
// ---------------------------------------------------------------------------
// UDG pack @ $40 (48 slots, full — life is last)
//   AAABBBCCCDDDEEEFFF GGHHIIJJ X PPPP 1111222233334444 life
//   A–F ×3 | G–J ×2 | B∩E cross | bars 2/4/6/8 | VL VR HT HB ×4 | life
//   Junction tile never damaged (no alts).
// ---------------------------------------------------------------------------
// A–F: full (healthy), dmg, critical
#define SC_RAIL_A 0x40  /* rail tile A, healthy */
#define SC_RAIL_A_DMG 0x41  /* rail tile A, damaged */
#define SC_RAIL_A_CRIT 0x42  /* rail tile A, critical */
#define SC_RAIL_B 0x43  /* rail tile B, healthy */
#define SC_RAIL_B_DMG 0x44  /* rail tile B, damaged */
#define SC_RAIL_B_CRIT 0x45  /* rail tile B, critical */
#define SC_RAIL_C 0x46  /* rail tile C, healthy */
#define SC_RAIL_C_DMG 0x47  /* rail tile C, damaged */
#define SC_RAIL_C_CRIT 0x48  /* rail tile C, critical */
#define SC_RAIL_D 0x49  /* rail tile D, healthy */
#define SC_RAIL_D_DMG 0x4A  /* rail tile D, damaged */
#define SC_RAIL_D_CRIT 0x4B  /* rail tile D, critical */
#define SC_RAIL_E 0x4C  /* rail tile E, healthy */
#define SC_RAIL_E_DMG 0x4D  /* rail tile E, damaged */
#define SC_RAIL_E_CRIT 0x4E  /* rail tile E, critical */
#define SC_RAIL_F 0x4F  /* rail tile F, healthy */
#define SC_RAIL_F_DMG 0x50  /* rail tile F, damaged */
#define SC_RAIL_F_CRIT 0x51  /* rail tile F, critical */
// G–J hubs: normal, mine
#define SC_RAIL_G 0x52  /* hub letter G, empty */
#define SC_RAIL_G_MINE 0x53  /* hub letter G, mine armed */
#define SC_RAIL_H 0x54  /* hub letter H, empty */
#define SC_RAIL_H_MINE 0x55  /* hub letter H, mine armed */
#define SC_RAIL_I 0x56  /* hub letter I, empty */
#define SC_RAIL_I_MINE 0x57  /* hub letter I, mine armed */
#define SC_RAIL_J 0x58  /* hub letter J, empty */
#define SC_RAIL_J_MINE 0x59  /* hub letter J, mine armed */
// B∩E centre cross (after second J, before bars)
#define SC_RAIL_X 0x5A  /* centre cross where the two rails meet */
#define SC_RAIL_FIRST SC_RAIL_A  /* first rail screen code (healthy A) */
#define SC_RAIL_LAST SC_RAIL_J  /* last hub letter (healthy J); the centre cross is the next code */
// Progress bar fill (order in atlas: 2, 4, 6, 8 px)
#define SC_UDG_BAR2 0x5B  /* HUD progress bar, 2px fill */
#define SC_UDG_BAR4 0x5C  /* HUD progress bar, 4px fill */
#define SC_UDG_BAR6 0x5D  /* HUD progress bar, 6px fill */
#define SC_UDG_BAR8 0x5E  /* HUD progress bar, 8px fill */
#define SC_UDG_BAR_FIRST SC_UDG_BAR2  /* first HUD bar glyph (2px) */
#define SC_UDG_BAR_COUNT 4  /* four HUD bar fills: 2, 4, 6 and 8 px */
// Bullets: left-vert, right-vert, top-horz, bot-horz
#define SC_BULLET_VL0 0x5F  /* bullet, vertical, left half of the cell, phase 0 */
#define SC_BULLET_VR0 0x63  /* bullet, vertical, right half of the cell, phase 0 */
#define SC_BULLET_HT0 0x67  /* bullet, horizontal, top half of the cell, phase 0 */
#define SC_BULLET_HB0 0x6B  /* bullet, horizontal, bottom half of the cell, phase 0 */
#define SC_BULLET_FIRST SC_BULLET_VL0  /* first bullet glyph (vertical, left half, phase 0) */
#define SC_BULLET_COUNT 16  /* sixteen bullet glyphs: 4 directions times 4 phases */
// Reserve life icon (HUD PILOTS) — last UDG
#define SC_UDG_LIFE 0x6F  /* reserve-life icon on the HUD pilots row */
#define SC_LETTER_A SC_UDG_LIFE  /* same glyph as the reserve-life icon; the HUD template paints AAAA */
#define SC_MINE SC_RAIL_G_MINE  /* mine glyph, same screen code as hub G armed */
// HUD: 000000   WAVE 01 ########    pilots AAAA  (40 columns)
// No dashes/colons. Progress bar immediately after wave digits.
// Banners (rank / death) clear only HUD_BANNER_COL .. HUD_BANNER_END-1 so
// score (0–5) and reserve pilot icons (36–39) stay visible.
#define HUD_ROW 0
#define HUD_SCORE_COL 0
#define HUD_SCORE_LEN 6
#define HUD_WAVE_LABEL_COL 9  /* "WAVE" */
#define HUD_LEVEL_COL 14  /* 2 digits (wave number) */
#define HUD_LEVEL_LEN 2
#define HUD_PROGRESS_COL 17  /* 8 bar cells full→empty (after "01 ") */
#define HUD_PROGRESS_LEN 8
#define HUD_PILOTS_LABEL_COL 29  /* "PILOTS" */
#define HUD_LIVES_COL 36
#define HUD_LIVES_MAX_SHOW 4
#define HUD_BANNER_COL 7  /* first col wiped for any top-line banner */
#define HUD_BANNER_END 36  /* exclusive end (lives icons start here) */
#define HUD_BANNER_ZONE_LEN (HUD_BANNER_END - HUD_BANNER_COL)  /* 29 */
// ---------------------------------------------------------------------------
// Bullets (character stream; V and H axes, 4px half-lanes)
// ---------------------------------------------------------------------------
#define BULLET_MAX 16
#define BULLET_HOLD 1
#define BULLET_PHASES 4
#define BULLET_CELL_TICKS (BULLET_HOLD * BULLET_PHASES)
// Vertical stream: half = X lane; horizontal: half = Y lane (same 0/1)
#define BULLET_HALF_LEFT 0
#define BULLET_HALF_RIGHT 1
#define BULLET_HALF_TOP 0
#define BULLET_HALF_BOT 1
// 3-row H-rail at rows 12–14; fire from adjacent cells
#define BULLET_RAIL_ROW_TOP 12
#define BULLET_RAIL_ROW_BOT 14
#define BULLET_LAUNCH_ROW_UP 11
#define BULLET_LAUNCH_ROW_DOWN 15
#define BULLET_ROW_MIN 1
// 3-col V-rail at cols 18–20; fire from adjacent cells
#define BULLET_LAUNCH_COL_LEFT 17
#define BULLET_LAUNCH_COL_RIGHT 21
#define BULLET_COL_MIN 0
#define BULLET_COL_MAX 39
// Gun Y offset for V-arm aim (sprite top → tip); keeps (y+off-50) on 4px grid
#define PLAYER_GUN_Y_OFF 10
#define BULLET_COLOR COL_YELLOW
// ---------------------------------------------------------------------------
// Playfield rail / quadrant geometry (0-based char cells; matches a–j map)
//   Vertical band: cols 18–20  (A B C)
//   H-rail: rows 12–14 (D/G/B/H, full E, F/I/B/J)
//   Left free: 0–17   Right free: 21–39
// ---------------------------------------------------------------------------
#define RAIL_COL_LEFT 18
#define RAIL_COL_MID 19
#define RAIL_COL_RIGHT 20  /* inclusive */
#define RAIL_ROW_TOP 12  /* D edge */
#define RAIL_ROW_MID 13  /* E solid */
#define RAIL_ROW_BOT 14  /* F edge */
#define QUAD_LEFT_COL_MAX 17
#define QUAD_RIGHT_COL_MIN 21
// 24px sprite fully left of col 18 / right of col 21
// Left: X+23 < 24+18*8=168 → X<=144.  Right: X >= 24+21*8=192
#define DRONE_X_LEFT_MIN 28
#define DRONE_X_LEFT_MAX 144
#define DRONE_X_RIGHT_MIN 192
#define DRONE_X_RIGHT_MAX 320
// ---------------------------------------------------------------------------
// Drones — launcher v2 (dice + kill targets + piggyback C)
// obj_user = DRONE_APPROACH_*
//
// Speed model (8.7):
//   1) Precomputed velocity tiers (drone_vel_tier): equal first-sight→rail
//      time across N/S/E/W, scaled by level (L1 calm … L10 peak).
//   2) Class max tier: C = level, B = level-1, A = level-2 (floor 1).
//   3) Each spawn picks a tier ≤ class max; geometric step-down from max so
//      near-max is common and far-slow is rare at high levels.
//   Distances: DOWN 103, UP 89, RIGHT 160, LEFT 168; T≈140 at L1.
// ---------------------------------------------------------------------------
#define DRONE_HP_C 1
#define DRONE_HP_B 2
#define DRONE_HP_A 3
// Class max-tier offsets below current level cap (C uses full cap)
#define DRONE_TIER_OFF_C 0
#define DRONE_TIER_OFF_B 1
#define DRONE_TIER_OFF_A 2
// Approach
#define DRONE_APPROACH_DOWN 0  /* from top → H-rail */
#define DRONE_APPROACH_UP 1  /* from bottom → H-rail */
#define DRONE_APPROACH_RIGHT 2  /* from left → V-rail */
#define DRONE_APPROACH_LEFT 3  /* from right → V-rail */
// Off-screen spawn Y (mux-safe)
#define DRONE_SPAWN_Y_FROM_TOP 37  /* assembly aliases MUX_MIN_SPRITE_Y; the mux is not ported */
#define DRONE_SPAWN_Y_FROM_BOT (262 - SPRITE_H_PX)  /* 241 */
#define DRONE_SPAWN_Y DRONE_SPAWN_Y_FROM_TOP
// Off-screen spawn X
#define DRONE_SPAWN_X_EDGE_L_LO 0
#define DRONE_SPAWN_X_EDGE_L_HI 0
#define DRONE_SPAWN_X_EDGE_R_LO 0x58  /* 344 */
#define DRONE_SPAWN_X_EDGE_R_HI 1
// In-quadrant coordinate bands (on-screen for the free axis)
// Left half X for vertical approach (Q3/Q4)
#define DRONE_BAND_X_L0 40
#define DRONE_BAND_X_L1 140
// Right half X (Q1/Q2) — stay in 8-bit X for simple dice (MSB spawn separate)
#define DRONE_BAND_X_R0 196
#define DRONE_BAND_X_R1 255
// Upper half Y for horizontal approach (Q1/Q4)
#define DRONE_BAND_Y_T0 70
#define DRONE_BAND_Y_T1 120
// Lower half Y (Q2/Q3)
#define DRONE_BAND_Y_B0 170
#define DRONE_BAND_Y_B1 220
// Legacy B spawn X (ensure_rail_attacker)
#define DRONE_B_SPAWN_X_LO 220
#define DRONE_B_SPAWN_X_HI 0
// Rail arrival
#define DRONE_RAIL_ARRIVE_Y 140
#define DRONE_RAIL_ARRIVE_Y_UP 152
#define DRONE_RAIL_ARRIVE_X_R 160
#define DRONE_RAIL_ARRIVE_X_L 176
#define DRONE_IMPACT_Y_OFF 4
#define QUAD_UL 0
#define QUAD_UR 1
#define QUAD_LL 2
#define QUAD_LR 3

/* COLLISION_MODE above is what the PRG builds. The port does not branch
 * on it: test_bullets and test_rail run every logic tick. */

/* Collision box inside a drone sprite. From game/collision.asm.
 * The port runs this test every tick; it does not read the VIC latch. */
#define HIT_X0 0   /* sprite-local left of the hit box */
#define HIT_X1 23  /* sprite-local right */
#define HIT_Y0 3   /* sprite-local top */
#define HIT_Y1 16  /* sprite-local bottom */

/* High-score line layout. From data/strings.asm. */
#define HS_INITIALS_OFF 4
#define HS_WAVE_OFF 11     /* centred in the WAVE field (cols 10..13) */
#define HS_RANK_OFF 15     /* 7-char military rank title */
#define HS_RANK_LEN 7
#define HS_SHOTS_OFF 24
#define HS_SCORE_OFF 31
#define HS_LINE_LEN 37
#define HS_ROW_HEROES 2
#define HS_ROW_HEAD 4      /* blank row 3 under the heroes heading */
#define HS_ROW_SCORE0 5    /* scores occupy rows 5..14 */
#define HS_ROW_NEW 17      /* YOU HAVE A NEW HIGH SCORE */
#define HS_ROW_PROMPT 19   /* ENTER YOUR NAME PILOT: xxx */
#define HS_ROW_HELP 24     /* bottom line */
#define HS_ROW_CONGRATS 0  /* same row as the title */
#define HS_COL_TABLE 1     /* 37-char lines centred */
#define HS_COL_HEROES 14
#define HS_COL_CONGRATS 9  /* 22 chars */
#define HS_COL_NEW 8       /* 24 chars */
#define HS_COL_PROMPT 7    /* 26 chars */
#define HS_COL_HELP 3      /* 34 chars */

/* Four spawn rows inside a level. The assembly names this only in a comment. */
#define WAVES_PER_LEVEL 4

/* Installed sprite block is 27 frames of 64 bytes. Player facings are separate. */
#define SPR_FRAME_BYTES 64
#define SPR_FRAMES_SRC_COUNT 27

/* Title voices: pulse, pulse, triangle. Pulse width is $0800 (~50%).
 * AD/SR live in music_ad / music_sr. Hz = word * 985248 / 16777216. */
#define MUSIC_VOICES 3
#define MUSIC_PULSE_WIDTH 0x0800
#define MUSIC_EVENT_LEN 3

/* 7-byte SFX step: freq_lo, freq_hi, wave, ad, sr, gate_frames, gap_frames.
 * wave == 0 ends the effect. */
#define SFX_STEP_LEN 7

#endif

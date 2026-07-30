; Hardware and game constants (shared).
; Included early from main.asm — assignments only, no code emit.

; ---------------------------------------------------------------------------
; VIC / CIA / memory map
; ---------------------------------------------------------------------------
SCREEN_RAM      = $0400
COLOR_RAM       = $D800
VIC_BORDER      = $D020
VIC_BG0         = $D021
VIC_CTRL1       = $D011
VIC_CTRL2       = $D016
VIC_MEM         = $D018
VIC_SPR_X_MSB   = $D010
VIC_SPR_ENABLE  = $D015
VIC_SPR_Y_EXPAND = $D017
VIC_IRQ_STATUS  = $D019
VIC_IRQ_ENABLE  = $D01A
VIC_SPR_BG_PRIORITY = $D01B
VIC_SPR_MULTICOLOR = $D01C
VIC_SPR_X_EXPAND = $D01D
VIC_SPR_SPR_COLL = $D01E
VIC_SPR_BG_COLL = $D01F
VIC_RASTER      = $D012
VIC_SPR_MC0     = $D025
VIC_SPR_MC1     = $D026
VIC_SPR_COLOR0  = $D027
CIA1_PRA        = $DC00             ; joy port 2 / keyboard columns
CIA1_PRB        = $DC01             ; joy port 1 / keyboard rows
CIA1_DDRA       = $DC02
CIA1_DDRB       = $DC03
CIA1_ICR        = $DC0D
CIA2_PRA        = $DD00             ; VIC bank select (bits 0–1 inverted)
CIA2_ICR        = $DD0D
IRQ_VECTOR_LO   = $0314
IRQ_VECTOR_HI   = $0315
KERNAL_IRQ_EXIT = $EA81
SPRITE_PTR_BASE = SCREEN_RAM + $03F8

; SID (MOS 6581/8580) — voice stride 7; filter/volume at $D415–$D418
SID_V1_FL       = $D400
SID_V1_FH       = $D401
SID_V1_PWL      = $D402
SID_V1_PWH      = $D403
SID_V1_CTRL     = $D404
SID_V1_AD       = $D405
SID_V1_SR       = $D406
SID_V2_FL       = $D407
SID_V2_FH       = $D408
SID_V2_PWL      = $D409
SID_V2_PWH      = $D40A
SID_V2_CTRL     = $D40B
SID_V2_AD       = $D40C
SID_V2_SR       = $D40D
SID_V3_FL       = $D40E
SID_V3_FH       = $D40F
SID_V3_PWL      = $D410
SID_V3_PWH      = $D411
SID_V3_CTRL     = $D412
SID_V3_AD       = $D413
SID_V3_SR       = $D414
SID_FC_LO       = $D415
SID_FC_HI       = $D416
SID_RES_FILT    = $D417
SID_MODE_VOL    = $D418
SID_VOICE_STRIDE = 7
SID_WAVE_TRI    = $10
SID_WAVE_SAW    = $20
SID_WAVE_PULSE  = $40
SID_WAVE_NOISE  = $80
SID_GATE        = $01
SID_VOL_MAX     = $0F               ; no filter mode bits

; One-shot SFX ids — also priority (lower number = higher priority).
; No continuous gun fire / spindown (by design).
SFX_UI_FIRE     = 0                 ; menu FIRE acknowledge (soft thump)
SFX_HS_TICK     = 1                 ; high-score initial scroll tick
SFX_WAVE        = 2                 ; wave / level start whoop×3
SFX_MINE        = 3                 ; cargo hubs arm → mine clink
SFX_PARCEL      = 4                 ; bonus parcel launched swoosh
SFX_PLAYER_DIE  = 5                 ; player explode rumble (noise)
SFX_EXTRA       = 6                 ; extra life parcel collect cha-ching
SFX_HEAL        = 7                 ; rail heal swish
SFX_DRONE_DIE   = 8                 ; drone explode pop
SFX_PING        = 9                 ; non-extra parcel collect (friendly ping)
SFX_COUNT       = 10
SFX_FREE        = $FF               ; voice idle marker

; VIC defaults / modes
VIC_DEN         = %00010000         ; $D011 bit 4 — display enable
VIC_DEN_MASK    = %11101111         ; AND mask to clear DEN (avoid unary ~ width)
VIC_CTRL1_TEXT  = $1b               ; text, DEN, 25 rows, yscroll 3
VIC_CTRL1_BITMAP = $3b              ; bitmap (BMM), DEN, 25 rows, yscroll 3
; Same as above with DEN clear (mode switch while blanked)
VIC_CTRL1_TEXT_BLANK   = VIC_CTRL1_TEXT & VIC_DEN_MASK
VIC_CTRL1_BITMAP_BLANK = VIC_CTRL1_BITMAP & VIC_DEN_MASK
VIC_CTRL2_HIRES = $08               ; 40 cols, multicolour off
VIC_MEM_TEXT    = $14               ; screen $0400, charset ROM $1000 (unused after boot)
; Text + RAM charset @ $2800 (bank 0, segment CHARSET). CODE must end before $2800.
; $D018: screen $0400 (bits7-4=1), charset $2800 (bits3-1=5) → $1A
VIC_MEM_TEXT_RAM = $1A
BITMAP_SIZE     = 8000              ; 320×200 / 8
BITMAP_COLOR_SIZE = 1000            ; 40×25 colour matrix

; VIC bank select in CIA2_PRA bits 0–1 (inverted: %11=bank0 … %00=bank3)
VIC_BANK0_BITS  = %00000011         ; $0000–$3FFF
VIC_BANK3_BITS  = %00000000         ; $C000–$FFFF

; Title hires — parked once under KERNAL (VIC bank 3). Fire-and-forget.
; Matrix $CC00 (avoids object pool $C000–$C8FF). Bitmap $E000–$FF3F.
TITLE_MATRIX_RAM = $CC00
TITLE_BITMAP_RAM = $E000
; $D018 in bank 3: matrix offset $0C00 → 3, bitmap +$2000 → bit3
VIC_MEM_TITLE   = $38

; ---------------------------------------------------------------------------
; Character set (VIC bank 0) — install once at cold init; all text uses this.
; $2800–$2FFF: after CODE (~$20E8), before SPRITE_BLOCK $3000.
; ---------------------------------------------------------------------------
CHARSET_RAM     = $2800             ; segment CHARSET — PRG-resident font
CHARSET_SIZE    = 2048              ; 256 glyphs × 8 bytes
SPRITE_H_PX             = 21        ; VIC sprite height (lines)

; Joystick port 2 bits (active low on PRA)
JOY_UP          = %00000001
JOY_DOWN        = %00000010
JOY_LEFT        = %00000100
JOY_RIGHT       = %00001000
JOY_FIRE        = %00010000

; Keyboard matrix (CIA1): write select on PRA ($DC00), read on PRB ($DC01).
; On the C64 / c64m, PRA selects the matrix "row" index and PRB returns
; "column" bits (active-low). Key positions match c64m keyboard.c {row,col}:
;   key   row  col   → PRA clear bit   PRB test bit
;   W      1    1
;   A      1    2
;   S      1    5
;   D      2    2
;   Space  7    4      ($7F / $10 — classic "space bar" test)
KEY_SEL_W       = %11111101         ; ~(1<<1)
KEY_BIT_W       = %00000010         ;  (1<<1)
KEY_SEL_A       = %11111101         ; ~(1<<1)
KEY_BIT_A       = %00000100         ;  (1<<2)
KEY_SEL_S       = %11111101         ; ~(1<<1)
KEY_BIT_S       = %00100000         ;  (1<<5)
KEY_SEL_D       = %11111011         ; ~(1<<2)
KEY_BIT_D       = %00000100         ;  (1<<2)
KEY_SEL_SPACE   = %01111111         ; ~(1<<7)
KEY_BIT_SPACE   = %00010000         ;  (1<<4)
; I key (c64m keyboard.c {row,col} = {4,1})
KEY_SEL_I       = %11101111         ; ~(1<<4)
KEY_BIT_I       = %00000010         ;  (1<<1)
; S is KEY_SEL_S / KEY_BIT_S above (also used as joy-down)
; RUN/STOP (c64m keyboard.c {row,col} = {7,7}) — same matrix row as Space
KEY_SEL_RUNSTOP = %01111111         ; ~(1<<7)
KEY_BIT_RUNSTOP = %10000000         ;  (1<<7)

; Screen geometry
SCREEN_W        = 40
SCREEN_H        = 25
SCREEN_SIZE     = 1000              ; 40 * 25

; Default text colours (VIC colour nybbles)
COL_BLACK       = $00
COL_WHITE       = $01
COL_RED         = $02
COL_CYAN        = $03
COL_PURPLE      = $04
COL_GREEN       = $05
COL_BLUE        = $06
COL_YELLOW      = $07
COL_ORANGE      = $08
COL_BROWN       = $09
COL_LT_RED      = $0A
COL_DK_GRAY     = $0B
COL_GRAY        = $0C
COL_LT_GREEN    = $0D
COL_LT_BLUE     = $0E
COL_LT_GRAY     = $0F

; ---------------------------------------------------------------------------
; Game mode IDs (game_mode ZP)
; ---------------------------------------------------------------------------
MODE_TITLE_GFX  = 0                 ; hires art attract page
MODE_GAME_INIT  = 1
MODE_STAGE_INIT = 2
MODE_PLAY       = 3
MODE_NEXT_WAVE  = 4
MODE_NEXT_LEVEL = 5
MODE_NEXT_LIFE  = 6
MODE_GAME_OVER  = 7
MODE_HISCORE    = 8
MODE_TITLE_TEXT = 9                 ; text menu + high scores (primary frontend)
MODE_STORY      = 10                ; placeholder
MODE_INSTRUCTIONS = 11              ; placeholder
MODE_COUNT      = 12

; Alias: cold-start / return-from-game frontend entry
MODE_TITLE      = MODE_TITLE_TEXT

; ---------------------------------------------------------------------------
; Session defaults (roadmap placeholders)
; ---------------------------------------------------------------------------
; lives ZP = reserve ships on HUD (not the ship on the board).
; New game: START_LIVES icons shown, then deploy peels one → START_LIVES-1 reserve.
START_LIVES     = 3                 ; pre-deploy HUD count
MAX_RESERVE_LIVES = 4               ; hard cap on reserve (extra life)
DEPLOY_HOLD_FRAMES = 45             ; ~0.9s @ 50Hz: show reserves, then peel
START_LEVEL     = 1
MAX_LEVEL       = 15
EXTRA_KILL_EVERY = 100              ; session kills → extra_due (mod counter)
; Rank banner: was 50 (~1s); 50% longer + clean 10-colour wheel (high-score palette)
LEVEL_BANNER_FRAMES = 75            ; ~1.5s (PAL 50Hz)
BANNER_NUM_COLORS   = 10            ; score_color_table length
BANNER_COLOR_HOLD   = 7             ; LEVEL_BANNER_FRAMES / BANNER_NUM_COLORS (int)
BANNER_PAD_SPACES   = 2             ; leading+trailing spaces when room
LEVEL_BAR_CELLS     = 8
LEVEL_BAR_STEPS     = 32            ; 8 cells × 4 UDG steps

; Spawn quadrants / flags (level-driven; no player-facing waves)
WAVE_Q1         = %00000001
WAVE_Q2         = %00000010
WAVE_Q3         = %00000100
WAVE_Q4         = %00001000
WAVE_Q_TOP      = WAVE_Q1 | WAVE_Q4
WAVE_Q_ALL      = WAVE_Q1 | WAVE_Q2 | WAVE_Q3 | WAVE_Q4
WAVE_F_PIGGY_C  = %00000001
WAVE_F_MAIN_C   = %00000010
WAVE_AB_MAX     = 1
WAVE_PIGGY_MIN  = 6
WAVE_PIGGY_SPAN = 36
WAVE_CD_MIN_FLOOR = 12
WAVE_CD_SPAN_MIN  = 10
WAVE_MAX_ACTIVE_CAP = 10

; C cargo (orange parcel sprite) → GHIJ hub stacks. K per tile to arm;
; default K=1 → 4 landings arm mines; centre pass while armed → death.
CARGO_SPEED       = 2               ; px/frame toward assigned G/H/I/J
MINE_STACK_K      = 1
; Sprite top-left so parcel disc centres on GHIJ char cells (see cargo.asm)
CARGO_TGT_X0      = 160             ; G col18
CARGO_TGT_X1      = 176             ; H col20
CARGO_TGT_Y0      = 140             ; rows 12 (G/H)
CARGO_TGT_Y1      = 156             ; rows 14 (I/J)

; Pixel inset for drone→col (matches rail::apply_ab_hit body align)
DRONE_IMPACT_X_OFF = 4

; Rail toughness (damage *taken* 0..HP; glyph mapped separately).
; Light/medium/heavy strikes = 1/2/3 (remaining drone HP). Tune here for fun.
RAIL_OUTER_HP     = 6               ; D/F/A/C full → destroyed
RAIL_CORE_HP      = 5               ; E/B full → game over at this damage

; Score: 1 registered hit = 1 point (not 1 bullet). Cap for 6-digit HUD.
; A/B/C kill totals = hit points (3/2/1) once multi-HP is live.
SCORE_HIT_POINTS = 1
SCORE_MAX0       = $3F              ; 999999 = $0F423F (lo, mid, hi)
SCORE_MAX1       = $42
SCORE_MAX2       = $0F

; ---------------------------------------------------------------------------
; Player (full cross — Step 8.1+)
; VIC sprite top-left. Char col C left edge ≈ 24+C*8.
; Gun aim X = sprite_x + PLAYER_GUN_X_OFF (centre of 24px sprite).
; 4px steps on a grid so aim hits left 2px or right 2px of a char cell:
;   (sprite_x + GUN_OFF - 24) mod 8 ∈ {0, 4}  →  OO...... / ....OO..
; ---------------------------------------------------------------------------
PLAYER_MOVE_STEP        = 4
PLAYER_SWING_MID_FRAMES = 5
; H-rail mid (layout): sit on the E row band.
PLAYER_Y_HRAIL          = 146
; V-rail centerline X (4px grid; gun ≈ col 19). In H centre gap for mount.
PLAYER_X_VRAIL          = 169
; Aim X = sprite_x + GUN_OFF. One coordinate for move, clamp, fire, and draw.
; GUN_OFF 11: barrel tip (~px 10–11) meets half-cell bullet lanes on the 4px grid.
PLAYER_GUN_X_OFF        = 11
;
; H-rail stops (4px grid from X_MIN). Centre gap (LEFT_MAX, RIGHT_MIN) is the
; intersection in X — walk-through on H, mount zone for V.
PLAYER_X_MIN            = 13
PLAYER_X_MAX            = 329
PLAYER_ARM_LEFT_MAX     = 153
PLAYER_ARM_RIGHT_MIN    = 181
PLAYER_X_START          = 153
PLAYER_GAP_MID          = 167
; V-rail stops (4px grid ≡ 2 mod 4, matching Y_HRAIL). Centre gap in Y.
PLAYER_Y_MIN            = 58
PLAYER_Y_MAX            = 234
PLAYER_ARM_TOP_MAX      = 130
PLAYER_ARM_BOT_MIN      = 162
; player_rail
PLAYER_RAIL_H           = 0
PLAYER_RAIL_V           = 1
; player_move_dir values
PLAYER_DIR_NONE         = 0
PLAYER_DIR_RIGHT        = 1
PLAYER_DIR_LEFT         = 2
PLAYER_DIR_UP           = 3
PLAYER_DIR_DOWN         = 4
SPR_COLOR_PLAYER        = COL_PURPLE

; Attract loop: text ↔ graphics (PAL 50Hz × 15s)
ATTRACT_SECONDS = 15
ATTRACT_HZ      = 50
ATTRACT_FRAMES  = ATTRACT_SECONDS * ATTRACT_HZ   ; 750

; Score-row colour wheel step (frames per shift; ~5 Hz on PAL)
SCORE_COLOR_PERIOD = 10

; ---------------------------------------------------------------------------
; Video cadence
; ---------------------------------------------------------------------------
VIDEO_PAL       = 0
VIDEO_NTSC      = 1
LOGIC_HZ        = 50
PAL_DISPLAY_HZ  = 50
NTSC_DISPLAY_HZ = 60

; ---------------------------------------------------------------------------
; Graphical-object pool
; ---------------------------------------------------------------------------
OBJECT_CAPACITY = 24
OBJECT_LAST     = OBJECT_CAPACITY - 1
OBJECT_FREE_CAPACITY = OBJECT_CAPACITY - 1
OBJECT_NONE     = $FF

OBJ_PLAYER      = 0
OBJ_DRONE_A     = 1                ; large, back
OBJ_DRONE_B     = 2                ; medium
OBJ_DRONE_C     = 3                ; small, front
OBJ_BONUS       = 4
OBJ_EFFECT      = 5

OBJF_ALLOCATED  = %00000001
OBJF_RENDER     = %00000010
OBJF_RETIRING   = %00000100
OBJF_BG_INTEREST = %00001000
OBJF_SS_INTEREST = %00010000

OBJA_MULTICOLOR = %00000001
OBJA_X_EXPAND   = %00000010
OBJA_Y_EXPAND   = %00000100
OBJA_BEHIND_BG  = %00001000

OBJE_BG         = %00000001
OBJE_SS         = %00000010

; Collision dogfood modes (see game/collision.asm):
;   0 = HW latch only ($D01F / OBJE_BG) — trust mux attribution
;   1 = hybrid (latch filter + software authority + mismatch borders)
;   2 = software always (ignore latch)
COLLISION_MODE = 0

OBJ_ERR_POOL_FULL   = 1
OBJ_ERR_PLAYER_FIXED = 2

; ---------------------------------------------------------------------------
; Sprite frames after sprite_frames_install → $3000 (64-byte stride)
; Source: DATA segment (src/data/sprites.asm). Pointer = address / 64.
; ---------------------------------------------------------------------------
; Shared multicolour pair (all MC sprites; set once per stage / cold init)
SPR_MC0_COLOR   = COL_DK_GRAY       ; $D025 — bit-pair 01 (3rd-most in PNGs)
SPR_MC1_COLOR   = COL_YELLOW        ; $D026 — bit-pair 11 (2nd-most in PNGs)

; Per-kind individual colour (bit-pair 10 → $D027+n)
; A/B unique colour = remaining HP (3 blue / 2 green / 1 cyan). C fixed red.
SPR_COLOR_DRONE_C = COL_RED         ; small / tiny (1 HP, no ladder)
SPR_COLOR_HP3     = COL_BLUE        ; 3 HP left (full A)
SPR_COLOR_HP2     = COL_GREEN       ; 2 HP left (full B or damaged A)
SPR_COLOR_HP1     = COL_CYAN        ; 1 HP left (last shot)
SPR_COLOR_DRONE_B = SPR_COLOR_HP2   ; spawn B at full HP
SPR_COLOR_DRONE_A = SPR_COLOR_HP3   ; spawn A at full HP

; VIC sprite pointers for drone frames (order: left, right, up, down)
SPR_PTR_DRONE_C_LEFT  = $C0         ; $3000
SPR_PTR_DRONE_C_RIGHT = $C1         ; $3040
SPR_PTR_DRONE_C_UP    = $C2         ; $3080
SPR_PTR_DRONE_C_DOWN  = $C3         ; $30C0
SPR_PTR_DRONE_B_LEFT  = $C4         ; $3100
SPR_PTR_DRONE_B_RIGHT = $C5         ; $3140
SPR_PTR_DRONE_B_UP    = $C6         ; $3180
SPR_PTR_DRONE_B_DOWN  = $C7         ; $31C0
SPR_PTR_DRONE_A_LEFT  = $C8         ; $3200
SPR_PTR_DRONE_A_RIGHT = $C9         ; $3240
SPR_PTR_DRONE_A_UP    = $CA         ; $3280
SPR_PTR_DRONE_A_DOWN  = $CB         ; $32C0
SPR_PTR_CARGO         = $CC         ; $3300 — hires disc (cargo only)
SPR_PTR_ADD_SCORE     = $CD         ; $3340 — add_score.png (score parcel)
SPR_PTR_ADD_REPAIR    = $CE         ; $3380 — add_repair.png (future)
SPR_PTR_ADD_EXTRA     = $CF         ; $33C0 — add_extra.png (future life)
SPR_PTR_ADD_CLEAR     = $D0         ; $3400 — add_clear.png (future cargo clear)
SPR_PTR_ADD_2X        = $D1         ; $3440 — add_2x.png (future score ×2)
SPR_PTR_EXPLODE_1     = $D2         ; $3480 — player death frame 1
SPR_PTR_EXPLODE_2     = $D3         ; $34C0 — player death frame 2
SPR_PTR_EXPLODE_3     = $D4         ; $3500 — player death frame 3
SPR_PTR_EXPLODE_DV_1  = $D5         ; vertical drone explode 1
SPR_PTR_EXPLODE_DV_2  = $D6
SPR_PTR_EXPLODE_DV_3  = $D7
SPR_PTR_EXPLODE_DH_1  = $D8         ; horizontal drone explode 1
SPR_PTR_EXPLODE_DH_2  = $D9
SPR_PTR_EXPLODE_DH_3  = $DA
; Live score parcel still uses SPR_PTR_PARCEL as the score pickup art
SPR_PTR_PARCEL        = SPR_PTR_ADD_SCORE

SPR_PTR_PLAYER_0      = $F8         ; $3E00 player buffer 0
SPR_PTR_PLAYER_1      = $F9         ; $3E40 player buffer 1

; Death sequence (player explode pattern 1-2-3-2-3-2-1, then hold).
DEATH_EXPLODE_FRAMES  = 3           ; distinct art frames
DEATH_EXPLODE_STEPS   = 7           ; 1,2,3,2,3,2,1
DEATH_EXPLODE_HOLD    = 8           ; frames per step (~0.16s)
DEATH_HOLD_PHASE      = 7           ; death_phase value during post-explode hold
DEATH_HOLD_FRAMES     = 100         ; ~2s after explode sequence (player only)
DEATH_GO_FLASH_FRAMES = 12          ; ~0.25s @ 50Hz; light/dark ×2 over hold
DEATH_BANNER_COL      = 11          ; both banners start here
DEATH_GO_BANNER_LEN   = 17          ; "    GAME OVER    "
DEATH_RIP_BANNER_LEN  = 18          ; "    RIP  PILOT    "
SPR_COLOR_EXPLODE     = COL_RED
; obj_anim_state bit7 set while drone plays explode; low 2 bits = phase 0..2
DRONE_DYING_BIT       = $80

; Parcel / bonus types + unique colours (shared MC accent is yellow)
PARCEL_TYPE_POINTS     = 0          ; add_score — cheap points
PARCEL_TYPE_SCORE2X    = 1          ; add_2x black — 2 points per hit
PARCEL_TYPE_POWER2X    = 2          ; add_2x cyan — 2 HP per hit
PARCEL_TYPE_CLEAR      = 3          ; add_clear brown — wipe GHIJ on next centre
PARCEL_TYPE_EXTRA      = 4          ; add_extra green — +1 reserve
PARCEL_TYPE_REPAIR     = 5          ; add_repair lt-gray — timed heal marks

SPR_COLOR_PARCEL_SCORE   = COL_PURPLE
SPR_COLOR_PARCEL_SCORE2X = COL_BLACK
SPR_COLOR_PARCEL_POWER2X = COL_CYAN
SPR_COLOR_PARCEL_CLEAR   = COL_BROWN
SPR_COLOR_PARCEL_EXTRA   = COL_GREEN
SPR_COLOR_PARCEL_REPAIR  = COL_LT_GRAY
SPR_COLOR_CARGO          = COL_ORANGE

; Sticky policy flags (parcel_flags ZP) — not a deep queue
PARCEL_FLAG_CLEAR       = %00000001
PARCEL_FLAG_REPAIR      = %00000010
PARCEL_FLAG_EXTRA       = %00000100
PARCEL_FLAG_BLOCK_CLEAR = %00001000 ; set after clear sent; cleared on next non-clear

PARCEL_SPEED           = 1          ; half of prior 2; easy intercept
; Soft collect AABB (sprite-relative pixels)
PARCEL_HIT_X0          = 6
PARCEL_HIT_X1          = 17
PARCEL_HIT_Y0          = 5
PARCEL_HIT_Y1          = 14
; Kill-progress drop marks (2 per *level*)
PARCEL_DROP_T1         = %00000001  ; ~1/3 of level debt
PARCEL_DROP_T2         = %00000010  ; ~2/3 of level debt
; Power/score 2× last until level banner ends (cleared in waves::load)
; Repair mark window then one-step heal on marked tiles
REPAIR_MARK_FRAMES     = 150        ; ~3s @ 50Hz (tune in R10)
COL_RAIL               = COL_DK_GRAY
COL_RAIL_HEAL_MARK     = COL_LT_GRAY

; Direction index for future table lookups (matches left/right/up/down order)
SPR_DIR_LEFT    = 0
SPR_DIR_RIGHT   = 1
SPR_DIR_UP      = 2
SPR_DIR_DOWN    = 3

; ---------------------------------------------------------------------------
; Sprite mux
; ---------------------------------------------------------------------------
MUX_HW_COUNT        = 8
MUX_MAX_COMMANDS    = OBJECT_CAPACITY
MUX_FRAME_IRQ_LINES = 28
MUX_FIRST_JOB_LINE  = 28
MUX_JOB_LINES       = 9
MUX_POST_GUARD      = 1
; Same-lane reuse needs prev_bottom+2 <= next_top-JOB_LINES, i.e. gap of
; JOB_LINES+POST_GUARD+1 beyond display separation. Lane assign must forbid
; the lane in that dead zone or build dies with RASTER_DEADLINE.
MUX_LANE_SEP        = MUX_JOB_LINES + MUX_POST_GUARD + 1   ; 11
; Earliest Y that can meet first-job deadline (line 28): top - JOB_LINES >= 28
MUX_MIN_SPRITE_Y    = MUX_FIRST_JOB_LINE + MUX_JOB_LINES   ; 37

MUX_OK                  = 0
MUX_ERR_TOO_MANY_VISIBLE = 1
MUX_ERR_LANE_CAPACITY   = 2
MUX_ERR_PRIORITY        = 3
MUX_ERR_RASTER_DEADLINE = 4
MUX_ERR_COMMAND_CAPACITY = 5
MUX_ERR_PLAN_BUSY       = 6
MUX_ERR_BAD_COORDINATE  = 7

; Coop phase profiler. Code writes these IDs to objects::profile_marker; the
; c64m flight recorder supplies the cycle timestamp for every write.
PROFILE_MAIN_WAIT        = $01
PROFILE_MAIN_DRAIN       = $02
PROFILE_MAIN_REAP        = $03
PROFILE_MAIN_INPUT       = $04
PROFILE_MAIN_MODE        = $05
PROFILE_MAIN_BUILD_CHECK = $06
PROFILE_MAIN_PUBLISH     = $07
PROFILE_MAIN_BUILD_FAIL  = $08

PROFILE_PLAY_PLAYER      = $20
PROFILE_PLAY_DRONES      = $21
PROFILE_PLAY_CARGO       = $22
PROFILE_PLAY_PARCELS     = $23
PROFILE_PLAY_BULLETS     = $24
PROFILE_PLAY_COLLISION   = $25
PROFILE_PLAY_WAVE_BANNER = $26
PROFILE_PLAY_WAVE_CLEAR  = $27
PROFILE_PLAY_SCORE       = $28
PROFILE_PLAY_HUD         = $29
PROFILE_PLAY_MODE_SET    = $2A
PROFILE_PLAY_DONE        = $2B

PROFILE_MUX_GATE         = $40
PROFILE_MUX_GATHER       = $41
PROFILE_MUX_SORT         = $42
PROFILE_MUX_ASSIGN       = $43
PROFILE_MUX_Y_ORDER      = $44
PROFILE_MUX_WINDOWS      = $45
PROFILE_MUX_EMIT         = $46
PROFILE_MUX_FINISH       = $47
PROFILE_MUX_BUSY         = $48
PROFILE_MUX_FAIL         = $49

PROFILE_IRQ_ENTER        = $E0
PROFILE_IRQ_FRAME        = $E1
PROFILE_IRQ_COMMAND      = $E2
PROFILE_IRQ_EXIT         = $EF

; Ignore fire for a few frames after entering a menu (held-button bleed)
MENU_FIRE_GUARD = 20

; Story typewriter
STORY_MARGIN_X  = 1                 ; left-justified inset
STORY_START_Y   = 0
STORY_TYPE_DELAY = 1                ; frames between glyphs (~50% faster than 2)
STORY_STATE_TYPING = 0
STORY_STATE_DONE   = 1

; Screen codes — text glyphs 0..63; UDG pack $40..$6F (see map below)
SC_SPACE        = $20
SC_STAR         = $2A               ; legacy; cargo stack no longer uses this
SC_PLUS         = $2B
SC_DASH         = $2D
SC_ZERO         = $30
SC_VBAR         = $5D
SC_HASH         = $23
SC_LEFT_ARROW   = $1F               ; ← (Z+5); hiscore backspace glyph
PET_LEFT_ARROW  = $5F               ; PETSCII/source byte for ← in strings

; Hiscore entry
HS_CHARSET_LEN  = 39                ; A–Z . 0–9 space ←
HS_CHAR_BACK    = 38                ; index of ← in hs_charset
HS_HOLD_FRAMES  = 50                ; ~1s @ 50Hz after 3rd initial
HS_PROMPT_NAME_OFF = 23             ; "ENTER YOUR NAME PILOT: " then name
; Up/down auto-repeat (classic: long first delay, then steady scroll)
HS_REPEAT_DELAY = 22                ; frames before first auto-step (~0.44s @ 50Hz)
HS_REPEAT_RATE  = 5                 ; frames between steps while held

; ---------------------------------------------------------------------------
; UDG pack @ $40 (48 slots, full — life is last)
;   AAABBBCCCDDDEEEFFF GGHHIIJJ X PPPP 1111222233334444 life
;   A–F ×3 | G–J ×2 | B∩E cross | bars 2/4/6/8 | VL VR HT HB ×4 | life
;   Junction tile never damaged (no alts).
; ---------------------------------------------------------------------------
; A–F: full (healthy), dmg, critical
SC_RAIL_A       = $40
SC_RAIL_A_DMG   = $41
SC_RAIL_A_CRIT  = $42
SC_RAIL_B       = $43
SC_RAIL_B_DMG   = $44
SC_RAIL_B_CRIT  = $45
SC_RAIL_C       = $46
SC_RAIL_C_DMG   = $47
SC_RAIL_C_CRIT  = $48
SC_RAIL_D       = $49
SC_RAIL_D_DMG   = $4A
SC_RAIL_D_CRIT  = $4B
SC_RAIL_E       = $4C
SC_RAIL_E_DMG   = $4D
SC_RAIL_E_CRIT  = $4E
SC_RAIL_F       = $4F
SC_RAIL_F_DMG   = $50
SC_RAIL_F_CRIT  = $51
; G–J hubs: normal, mine
SC_RAIL_G       = $52
SC_RAIL_G_MINE  = $53
SC_RAIL_H       = $54
SC_RAIL_H_MINE  = $55
SC_RAIL_I       = $56
SC_RAIL_I_MINE  = $57
SC_RAIL_J       = $58
SC_RAIL_J_MINE  = $59
; B∩E centre cross (after second J, before bars)
SC_RAIL_X       = $5A
SC_RAIL_FIRST   = SC_RAIL_A
SC_RAIL_LAST    = SC_RAIL_J         ; letter elbows; X is separate
; Progress bar fill (order in atlas: 2, 4, 6, 8 px)
SC_UDG_BAR2     = $5B
SC_UDG_BAR4     = $5C
SC_UDG_BAR6     = $5D
SC_UDG_BAR8     = $5E
SC_UDG_BAR_FIRST = SC_UDG_BAR2
SC_UDG_BAR_COUNT = 4
; Bullets: left-vert, right-vert, top-horz, bot-horz
SC_BULLET_VL0   = $5F
SC_BULLET_VR0   = $63
SC_BULLET_HT0   = $67
SC_BULLET_HB0   = $6B
SC_BULLET_FIRST = SC_BULLET_VL0
SC_BULLET_COUNT = 16
; Reserve life icon (HUD PILOTS) — last UDG
SC_UDG_LIFE     = $6F
SC_LETTER_A     = SC_UDG_LIFE
SC_MINE         = SC_RAIL_G_MINE

; HUD: 000000 - WAVE 01 - ######## -PILOTS:AAAA  (40 columns)
; WAVE is +1 vs LVL → no space after the dash before PILOTS.
HUD_ROW                 = 0
HUD_SCORE_COL           = 0
HUD_SCORE_LEN           = 6
HUD_WAVE_LABEL_COL      = 9         ; "WAVE"
HUD_LEVEL_COL           = 14        ; 2 digits (wave number)
HUD_LEVEL_LEN           = 2
HUD_PROGRESS_COL        = 19        ; 8 bar cells full→empty
HUD_PROGRESS_LEN        = 8
HUD_PILOTS_LABEL_COL    = 29        ; "PILOTS:" (tight: " -PILOTS:")
HUD_LIVES_COL           = 36
HUD_LIVES_MAX_SHOW      = 4

; ---------------------------------------------------------------------------
; Bullets (character stream; V and H axes, 4px half-lanes)
; ---------------------------------------------------------------------------
BULLET_MAX              = 16
BULLET_HOLD             = 1
BULLET_PHASES           = 4
BULLET_CELL_TICKS       = BULLET_HOLD * BULLET_PHASES
; Vertical stream: half = X lane; horizontal: half = Y lane (same 0/1)
BULLET_HALF_LEFT        = 0
BULLET_HALF_RIGHT       = 1
BULLET_HALF_TOP         = 0
BULLET_HALF_BOT         = 1
; 3-row H-rail at rows 12–14; fire from adjacent cells
BULLET_RAIL_ROW_TOP     = 12
BULLET_RAIL_ROW_BOT     = 14
BULLET_LAUNCH_ROW_UP    = 11
BULLET_LAUNCH_ROW_DOWN  = 15
BULLET_ROW_MIN          = 1
; 3-col V-rail at cols 18–20; fire from adjacent cells
BULLET_LAUNCH_COL_LEFT  = 17
BULLET_LAUNCH_COL_RIGHT = 21
BULLET_COL_MIN          = 0
BULLET_COL_MAX          = 39
; Gun Y offset for V-arm aim (sprite top → tip); keeps (y+off-50) on 4px grid
PLAYER_GUN_Y_OFF        = 10
BULLET_COLOR            = COL_YELLOW

; ---------------------------------------------------------------------------
; Playfield rail / quadrant geometry (0-based char cells; matches a–j map)
;   Vertical band: cols 18–20  (A B C)
;   H-rail: rows 12–14 (D/G/B/H, full E, F/I/B/J)
;   Left free: 0–17   Right free: 21–39
; ---------------------------------------------------------------------------
RAIL_COL_LEFT           = 18
RAIL_COL_MID            = 19
RAIL_COL_RIGHT          = 20        ; inclusive
RAIL_ROW_TOP            = 12        ; D edge
RAIL_ROW_MID            = 13        ; E solid
RAIL_ROW_BOT            = 14        ; F edge
QUAD_LEFT_COL_MAX       = 17
QUAD_RIGHT_COL_MIN      = 21

; 24px sprite fully left of col 18 / right of col 21
; Left: X+23 < 24+18*8=168 → X<=144.  Right: X >= 24+21*8=192
DRONE_X_LEFT_MIN        = 28
DRONE_X_LEFT_MAX        = 144
DRONE_X_RIGHT_MIN       = 192
DRONE_X_RIGHT_MAX       = 320

; ---------------------------------------------------------------------------
; Drones — launcher v2 (dice + kill targets + piggyback C)
; obj_user = DRONE_APPROACH_*
;
; Speed model (8.7):
;   1) Precomputed velocity tiers (drone_vel_tier): equal first-sight→rail
;      time across N/S/E/W, scaled by level (L1 calm … L10 peak).
;   2) Class max tier: C = level, B = level-1, A = level-2 (floor 1).
;   3) Each spawn picks a tier ≤ class max; geometric step-down from max so
;      near-max is common and far-slow is rare at high levels.
;   Distances: DOWN 103, UP 89, RIGHT 160, LEFT 168; T≈140 at L1.
; ---------------------------------------------------------------------------
DRONE_HP_C              = 1
DRONE_HP_B              = 2
DRONE_HP_A              = 3
; Class max-tier offsets below current level cap (C uses full cap)
DRONE_TIER_OFF_C        = 0
DRONE_TIER_OFF_B        = 1
DRONE_TIER_OFF_A        = 2
; Approach
DRONE_APPROACH_DOWN     = 0         ; from top → H-rail
DRONE_APPROACH_UP       = 1         ; from bottom → H-rail
DRONE_APPROACH_RIGHT    = 2         ; from left → V-rail
DRONE_APPROACH_LEFT     = 3         ; from right → V-rail
; Off-screen spawn Y (mux-safe)
DRONE_SPAWN_Y_FROM_TOP  = MUX_MIN_SPRITE_Y       ; 37
DRONE_SPAWN_Y_FROM_BOT  = 262 - SPRITE_H_PX       ; 241
DRONE_SPAWN_Y           = DRONE_SPAWN_Y_FROM_TOP
; Off-screen spawn X
DRONE_SPAWN_X_EDGE_L_LO = 0
DRONE_SPAWN_X_EDGE_L_HI = 0
DRONE_SPAWN_X_EDGE_R_LO = $58                   ; 344
DRONE_SPAWN_X_EDGE_R_HI = 1
; In-quadrant coordinate bands (on-screen for the free axis)
; Left half X for vertical approach (Q3/Q4)
DRONE_BAND_X_L0         = 40
DRONE_BAND_X_L1         = 140
; Right half X (Q1/Q2) — stay in 8-bit X for simple dice (MSB spawn separate)
DRONE_BAND_X_R0         = 196
DRONE_BAND_X_R1         = 255
; Upper half Y for horizontal approach (Q1/Q4)
DRONE_BAND_Y_T0         = 70
DRONE_BAND_Y_T1         = 120
; Lower half Y (Q2/Q3)
DRONE_BAND_Y_B0         = 170
DRONE_BAND_Y_B1         = 220
; Legacy B spawn X (ensure_rail_attacker)
DRONE_B_SPAWN_X_LO      = 220
DRONE_B_SPAWN_X_HI      = 0
; Rail arrival
DRONE_RAIL_ARRIVE_Y     = 140
DRONE_RAIL_ARRIVE_Y_UP  = 152
DRONE_RAIL_ARRIVE_X_R   = 160
DRONE_RAIL_ARRIVE_X_L   = 176
DRONE_IMPACT_Y_OFF      = 4
QUAD_UL                 = 0
QUAD_UR                 = 1
QUAD_LL                 = 2
QUAD_LR                 = 3

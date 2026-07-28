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

; VIC defaults / modes
VIC_DEN         = %00010000         ; $D011 bit 4 — display enable
VIC_DEN_MASK    = %11101111         ; AND mask to clear DEN (avoid unary ~ width)
VIC_CTRL1_TEXT  = $1b               ; text, DEN, 25 rows, yscroll 3
VIC_CTRL1_BITMAP = $3b              ; bitmap (BMM), DEN, 25 rows, yscroll 3
; Same as above with DEN clear (mode switch while blanked)
VIC_CTRL1_TEXT_BLANK   = VIC_CTRL1_TEXT & VIC_DEN_MASK
VIC_CTRL1_BITMAP_BLANK = VIC_CTRL1_BITMAP & VIC_DEN_MASK
VIC_CTRL2_HIRES = $08               ; 40 cols, multicolour off
VIC_MEM_TEXT    = $14               ; screen $0400, charset ROM $1000 (boot only)
; Text + RAM charset @ $2800 (bank 0). CODE currently extends past $2000 into
; the old charset slot — do not put font at $2000 or install will trash IRQ code.
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
CHARSET_RAM     = $2800
CHARSET_SIZE    = 2048              ; 256 glyphs × 8 bytes
CHAR_ROM        = $D000             ; uppercase/graphics set (I/O bank out)
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
START_LIVES     = 3                 ; PILOTS; max HUD_LIVES_MAX_SHOW (4)
START_LEVEL     = 1
MAX_LEVEL       = 15
LEVEL_BANNER_FRAMES = 50            ; ~1s rank banner (no skip)
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

; C cargo → GHIJ mines. K stacks on each of G,H,I,J to arm (total cargo 4K).
CARGO_STEP_FRAMES = 4
MINE_STACK_K      = 1
SC_CARGO_DOT      = $2E
SC_MINE           = $2A

; Pixel inset for drone→col (matches rail::apply_ab_hit body align)
DRONE_IMPACT_X_OFF = 4

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
SPR_COLOR_PLAYER        = COL_GREEN

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
SPR_MC0_COLOR   = COL_DK_GRAY       ; $D025 — bit-pair 01
SPR_MC1_COLOR   = COL_CYAN          ; $D026 — bit-pair 11

; Per-kind individual colour (bit-pair 10 → $D027+n)
SPR_COLOR_DRONE_C = COL_RED         ; small / tiny
SPR_COLOR_DRONE_B = COL_GREEN       ; medium
SPR_COLOR_DRONE_A = COL_PURPLE      ; large

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
SPR_PTR_PARCEL        = $CC         ; $3300 — hires disc (own colour)

SPR_PTR_PLAYER_0      = $F8         ; $3E00 player buffer 0
SPR_PTR_PLAYER_1      = $F9         ; $3E40 player buffer 1

; Parcel / bonus (Step 9.1)
SPR_COLOR_PARCEL_SCORE = COL_YELLOW ; unique colour = payload cue
PARCEL_SPEED           = 2          ; ~½ PLAYER_MOVE_STEP (4)
PARCEL_PAYLOAD_SCORE   = 0          ; 9.1 only; bit-flags later
; Soft collect AABB (sprite-relative pixels)
PARCEL_HIT_X0          = 6
PARCEL_HIT_X1          = 17
PARCEL_HIT_Y0          = 5
PARCEL_HIT_Y1          = 14
; Kill-progress drop marks (2 per *level*)
PARCEL_DROP_T1         = %00000001  ; ~1/3 of level debt
PARCEL_DROP_T2         = %00000010  ; ~2/3 of level debt

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

; Ignore fire for a few frames after entering a menu (held-button bleed)
MENU_FIRE_GUARD = 20

; Story typewriter
STORY_MARGIN_X  = 1                 ; left-justified inset
STORY_START_Y   = 0
STORY_TYPE_DELAY = 1                ; frames between glyphs (~50% faster than 2)
STORY_STATE_TYPING = 0
STORY_STATE_DONE   = 1

; Screen codes for placeholder art
SC_SPACE        = $20
SC_STAR         = $2A
SC_PLUS         = $2B
SC_DASH         = $2D               ; legacy; playfield uses SC_RAIL_*
SC_ZERO         = $30
SC_VBAR         = $5D               ; legacy; playfield uses SC_RAIL_*
SC_HASH         = $23               ; HUD bar stand-in until UDGs
SC_LETTER_A     = $01               ; life icon stand-in / rail tile A placeholder

; Playfield rail placeholders (font A–J until UDGs installed). Key:
;   A left V-edge  B solid mid  C right V-edge
;   D top H-edge   E mid H      F bottom H-edge
;   G elbow L→up   H elbow top→R
;   I elbow L→down J elbow R→down
SC_RAIL_A       = $01
SC_RAIL_B       = $02
SC_RAIL_C       = $03
SC_RAIL_D       = $04
SC_RAIL_E       = $05
SC_RAIL_F       = $06
SC_RAIL_G       = $07
SC_RAIL_H       = $08
SC_RAIL_I       = $09
SC_RAIL_J       = $0A
SC_RAIL_FIRST   = SC_RAIL_A
SC_RAIL_LAST    = SC_RAIL_J

; HUD: 000000 - LVL 01 - ######## - PILOTS:AAAA  (40 columns)
HUD_ROW                 = 0
HUD_SCORE_COL           = 0
HUD_SCORE_LEN           = 6
HUD_LVL_LABEL_COL       = 9         ; "LVL"
HUD_LEVEL_COL           = 13        ; 2 digits
HUD_LEVEL_LEN           = 2
HUD_PROGRESS_COL        = 18        ; 8 bar cells full→empty
HUD_PROGRESS_LEN        = 8
HUD_PILOTS_LABEL_COL    = 29        ; "PILOTS:"
HUD_LIVES_COL           = 36
HUD_LIVES_MAX_SHOW      = 4

; ---------------------------------------------------------------------------
; UDG reservation map (install over ROM copy at CHARSET_RAM)
; Bullets already use half-cell lanes (4 phases × 2 halves = 8 per axis):
;   $F0–$F7  vertical  (VL0–3, VR0–3)
;   $F8–$FF  horizontal (HT0–3, HB0–3)  — reserved & defined
; Planned / reserved block (placeholders until art installs):
;   $C0      life icon (HUD)
;   $C1–$CA  rail normal a–j (10)
;   $CB–$D0  rail damage set 1 (a–f only, 6)
;   $D1–$D6  rail damage set 2 (a–f only, 6)
;   $D7–$DA  HUD bar fill (shared health + ammo): 8, 6, 4, 2 px tall
;            Empty cell = SC_SPACE (no blank UDG)
; Count: 1 life + 10 rail + 6 + 6 + 4 bar + 8v + 8h = 43
; ---------------------------------------------------------------------------
SC_BULLET_VL0   = $F0
SC_BULLET_VR0   = $F4
SC_BULLET_HT0   = $F8
SC_BULLET_HB0   = $FC
SC_BULLET_FIRST = SC_BULLET_VL0
SC_BULLET_COUNT = 16                ; 8 vert + 8 horiz (4px half-lanes)
SC_UDG_LIFE     = $C0
SC_UDG_RAIL0    = $C1               ; a–j normal → $C1..$CA
SC_UDG_DMG1     = $CB               ; a–f damage 1
SC_UDG_DMG2     = $D1               ; a–f damage 2
; Bar cells: one set for H and A (colour RAM distinguishes). Index by fill step.
SC_UDG_BAR8     = $D7               ; full 8 px
SC_UDG_BAR6     = $D8
SC_UDG_BAR4     = $D9
SC_UDG_BAR2     = $DA
SC_UDG_BAR_FIRST = SC_UDG_BAR8
SC_UDG_BAR_COUNT = 4
SC_UDG_COUNT    = 43                ; life+rails+dmg+bars+bullets

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

# RailGunner — host build orchestration
#
#   make            assets (if needed) → build/railgunner.prg
#   make play       full build, then windowed play (tools/c64/play.sh)
#   make coop       build, windowed emu + control port, coop_debug watcher
#   make assets     regenerate converted art when sources change
#   make screens    title (and future) screen bins only
#   make charset    atlas PNG → railgunner_charset.bin
#   make sprites    sprite bins (placeholder until converters exist)
#   make clean      remove build/ outputs (not assets/c64/ PNGs or generated bins)
#
# Generators live under tools/c64/; this file only wires timestamps and targets.
# Agent path stays tools/c64/agent_session.py (live assemble; no Makefile required).

.PHONY: all prg assets screens charset sprites play coop clean help ensure_prg_header core sdl

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOOLS := $(ROOT)/tools/c64
PYTHON ?= python3

# ---------------------------------------------------------------------------
# Converted assets (PNG → .bin for .incbin)
# ---------------------------------------------------------------------------

# Source art (hires products keep title_* names for .incbin stability)
TITLE_PNG := $(ROOT)/assets/c64/screens/railgunner.png
TITLE_HIRES_BIN := $(ROOT)/assets/c64/screens/title_hires.bin
TITLE_HIRES_COL := $(ROOT)/assets/c64/screens/title_hires_col.bin
TITLE_BINS := $(TITLE_HIRES_BIN) $(TITLE_HIRES_COL)
TITLE_OUT_PREFIX := $(ROOT)/assets/c64/screens/title
PNG_TO_HIRES := $(TOOLS)/png_to_c64_hires.py
PNG_TO_SPRITE := $(TOOLS)/png_to_c64_sprite.py
PNG_TO_CHARSET := $(TOOLS)/png_to_c64_charset.py

# Future: list more screen products here.
SCREEN_BINS := $(TITLE_BINS)

# VIC text font atlas (16×7 cells = 112 glyphs → 2K bin)
CHARSET_PNG := $(ROOT)/assets/c64/charset/railgunner_charset.png
CHARSET_BIN := $(ROOT)/assets/c64/charset/railgunner_charset.bin
CHARSET_BINS := $(CHARSET_BIN)

# Multicolour sprite frames: each assets/c64/sprites/*.png → same-stem .bin (64 bytes).
# --fit: medium/large source art currently exceeds 12×21; scale until remastered.
SPRITE_PNGS := $(wildcard $(ROOT)/assets/c64/sprites/*.png)
SPRITE_BINS := $(SPRITE_PNGS:.png=.bin)

ASSET_BINS := $(SCREEN_BINS) $(CHARSET_BINS) $(SPRITE_BINS)

# ---------------------------------------------------------------------------
# Assembly inputs → PRG
# ---------------------------------------------------------------------------

ASM_SRC := $(shell find $(ROOT)/src -type f \( -name '*.asm' -o -name '*.inc' \) | sort)
PRG := $(ROOT)/build/railgunner.prg
RAW := $(ROOT)/build/railgunner.raw
SYM := $(ROOT)/build/symbols.txt

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

all: prg

help:
	@echo "RailGunner make targets:"
	@echo "  make / make prg   regenerate assets if needed, assemble PRG"
	@echo "  make play         build then tools/c64/play.sh (windowed)"
	@echo "  make coop         build, emu+control-port, coop live-debug watcher"
	@echo "  make assets       screens + charset + sprites converters"
	@echo "  make screens      railgunner.png → title_hires*.bin"
	@echo "  make charset      railgunner_charset.png → .bin (2K font)"
	@echo "  make sprites      assets/c64/sprites/*.png → *.bin (64-byte MC)"
	@echo "  make clean        wipe build/ (keeps assets/c64/ PNGs; bins via make assets)"
	@echo "  make core        headless C simulation and tst/core traces"
	@echo "  make sdl         build and open the SDL window; not part of make/play"

# Drop a mis-tagged PRG (raw c64masm image written to .prg without $0801 load
# header). Make would otherwise treat it as up-to-date and play/--autorun fails.
ensure_prg_header:
	@$(PYTHON) -c "from pathlib import Path; p=Path(r'$(PRG)');\
import sys;\
sys.exit(0 if p.is_file() and p.stat().st_size>=4 and p.read_bytes()[:2]==b'\x01\x08' else 1)" \
		|| { echo "note: $(PRG) missing C64 load header 01 08 (raw assemble?) — rebuilding"; rm -f $(PRG); }

prg: ensure_prg_header $(PRG)

# Assets are prerequisites of the PRG so a PNG edit rebuilds bins then PRG.
# Always produce PRG via build-prg.sh (raw image + 2-byte load address).
# Do NOT point c64masm -o at build/railgunner.prg — that omits the header.
$(PRG): $(ASSET_BINS) $(ASM_SRC) $(TOOLS)/build-prg.sh $(TOOLS)/c64masm
	@mkdir -p $(ROOT)/build
	$(TOOLS)/build-prg.sh
# build-prg.sh fails on c64masm errors and on CODE growing into CHARSET/sprites.

# Umbrella: force-walk groups (cheap while asset count is tiny).
assets: screens charset sprites

screens: $(SCREEN_BINS)

charset: $(CHARSET_BINS)

$(CHARSET_BIN): $(CHARSET_PNG) $(PNG_TO_CHARSET)
	$(PYTHON) $(PNG_TO_CHARSET) $(CHARSET_PNG) -o $(CHARSET_BIN)

sprites: $(SPRITE_BINS)

# Multicolour VIC sprite: 12×21 logical pixels → 64-byte block.
# --fit until medium/large PNGs are remastered to native 12×21.
$(ROOT)/assets/c64/sprites/%.bin: $(ROOT)/assets/c64/sprites/%.png $(PNG_TO_SPRITE)
	$(PYTHON) $(PNG_TO_SPRITE) $< --fit -o $@

# One converter writes both hires products; col bin tracks the bitmap bin.
$(TITLE_HIRES_BIN): $(TITLE_PNG) $(PNG_TO_HIRES)
	$(PYTHON) $(PNG_TO_HIRES) $(TITLE_PNG) -o $(TITLE_OUT_PREFIX)

$(TITLE_HIRES_COL): $(TITLE_HIRES_BIN)
	@test -f $(TITLE_HIRES_COL) || { echo "error: missing $(TITLE_HIRES_COL) after hires convert" >&2; exit 1; }

# Build then launch; skip a second assemble inside play.sh (header already checked).
play: prg
	RAILGUNNER_SKIP_BUILD=1 $(TOOLS)/play.sh

# Build, start windowed c64m with control port + PRG if needed, run coop watcher.
# Protocol: agents/coop-debug.md  (pause on glitch → build/debug/snap-*.txt)
coop: prg
	RAILGUNNER_SKIP_BUILD=1 $(TOOLS)/coop.sh

# ---------------------------------------------------------------------------
# Portable core (headless) and SDL frontend.
# These are not prerequisites of prg or play. The C64 assemble glob only
# matches .asm/.inc, so C sources under src/core and src/sdl do not rebuild
# the PRG.
# ---------------------------------------------------------------------------

CORE_BIN := $(ROOT)/build/railgunner-core
SDL_BIN := $(ROOT)/build/railgunner-sdl
CORE_C := $(shell find $(ROOT)/src/core -name '*.c' | sort)
CORE_H := $(shell find $(ROOT)/src/core -name '*.h' | sort)
CORE_LIB_C := $(filter-out $(ROOT)/src/core/main.c,$(CORE_C))
SDL_C := $(shell find $(ROOT)/src/sdl -name '*.c' | sort)
CC ?= cc
CORE_CFLAGS := -std=c11 -Wall -Wextra -Werror -I$(ROOT)/src/core

core: $(CORE_BIN)
	sh $(ROOT)/tst/core/run.sh

$(CORE_BIN): $(CORE_C) $(CORE_H)
	@mkdir -p $(ROOT)/build
	$(CC) $(CORE_CFLAGS) -o $@ $(CORE_C)

# Opens the window. Not a prerequisite of prg or play, so a machine
# without SDL2 can still assemble the C64 game.
$(SDL_BIN): $(SDL_C) $(CORE_LIB_C) $(CORE_H)
	@command -v sdl2-config >/dev/null 2>&1 || { echo "sdl2-config not found" >&2; exit 1; }
	@mkdir -p $(ROOT)/build
	$(CC) $(CORE_CFLAGS) $$(sdl2-config --cflags) -DRAILGUNNER_ROOT=\"$(ROOT)\" -o $@ $(SDL_C) $(CORE_LIB_C) $$(sdl2-config --libs)

sdl: $(SDL_BIN)
	$(SDL_BIN)

clean:
	rm -f $(RAW) $(PRG) $(SYM)
	rm -f $(CORE_BIN) $(SDL_BIN)
	rm -f $(ROOT)/build/title_hires_preview.png

# Optional native frontend; existing default and launch targets are unchanged.
include tools/archie/build.mk

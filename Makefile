# RailGunner — host build orchestration
#
#   make            assets (if needed) → build/railgunner.prg
#   make play       full build, then windowed play (tools/play.sh)
#   make assets     regenerate converted art when sources change
#   make screens    title (and future) screen bins only
#   make charset    charset bins (placeholder until converters exist)
#   make sprites    sprite bins (placeholder until converters exist)
#   make clean      remove build/ outputs (not assets/ PNGs or generated bins)
#
# Generators live under tools/; this file only wires timestamps and targets.
# Agent path stays tools/agent_session.py (live assemble; no Makefile required).

.PHONY: all prg assets screens charset sprites play clean help

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOOLS := $(ROOT)/tools
PYTHON ?= python3

# ---------------------------------------------------------------------------
# Converted assets (PNG → .bin for .incbin)
# ---------------------------------------------------------------------------

# Source art (hires products keep title_* names for .incbin stability)
TITLE_PNG := $(ROOT)/assets/screens/railgunner.png
TITLE_HIRES_BIN := $(ROOT)/assets/screens/title_hires.bin
TITLE_HIRES_COL := $(ROOT)/assets/screens/title_hires_col.bin
TITLE_BINS := $(TITLE_HIRES_BIN) $(TITLE_HIRES_COL)
TITLE_OUT_PREFIX := $(ROOT)/assets/screens/title
PNG_TO_HIRES := $(TOOLS)/png_to_c64_hires.py
PNG_TO_SPRITE := $(TOOLS)/png_to_c64_sprite.py

# Future: list more screen / charset products here.
SCREEN_BINS := $(TITLE_BINS)
CHARSET_BINS :=

# Multicolour sprite frames: each assets/sprites/*.png → same-stem .bin (64 bytes).
# --fit: medium/large source art currently exceeds 12×21; scale until remastered.
SPRITE_PNGS := $(wildcard $(ROOT)/assets/sprites/*.png)
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
	@echo "  make play         build then tools/play.sh (windowed)"
	@echo "  make assets       screens + charset + sprites converters"
	@echo "  make screens      railgunner.png → title_hires*.bin"
	@echo "  make charset      (no converters yet)"
	@echo "  make sprites      assets/sprites/*.png → *.bin (64-byte MC)"
	@echo "  make clean        wipe build/ (keeps assets/ PNGs; bins via make assets)"

prg: $(PRG)

# Assets are prerequisites of the PRG so a PNG edit rebuilds bins then PRG.
$(PRG): $(ASSET_BINS) $(ASM_SRC) $(TOOLS)/build-prg.sh $(TOOLS)/c64masm
	@mkdir -p $(ROOT)/build
	$(TOOLS)/build-prg.sh

# Umbrella: force-walk groups (cheap while asset count is tiny).
assets: screens charset sprites

screens: $(SCREEN_BINS)

charset:
	@# No charset converters yet — directory reserved under assets/charset/
	@true

sprites: $(SPRITE_BINS)

# Multicolour VIC sprite: 12×21 logical pixels → 64-byte block.
# --fit until medium/large PNGs are remastered to native 12×21.
$(ROOT)/assets/sprites/%.bin: $(ROOT)/assets/sprites/%.png $(PNG_TO_SPRITE)
	$(PYTHON) $(PNG_TO_SPRITE) $< --fit -o $@

# One converter writes both hires products; col bin tracks the bitmap bin.
$(TITLE_HIRES_BIN): $(TITLE_PNG) $(PNG_TO_HIRES)
	$(PYTHON) $(PNG_TO_HIRES) $(TITLE_PNG) -o $(TITLE_OUT_PREFIX)

$(TITLE_HIRES_COL): $(TITLE_HIRES_BIN)
	@test -f $(TITLE_HIRES_COL) || { echo "error: missing $(TITLE_HIRES_COL) after hires convert" >&2; exit 1; }

# Build then launch; skip a second assemble inside play.sh.
play: prg
	RAILGUNNER_SKIP_BUILD=1 $(TOOLS)/play.sh

clean:
	rm -f $(RAW) $(PRG) $(SYM)
	rm -f $(ROOT)/build/title_hires_preview.png

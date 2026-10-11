# Isolated ARM2 objects. Missing SDK affects only Archie targets.
ARCHIESDK ?= $(HOME)/Develop/gitlab/archiesdk
ARCHIE_CC := $(ARCHIESDK)/tools/bin/arm-archie-gcc
ARCHIE_OBJCOPY := $(ARCHIESDK)/tools/bin/arm-archie-objcopy
ARCHIE_CFLAGS := -std=c11 -mcpu=arm2 -msoft-float -mno-thumb-interwork -O2 -Wall -Wextra -Werror -I$(ROOT)/src/core -I$(ROOT)/src/archie -isystem $(ARCHIESDK)/SDK/include
ARCHIE_SOURCES := $(CORE_LIB_C) $(wildcard $(ROOT)/src/archie/*.c)
ARCHIE_OBJECTS := $(ROOT)/build/archie/obj/archie/keys.o $(ROOT)/build/archie/obj/archie/oscillator.o $(ROOT)/build/archie/obj/noise-table.o $(ROOT)/build/archie/obj/assets.o $(ROOT)/build/archie/obj/assets-blit.o  $(ROOT)/build/archie/obj/archie/sound-voice.o $(ROOT)/build/archie/obj/archie/vsync.o $(ROOT)/build/archie/obj/archie/blit.o  $(patsubst $(ROOT)/src/%.c,$(ROOT)/build/archie/obj/%.o,$(ARCHIE_SOURCES))
ARCHIE_ELF := $(ROOT)/build/archie/railgunner.elf
ARCHIE_BIN := $(ROOT)/build/archie/railgunner,ff8
.PHONY: archie archie-check-sdk sdl-build archie-run
sdl-build: $(SDL_BIN)
archie-check-sdk:
	@test -x "$(ARCHIE_CC)" -a -x "$(ARCHIE_OBJCOPY)" -a -f "$(ARCHIESDK)/SDK/include/kernel.h" -a -f "$(ARCHIESDK)/SDK/lib/libOSLib32.a" || { echo 'ArchieSDK incomplete; set ARCHIESDK to the installation root' >&2; exit 1; }
archie: $(ARCHIE_BIN)
$(ROOT)/build/archie/obj/%.o: $(ROOT)/src/%.c tools/archie/build.mk | archie-check-sdk
	@mkdir -p $(@D)
	$(ARCHIE_CC) $(ARCHIE_CFLAGS) -MMD -MP -c $< -o $@
$(ARCHIE_ELF): $(ARCHIE_OBJECTS)
	$(ARCHIE_CC) $(ARCHIE_CFLAGS) -Wl,-Map,$(ROOT)/build/archie/railgunner.map -o $@ $^ -L$(ARCHIESDK)/SDK/lib -lOSLib32
$(ARCHIE_BIN): $(ARCHIE_ELF)
	$(ARCHIE_OBJCOPY) -O binary $< $@
archie-run: archie
	$(PYTHON) $(ROOT)/tools/archie/run.py
-include $(ARCHIE_OBJECTS:.o=.d)

$(ROOT)/build/archie/obj/archie/%.o: $(ROOT)/src/archie/%.s tools/archie/build.mk | archie-check-sdk
	@mkdir -p $(@D)
	$(ARCHIE_CC) $(ARCHIE_CFLAGS) -MMD -MP -c $< -o $@

$(ROOT)/build/archie/assets.c: $(ASSET_BINS) src/core/data/tables.c src/core/const.h tools/archie/assets.py
	@mkdir -p $(@D)
	$(PYTHON) $(ROOT)/tools/archie/assets.py $@

$(ROOT)/build/archie/obj/assets.o: $(ROOT)/build/archie/assets.c src/archie/assets.h | archie-check-sdk
	@mkdir -p $(@D)
	$(ARCHIE_CC) $(ARCHIE_CFLAGS) -MMD -MP -c $< -o $@

.PHONY: archie-test
ARCHIE_HOST_TEST := $(ROOT)/build/archie/render-test
$(ARCHIE_HOST_TEST): tst/archie/render.c src/archie/render.c src/archie/render.h src/archie/assets.h $(ROOT)/build/archie/assets.c $(CORE_LIB_C) $(CORE_H) src/sdl/blit.c src/sdl/blit.h tst/archie/texture-stub/SDL.h
	$(CC) $(CORE_CFLAGS) -I$(ROOT)/src/archie -I$(ROOT)/tst/archie/texture-stub -O2 -DRAILGUNNER_ROOT=\"$(ROOT)\" -fsanitize=address,undefined -g -o $@ tst/archie/render.c src/archie/render.c $(ROOT)/build/archie/assets.c $(CORE_LIB_C)
archie-test: $(ARCHIE_HOST_TEST)
	$(ARCHIE_HOST_TEST)

$(ROOT)/build/archie/assets-blit.S: $(ROOT)/build/archie/assets.c tools/archie/assets.py
	$(PYTHON) $(ROOT)/tools/archie/assets.py $(ROOT)/build/archie/assets.c
$(ROOT)/build/archie/obj/assets-blit.o: $(ROOT)/build/archie/assets-blit.S | archie-check-sdk
	@mkdir -p $(@D)
	$(ARCHIE_CC) $(ARCHIE_CFLAGS) -c $< -o $@

$(ROOT)/build/archie/audio-reference.c: src/sdl/audio.c tools/archie/audio-reference.py
	@mkdir -p $(@D)
	$(PYTHON) tools/archie/audio-reference.py $@
$(ROOT)/build/archie/audio-test: tst/archie/audio.c src/archie/synth.c src/archie/synth.h $(ROOT)/build/archie/audio-reference.c src/sdl/audio.h tst/archie/texture-stub/SDL.h $(CORE_LIB_C) $(CORE_H)
	$(CC) $(CORE_CFLAGS) -I$(ROOT)/src/archie -I$(ROOT)/src/sdl -I$(ROOT)/tst/archie/texture-stub -O2 -fsanitize=address,undefined -g -o $@ tst/archie/audio.c src/archie/synth.c $(ROOT)/build/archie/audio-reference.c $(CORE_LIB_C)
.PHONY: archie-audio-test
archie-audio-test: $(ROOT)/build/archie/audio-test
	$<

.PHONY: archie-input-test
$(ROOT)/build/archie/input-test: tst/archie/input.c src/archie/input.c src/archie/input.h $(CORE_H) | archie-check-sdk
	@mkdir -p $(@D)
	$(CC) $(CORE_CFLAGS) -I$(ROOT)/src/archie -idirafter $(ARCHIESDK)/SDK/include -fsanitize=address,undefined -g -o $@ tst/archie/input.c src/archie/input.c
archie-input-test: $(ROOT)/build/archie/input-test
	$<

$(ROOT)/build/archie/noise-table.S: tools/archie/noise-table.py
	@mkdir -p $(@D)
	$(PYTHON) $< $@
$(ROOT)/build/archie/obj/noise-table.o: $(ROOT)/build/archie/noise-table.S | archie-check-sdk
	@mkdir -p $(@D)
	$(ARCHIE_CC) $(ARCHIE_CFLAGS) -c $< -o $@

.PHONY: archie-package
archie-package: archie
	$(PYTHON) $(ROOT)/tools/archie/package.py

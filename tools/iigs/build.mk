# IIgs only; no changes to the default/C64/SDL/Archimedes targets.
IIGS_TEMPLATE ?= ../force/assets/iigs/disc/templat.2mg
IIGS_VOLUME ?= FORCE
# Playable native game: NTSC clock, compiled sprites, no frame admission veto.
IIGS_ROM ?= 3
IIGS_GAME_SPEED ?= 7.159mhz
.PHONY: iigs-game iigs-game-play iigs-game-package
iigs-game:
	$(PYTHON) tools/iigs/native_oracle.py
	$(PYTHON) tools/iigs/native_core_build.py --group 5 --out build/iigs/nativecore-game
	$(PYTHON) tools/iigs/native_specialized_build.py --game-source build/iigs/nativecore-game/game-production.s --game-manifest build/iigs/nativecore-game/manifest.json --speed "$(IIGS_GAME_SPEED)" --out build/iigs/native-game-play

iigs-game-play: iigs-game
	$(PYTHON) tools/iigs/native_probe.py --play --rom "$(IIGS_ROM)" --binary build/iigs/native-game-play/RAILGUNNER --manifest build/iigs/native-game-play/manifest.json --source build/iigs/native-game-play/main.asm --speed "$(IIGS_GAME_SPEED)" --template "$(IIGS_TEMPLATE)" --volume "$(IIGS_VOLUME)"

iigs-game-package: iigs-game
	$(PYTHON) tools/iigs/native_package.py --binary build/iigs/native-game-play/RAILGUNNER --manifest build/iigs/native-game-play/manifest.json --template "$(IIGS_TEMPLATE)" --volume "$(IIGS_VOLUME)" --out build/iigs/native-game-package

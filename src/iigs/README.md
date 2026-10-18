# Native Apple IIgs port

Start with [the current handoff](../../agents/iigs-beam-renderer-handoff.md).
The game is native ORCA/M, with gameplay adapted from C64 assembly. The retired
ORCA/C platform experiment is removed. Shared `src/core` and the host C oracle
remain intentionally; no C runtime is linked into the IIgs executable.

The renderer now releases disjoint restore/redraw regions behind the beam and
keeps candidates immutable until completion. See the [measured results](../../agents/iigs-beam-renderer-results.md)
for scan-time stability, exact pixels, cadence, and remaining stock-speed limits.
The measurements do not establish locked 30 Hz or hardware acceptance.

```sh
make iigs-game
make iigs-game-play IIGS_GAME_SPEED=14.3mhz
make iigs-game-package IIGS_GAME_SPEED=14.3mhz
```

Default ROM3, NTSC,7.159 MHz. Template/volume overrides: `IIGS_TEMPLATE`,
`IIGS_VOLUME`. Packaging/launch copy the user's GS/OS media privately.
The launch disk is `railgunner-iigs.2mg` with config `railgunner-iigs.gs2`; packaged
images are `railgunner-iigs.2mg` (bootable), `railgunner-iigs-transfer.2mg`,
and `railgunner-iigs-800K.po` (non-bootable 800K ProDOS-order floppy). Mount
the transfer/floppy disk under an existing GS/OS system to run or copy RAILGUNNER.
`IIGS_GAME_SPEED` configures the emulator and manifest only; the game executable
is identical at every speed setting. Hardware supplies its own actual CPU speed.
Space advances title/start and fires; arrows/WASD move; S/I select frontend pages;
Escape is Run/Stop; Ctrl-Q returns to GS/OS. Audio is deferred.

The shipping IIgs high-score table uses light grey with one yellow row moving
down every ten logic ticks. `highscore_color.asm` restores the previous row and
colours the next (80 cells instead of 400); entry paints the full base once.
Initials retain their yellow/white editing cursor. `native_game_export.py`
replaces only the two shipping colour procedures; CORETEST keeps the C64 wheel.
Run `python3 tools/iigs/native_highscore_color_test.py` for native cadence/wrap
checks; `native_continuous_smoke.py --session ... --highscore-roll` checks actual
completed pixels and dirty cells in a windowed game. The 7.159 MHz check passed
twelve consecutive two-row updates, including wrap, plus input/exit/black-transition
checks. Evidence: `build/iigs/highscore-color-evidence/`.

`main.asm` is a builder template, not a standalone assembly target. Build
through `native_specialized_build.py`/Make; generated sources are under `build/iigs`.

Assembly template transformations use `tools/iigs/asm_transform.py`: Cadius column
spacing and tabs are supported without changing source formatting. Labels must
remain in column zero; quoted data and line boundaries remain significant.
Required edits check their match counts and fail before assembly when an anchor
is missing or ambiguous. Python-template edits also check exact match counts.
Run `python3 tools/iigs/asm_transform_test.py` for formatting regressions.
The handoff maps runtime files, tools, reference projects, measurements, test
limitations, and the desired scheduling. [Input ownership](../../agents/iigs-native-input.md)
and [hardware validation](../../agents/iigs-native-hardware.md) retain useful details.

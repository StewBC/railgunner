# Native Apple IIgs port

Start with [the current handoff](../../agents/iigs-beam-renderer-handoff.md).
The game is native ORCA/M, with gameplay adapted from C64 assembly. The retired
ORCA/C platform experiment is removed. Shared `src/core` and the host C oracle
remain intentionally; no C runtime is linked into the IIgs executable.

The game currently flashes during play because erase/redraw is not coordinated
with the beam. **The beam-following fix is the next task, not a completed feature.**
Final framebuffer correctness and mean FPS do not establish presentation quality.

```sh
make iigs-game
make iigs-game-play IIGS_GAME_SPEED=14.3mhz
make iigs-game-package IIGS_GAME_SPEED=14.3mhz
```

Default ROM3, NTSC,7.159MHz. Template/volume overrides: `IIGS_TEMPLATE`,
`IIGS_VOLUME`. Packaging/launch copy the user's GS/OS media privately.
Space advances title/start and fires; arrows/WASD move; S/I select frontend pages;
Escape is Run/Stop; Ctrl-Q returns to GS/OS. Audio is deferred.

`main.asm` is a builder template, not a standalone assembly target. Build
through `native_specialized_build.py`/Make; generated sources are under `build/iigs`.
The handoff maps runtime files, tools, reference projects, measurements, test
limitations, and the desired scheduling. [Input ownership](../../agents/iigs-native-input.md)
and [hardware validation](../../agents/iigs-native-hardware.md) retain useful details.

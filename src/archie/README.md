# Archimedes frontend

A native frontend on the unchanged game core, targeting A3010 / ARM250,
2 MB RAM and RISC OS 3.11. Emulator validation and packaging are complete; see the
execution ledger in `agents/archie-port.md` for accepted gates and limitations.

```
make archie                # ARM2 C11/O2 executable, ELF and map
make archie-run            # private windowed A3010 Arculator deployment
make archie-package        # !RGunner and both ZIP transports
make archie-test           # 10,161 SDL/reference/incremental pixel comparisons
make archie-audio-test     # 2,251,800 SDL synthesis comparisons
make archie-input-test     # keyboard/joystick mapping and fallback checks
```

`ARCHIESDK` defaults to `$HOME/Develop/gitlab/archiesdk`; `ARCU_HOME` defaults
 to `$HOME/Applications/arculator`. External installations are read-only.
Emulator CMOS, configuration, HostFS and writable files live under
`build/archie/arculator`. The baseline uses 2 MB, RISC OS 3.11 and normal speed.
Open HostFS and `!RGDiag` to play. The packaged application is `!RGunner`.

Release files are under `build/archie/release/`. Extract `RailGunner-HostFS.zip`
into an emulator HostFS directory, preserving comma file-type suffixes, and
open `!RGunner`. For RISC OS disks, extract `RailGunner-RISCOS.zip` with an
Acorn-aware unzip tool that restores native file types. The package includes
its icon, executable, launcher and licence notices; no external sound module
installation is required. Clean packaged launch, play and repeated quit/relaunch
passed on the baseline emulator.

Either native joystick port or cursors/WASD move; joystick fire or Space
fires/starts/selects. S opens story and also moves
down, I opens instructions, Escape retains RUN/STOP behavior. **Ctrl-Q exits**.
Both ports are polled once per tick through XJoystick_Read, with an axis dead
zone from -32 to 32. Keyboard input stays active; unavailable/erroring ports
are disabled until relaunch. Native joystick hardware and its incremental
polling cost have not yet been measured.
The core keeps its existing edge detection, 50 Hz tick order and RAM scores.
There are no catch-up ticks. No core, C64 or SDL source has been changed.

Executable arguments:

- `play` (also no argument): full game with native keyboard and sound.
- `banks`: G1 checkerboard/bank diagnostic, 3,050 flips.
- `graphics` / `profile`: native scalar audits and G2 graphics batches.
- `audio`: 128 native scalar synthesis audits, production batch and transport.
- `integrated [scenario] [frames]`: audible combined loop; default 3,050 frames.
  Scenario 0 uses native input, 1 automated late-level play, 2 eight synthetic
  sprites plus 16 bullet changes and three voices, 3 all 24 sprite slots.
  Scenario 4 enables intrusive per-frame stage timing for native input.
  Normal gameplay and cadence tests avoid per-frame timing SWIs.

Diagnostic reports use `<RGDiag$Dir>` and are written after stopping sound.
Retained evidence lives under `build/archie/evidence`. Only centisecond timing
is available: batch averages and VSync/underrun counters are measured; fine
percentiles are not. Frame counters include interrupt traffic and presentation.

Mode 9 has two verified disjoint banks, 320x256 pixels, stride 160, with the
320x200 game at Y=28. The quantized SDL palette and black margins are installed
and OS state restored at exit. Dirty backgrounds and sprite footprints belong
to each bank. Embedded assets derive deterministically from the SDL/C64 blobs.
ARM assembly has independent scalar references; host comparisons use unchanged
SDL pixels under ASan/UBSan. The installed SDK's defective `memcmp` is avoided
in native audits; external SDK files remain unchanged.

Sound uses a small position-independent RMA voice and a 1,024-byte ring. Its
bounded interrupt copies VIDC logarithmic bytes and counts underruns, without
SWIs, allocations, file I/O or application pointers. Foreground integer SID
synthesis preserves phase, noise, ADSR and all published core voices. Sample
period is 48 us (about 20.833 kHz), DMA buffer 208 samples (9.984 ms), queued
producer target at most 40 ms; hardware latency is separate. Common-rate SDL
comparison has exact oscillator/noise state, max error 3 signed-16 units,
mean 0.699 before unavoidable native 8-bit logarithmic quantization.

G1 passed 60 seconds with zero misses. User accepted G2 progression with one
miss in 3,050 24-sprite frames (7.79 ms graphics / 8.30 ms core+graphics).
Native standalone sound ran 60.90 seconds without misses/underruns; latest
production batch is 6.84 ms versus the original 4 ms allowance. The user
approved prioritizing full integration and the total 20 ms budget. Three ten-minute combined runs (title, late-level play, eight sprites) had
zero underruns, with 97, 49 and 2 missed VSyncs respectively. The user accepted
this evidence and ended further performance testing; strict zero misses and
fine timing percentiles are not claimed.

The current ELF footprint is about 744 KB including the SDK's stack reservation.
The application slot is 896 KB; rounded screen storage is 163,840 bytes and
sound RMA about 1.3 KB, separate from the slot. Baseline emulator allocations and packaged launch/exit passed. Actual hardware
acceptance, native ZIP extraction and failure injection remain pending.

For hardware validation, extract the native ZIP with an Acorn-aware unzip tool,
launch `!RGunner` on A3010/2 MB/RISC OS 3.11, and exercise title music, S/I,
play with multiple effects, deaths, banners, game over and initials. Check
sprite/rail restoration, flicker, sound crackle and keyboard response; quit with
Ctrl-Q and repeat launch/exit. Run for ten minutes and report machine/OS, sound
and cadence observations. Emulator evidence does not establish hardware acceptance.

Native interfaces follow the RISC OS PRM:
[VDU](https://riscos.com/support/developers/prm/vdu.html),
[vectors](https://www.riscos.com/support/developers/prm/softvecs.html),
[sound](https://riscos.com/support/developers/prm/sound.html).
Banking was independently adapted from Time Pilot's public-domain video code.

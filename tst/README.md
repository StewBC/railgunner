# Standalone tests

## Sprite multiplexer dance

`sprite_mux_dance.asm` is a separate C64 program that exercises the production
24-slot graphical-object pool and sprite multiplexer without the RailGunner
frontend or gameplay code.

It creates 14 colored logical objects in two seven-sprite ribbons. Both groups
bob vertically while their members follow phase-shifted horizontal waves. The
second ribbon reuses the hardware lanes used by the first, proving that more
than eight logical sprites are displayed in one frame. A red border means the
plan builder or publisher reported an error.

Build only:

```bash
tst/build_sprite_mux_dance.sh
```

This writes `build/sprite_mux_dance.prg` and
`build/sprite_mux_dance.symbols.txt`.

Build and run in the required visible emulator:

```bash
tst/play_sprite_mux_dance.sh
```

Pass a video-standard override through to c64m when needed:

```bash
tst/play_sprite_mux_dance.sh --video PAL
tst/play_sprite_mux_dance.sh --video NTSC
```

## Clockwise orbit

`sprite_mux_circle.asm` is the more adventurous variant. Fourteen objects orbit
one ellipse clockwise. Every object passes through both the upper and lower
halves, so their Y order changes continuously and the multiplexer must re-sort
the pool and transfer hardware-sprite ownership throughout the orbit.

Build or play:

```bash
tst/build_sprite_mux_circle.sh
tst/play_sprite_mux_circle.sh
```

PAL and NTSC overrides work the same way:

```bash
tst/play_sprite_mux_circle.sh --video PAL
tst/play_sprite_mux_circle.sh --video NTSC
```

Both demos share `sprite_mux_demo_runtime.asm`, which owns only test
presentation and initialization; the pool, builder, IRQ executor, collision
handoff, and video-standard code are included directly from `src/`.

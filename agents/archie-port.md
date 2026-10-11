# RailGunner — Archimedes port execution and release record

**Status:** Emulator release completed 2026-10-11. The full game has native input,
banked Mode 9 rendering and sound, and is delivered as `!RailGunner` plus HostFS
and native RISC OS ZIPs. Packaged launch, play, exit and relaunch passed. The
user accepted occasional missed VSyncs and ended further performance testing.
Actual hardware acceptance remains pending. The phases below retain the original
plan; the ledger and final delivery record describe the completed work and limits.

**Goal:** The shipped RailGunner game, with the same art, sound events, controls,
rules, and pace, presented natively on an Acorn Archimedes through ArchieSDK.

**Baseline:** A3010 / ARM250, **2 MB RAM, RISC OS 3.11**, at normal machine speed.
Generate ARMv2-compatible code with ARM2 compiler settings. Compatibility with
other machines can be reported when tested; ARM2-compatible code alone does not
prove acceptable performance on every ARM2 machine.

This is a new frontend on `src/core/`, a sibling of `src/sdl/`. The finished C64
and SDL games remain supported. This document retains the original port plan and its execution record; historical
open rows in the other handoffs are not a work queue.

## 1. Required reading and reference boundaries

Before execution, read `agents/README.md` and its applicable handoff path:

- `level-rework.md`: shipped loop and authoritative behavior.
- `railgunner.md`, `roadmap.md`: design and history; defer to shipped behavior.
- `repo-layout.md`, `c64-to-sdl.md`: frontend boundary, timing, coordinates,
  accepted differences, and existing assets.
- `objects-sprites.md`, `sprite-mux-status.md`, `sprite-mux-issues.md`: object
  lifecycle, priority, and historical C64 constraints. Do not port the mux.
- `build-debug.md` before using c64m; `assembler-syntax.md` before changing C64
  assembly. Neither activity should be needed for routine frontend work.

Read the actual interfaces and implementations:

- `src/core/{sim,cells,objects,input,play,bullets,rail,cargo,parcels,music,sfx}.*`,
  `src/core/const.h`, and `src/core/data/tables.*`.
- `src/sdl/{main,blit,audio}.*`: visual reference, input mapping, audio synthesis.
- `Makefile` and `tst/core/run.sh`, including the existing traces.

External projects are **read-only references**:

| Reference | What to inspect and reuse conceptually |
|---|---|
| `../Time-Pilot/TimePilot-Archie/README.md` | Tested hardware, runtime, packaging, sound-module details |
| Time Pilot `src/archie.c` | Checked bank discovery, write/display bank selection, VSync, cleanup, per-bank sprite damage |
| Time Pilot `src/{sprite,erase,update,input,audio}.c` | Clipping, fast transfers, dirty regions, key sampling, sound lifecycle |
| Time Pilot `misc/{resman,package,app_icon}.py` and toolchain files | Asset generation, RISC OS file types, application packaging |
| `../cc65-Chess/make/common.mk`, `Makefile`, `make/{ports/archie,toolchains/archiesdk}.mk` | SDK detection and isolated target rules |
| Chess `src/archie/platArchie.c` | Mode 9 packed pixels, independent palette entries, 320×200 placement |
| Installed ArchieSDK headers, libraries, examples, and relevant RISC OS documentation | Actual SWI signatures, startup, timing, bank and sound contracts |

Verify APIs against installed headers and implementation or primary documentation.
Do not invent a streaming API from Time Pilot's prerecorded-sample interface.
Do not modify Time Pilot, Chess, ArchieSDK, c64m, or shared emulator installations.
Put emulator configuration and deployment staging inside this repository.
Preserve attribution and comply with licences for any copied code or module.

## 2. Fixed behavior and frontend architecture

### Preserve the game

- Link the existing core library sources, excluding `src/core/main.c`.
- Keep `sim_tick()` and its call order, wrap behavior, RNG, collision, and tables.
- Run logic and the core audio sequencers at **50 Hz**, one tick per due frame.
  Drop missed backlog; do not run catch-up ticks or use variable delta time.
- Keep VIC coordinates in the core. Rendering subtracts **24 from X, 50 from Y**;
  the display margin is a frontend offset only.
- Keep the 40×25 glyph/color grid as real game state. Bullets remain characters,
  with their existing phases and collision behavior.
- Render every `OBJF_RENDER` object with SDL's frame selection, multicolor
  decoding, clipping, and priority/tie order. No C64 sprite capacity emulation.
- Keep title music, existing effects, voice stealing, and RAM high scores.
  Do not add gameplay, disk scores, continuous gun sound, or in-game music.

Core changes need a specific correctness reason and regression coverage. Dirty
tracking and performance counters belong in the frontend initially; a scan of
1,000 cells avoids changing all the core's direct cell writes.

### Initial video choice: Mode 9

Use 320×256, 16 colors, two pixels per byte, a nominal 160-byte row. Place the
unchanged 320×200 image at **Y=28**, with black top/bottom margins and border.
Read back and verify mode variables rather than trusting assumed geometry.
Use SDL's existing RGB palette, quantized to the available VIDC component
precision, rather than substituting Chess's different C64 palette.

Mode 9 offers independent colors and less transfer traffic than Mode 13. Its
packed sprite writes require more care. Mode 9 bank flipping is a hypothesis to
prove in Phase 1, not a capability already established by Chess. Time Pilot proves
banking in Mode 13, not this exact combination.

### Character background plus two display banks

Maintain one packed **320×200 background image without object sprites**. It is a
render of the current cells, including bullets, rail scars, mines, HUD, and text.
It is not just an undamaged cross or an "empty" playfield.

Maintain a last-observed cell snapshot and a pending cell bitset for **each bank**.
On a glyph or color change, update the background and mark that cell pending for
both banks. Each bank also owns its previous sprite footprints.

For each frame, after the logic tick:

1. Compare cells and update the background and both pending bitsets.
2. In the hidden bank, form the union of its pending cells and the cells covered
   by **that bank's** old sprite footprints. Clip footprints to the game area
   and round outward to cell boundaries.
3. Copy those complete 8×8 tiles from the current background into the hidden
   bank. Deduplicate with a bitset; restore all old sprites before drawing any
   new ones. Each tile is 32 packed bytes spread over eight rows.
4. Draw **all current visible sprites** in the reference priority order. Record
   their clipped bounds as this bank's new footprints. Redrawing all objects is
   deliberately the initial design; it makes overlap handling straightforward.
5. Clear only this bank's consumed pending cells. At VSync display the finished
   bank and select the other as the next hidden bank.

The hidden bank usually contains a frame from two ticks ago. Never restore it
using only the immediately preceding frame's object positions. Never clear the
other bank's pending changes, or copy sprite-contaminated screen pixels into the
background. Mark pending changes even when no render occurs on a tick.

Full invalidation initializes banks and handles scene changes. The hires title
uses its decoded bitmap and suppresses object rendering, matching SDL. Any bank
containing another presentation must be rebuilt before it can be displayed.

### Suggested ownership

| Location | Responsibility |
|---|---|
| `src/archie/main.c` | Startup, scheduling, input → core → render/audio, shutdown |
| `src/archie/video.*` | Mode, palette, bank discovery/selection, present, restoration of OS state |
| `src/archie/render.*` | Background, bank damage, tiles, sprite compositing |
| `src/archie/input.*` | Native key sampling and deliberate application exit |
| `src/archie/audio.*` | Voice snapshots, fixed-point synthesis, native output lifecycle |
| `assets/archie/` | Reproducibly generated target assets derived from existing C64 blobs |
| `tools/archie/` | Asset converter, packaging, local emulator launch, analysis scripts |
| `tst/archie/` | Renderer comparison fixtures and diagnostic/stress harness sources |
| `build/archie/` | Objects, ELF/map, `railgunner,ff8`, app, ZIPs, diagnostic evidence |

Names may be adjusted to keep modules coherent. Do not create a second game core.
If native sound requires ARM assembly, use a target `.S` file and the SDK's
assembler contract; do not put ARM source in a `.asm` file caught by the C64 glob.

## 3. Measurement rules and performance gates

The budget is **20 ms per displayed gameplay frame**, including input, core,
rendering, audio production, and native sound interrupt cost. Waiting for VSync
is idle time, not rendering work. A 50 Hz monitor showing duplicated frames is
not evidence of a 50 Hz game.

Collect counters in memory and print/write them after a measurement interval,
not inside the timed loop. Record configuration, compiler flags, binary identity,
test scenario, duration, logic ticks, presents, missed display deadlines, audio
underruns, changed/restored cells, sprite count, and memory use. Separate stage
timings when the timer supports it. Count VSyncs with a verified mechanism so
missed frames cannot hide behind an average.

`OS_ReadMonotonicTime` is only centisecond resolution. Do not claim reliable
single-frame sub-millisecond or percentile measurements from it. Establish a
verified finer timer/emulator cycle instrument if available; otherwise time large
batches for average work, use VSync/deadline counters for overruns, and explicitly
label tail timing unmeasured. Keep the normal application free of invasive
profiling machinery.

The numerical budgets below are **acceptance targets**, not measured results:

| Gate | Required evidence |
|---|---|
| G0: baseline | Existing core traces pass; reference assets/builds identified |
| G1: video | Distinct checked Mode 9 banks, correct palette/geometry, 50 Hz flip test, safe exit on 2 MB baseline |
| G2: incremental graphics | Pixel-identical indexed output versus full composition; worst synthetic renderer averages ≤8 ms, core+video averages ≤12 ms; no late frames in a 60-second repeat |
| G3: audio feasibility | Three active voices on native output, ≤4 ms average CPU work per 20 ms audio interval including estimated/measured interrupt work; no underruns in a 60-second stress repeat |
| G4: integrated release budget | Total average work ≤14 ms; with fine timing, 99th percentile ≤16 ms and measured maximum <20 ms; no missed deadlines or underruns in each 10-minute stress run |
| G5: release | 2 MB launch/exit/relaunch and gameplay verified; hardware results separately recorded; packaging, fidelity, and regressions pass |

G2/G3 reserve room for each other and scheduling; passing them separately does
not pass G4. Include one workload combining the maximum useful graphics load
with three busy sound voices. Use both reachable late-game states and synthetic
24-object/16-bullet scenes. Synthetic scenes measure frontend capacity and are
not new gameplay requirements or proof of the spawner's behavior.

For G4, coarse timing can establish the average and zero-missed-deadline criteria,
but cannot certify the percentile/headroom figures. Record that limitation and
seek finer instrumentation before claiming those figures. Repeat final tests
with the release build so diagnostic overhead does not distort the conclusion.

If a gate fails, fix the measured bottleneck before proceeding to work that
depends on it. Do not lower the logic rate, hide objects, alter sound priorities,
reduce game content, or call a 25 Hz port complete. Optimize transfer routines,
asset layout, and sound generation first. A fallback mode, reduced audio quality,
or changed hardware baseline that affects fidelity requires an explicit user
decision supported by measurements; routine implementation choices do not.

## 4. Phased execution

### Phase 0 — Baseline, build scaffold, and measurement setup

1. Read the required sources, inspect working-tree changes, and establish the
   current core/SDL/C64 baseline. Run `make core`, build SDL without launching
   unnecessarily, and build the C64 PRG. Preserve unrelated changes.
2. Add an isolated `make archie` build target; retain existing default `make`,
   `play`, `core`, and `sdl` semantics. Add a build-only SDL target if needed for
   verification without opening another session.
3. Detect `ARCHIESDK`, allowing command-line/environment overrides and the local
   installation fallback following Chess. Verify gcc, objcopy, headers, and
   required libraries. Only the requested Archie target fails if unavailable.
   A `make list` target may report C64, host, SDL, and Archie availability.
4. Build C11 core plus a minimal Archie entry with explicit
   `-mcpu=arm2 -msoft-float -mno-thumb-interwork -O2`, warnings, SDK include/library
   paths, dependency files, and a linker map. Use the SDK's actual startup/link
   defaults and `OSLib32` as needed. Do not copy Chess's GNU89 flags into the core.
5. Emit ELF and `build/archie/railgunner,ff8`; keep target objects isolated from
   host objects. Create a private windowed Arculator launch/deployment recipe.
6. Establish measurement resolution, VSync/deadline counting, and memory accounting.
   Prototype a cross-compiled core trace harness if needed to compare ARM results;
   keep it distinct from the normal game executable.

**Exit / G0:** Existing checks pass, minimal target boots and exits, all compiler
and emulator settings are recorded. No graphics or sound performance claim yet.

### Phase 1 — Prove Mode 9 banking and cleanup

1. Save prior display mode, pointer selection, and any state changed by startup.
   Register cleanup early enough to cover partial initialization.
2. Set Mode 9, disable the text cursor and mouse pointer for gameplay, set the
   16-entry RailGunner palette and black border, and verify returned dimensions,
   pixel format, stride, and screen storage.
3. Adapt Time Pilot's checked write/display bank setup to Mode 9. Determine the
   required screen allocation procedure on RISC OS 3.11, including shadow mode
   if applicable. Query bank addresses after selecting them, verify disjoint
   usable ranges and allocation size, and check every relevant SWI error.
   Do not infer bank addresses from a hardcoded legacy base or unchecked return.
4. Draw distinguishable checkerboards and a moving marker into hidden banks,
   flip at VSync, and verify the displayed bank never receives normal rendering
   writes. Test both banks repeatedly, rather than just the first flip.
5. Exercise failure paths, repeated starts, and return to the desktop/CLI.
   Clear gameplay key queues/Escape conditions as appropriate.

**Exit / G1:** 60 seconds of correct 50 Hz flipping on the configured 2 MB
machine, with two distinct banks, correct palette/margins, no tearing/flicker,
and reliable restoration. Report Mode 9 failure before committing to a Mode 13
fallback. A single-buffer diagnostic path may help investigate but is not the
release solution.

### Phase 2 — Assets and a correct full-composition renderer

1. Decode the existing charset, hires title/color bytes, sprite pointer table,
   all four player frames, and embedded cargo disc. Derive target assets from
   the same `.bin` products SDL uses, preserving glyph and pointer IDs.
2. Build deterministic host conversion rules with complete prerequisites and
   no timestamps in generated payloads. Embed target data so runtime requires
   no source-tree paths or loose C64 assets. Rebuilding after an art change must
   regenerate the relevant target data automatically.
3. Implement a simple complete indexed frame composition as the visual oracle,
   initially on host buffers. Preserve hires-title interpretation, foreground
   and background colors, multicolor transparency, sprite color selection,
   player animation, priority, and slot tie order from `src/sdl/blit.c`.
4. Implement Mode 9 packed writes, including both X parities, clipped edges,
   byte-edge preservation, and safe alignment. Never perform an unaligned ARM2
   word access. Initialize the physical margins separately.
5. Establish a host comparison path that maps SDL's pre-scaled pixels back to
   the 16 color indices. If a small SDL reference-rendering helper is needed,
   keep its extraction narrow and preserve the existing SDL image and audio.

**Exit:** Every sprite/frame/color/parity and title/charset fixture matches the
reference indices at 320×200; native screenshots match after expected palette
quantization. This renderer is a correctness oracle, not the final full-screen
per-frame strategy. Record its target cost as a baseline.

### Phase 3 — Incremental background and per-bank sprite restoration

1. Implement the background, cell snapshot, two pending bitsets, and two sets
   of old sprite bounds described above. Build each bank's restore union using
   bounded storage; a cell bitset avoids rectangle-list overflow entirely.
2. Restore tiles with aligned word transfers where valid. Start with generated
   glyph masks or a compact row lookup; avoid a large all-glyph/all-color cache
   unless measurements justify its memory cost. Coalesce adjacent tiles into
   row spans only if useful and still correct.
3. Implement masked sprite compositing, with fast interior and safe clipped
   paths. Precompute masks/pixels or parity variants as measured; preserve
   variable object colors and both multicolor shared colors.
4. In host tests alternate the two bank buffers, and compare the completed bank
   against the full compositor after **every frame** of deterministic sequences.
5. Cover moving, unchanged, overlapping, disappearing, color-changing, and
   frame-changing objects; slot reuse; every screen edge; negative origins;
   bullet phase/cell changes; rail damage and repair under a sprite; mine changes;
   score/banner recoloring; changes accumulated while a bank is unused; return
   to earlier presentation modes. Verify no writes outside the framebuffer.
6. Force repeated scene invalidation and both first-use bank paths. Measure
   realistic play plus all visible object slots and bullet slots.

**Exit / G2:** Frame comparisons pass and the graphics budget is met on the
target. No bank has a trailing sprite, stale bullet, or damaged rail restored to
its former appearance. Routine static frames perform no full-screen clear/copy.

### Phase 4 — Native audio feasibility before full game integration

1. Inspect RISC OS 3.11/SDK sound interfaces and Time Pilot's sound integration,
   including buffer ownership, module lifetime, sample rate, output encoding,
   and interrupt restrictions. Write the chosen transport and its limits into
   the execution record before building around it.
2. Prefer continuous buffered output driven by the three published core voices,
   through an existing supported interface or a small native sound voice module.
   THSound is usable only if its verified capabilities fit this purpose. Installing
   short samples repeatedly at 50 Hz is not an assumed streaming solution.
3. Implement an integer synthesizer preserving pulse/triangle/saw/noise, pitch,
   pulse width, gate, generation-based retrigger, ADSR behavior, and mixing.
   Replace SDL's floating-point envelope math and per-SID-clock loops with
   fixed-point/block techniques. Keep phase/noise state across buffers and advance
   the SID noise recurrence at the correct oscillator crossings.
4. Select and measure a native sample rate/encoding supported on the baseline.
   Compare at a common rate against the SDL synthesis reference; quantify pitch,
   envelope, output-level and waveform/noise differences. Native DAC precision
   is a known constraint to document, not a reason to substitute different cues.
5. Publish complete coherent snapshots after `sim_tick()`. Advance samples in
   the audio transport, not the sequencer. Bound queued audio latency to a target
   of at most two logic frames (40 ms), excluding separately reported hardware
   latency, and avoid clicks or phase resets at every game tick.
6. No allocation, file I/O, blocking SWIs, or unbounded work in an audio interrupt.
   If foreground refill is used, measure its deadline under rendering load.
   Define underrun recovery and snapshot handoff without assuming SDL mutexes.
7. Validate three-voice title passages, all effect steps, pitch slides, release
   tails, simultaneous effects, voice stealing, and music resumption. Standalone
   silence and shutdown tests must leave no dangling buffer/module references.

**Exit / G3:** Native output runs continuously, meets the audio CPU budget, and
preserves the sound sequence and recognizable timbre. Record sample rate,
encoding, buffer sizes, latency, CPU cost, and comparison evidence. Do not proceed
to full integration with an unresolved transport. Prerecorded whole effects or
music are not the default: they must first demonstrate correct interruptions,
voice stealing, slides, and resumption, or be presented for a user decision.

### Phase 5 — Full frontend, input, and 50 Hz scheduling

1. Connect native input to the existing core inputs: cursors/WASD, Space, S, I,
   and Escape as RUN/STOP. Preserve core edge detection and held-key behavior;
   S remains both a title shortcut and downward movement as in SDL.
2. Define a separate documented way to exit the application without changing
   Escape's gameplay meaning. Do not add pause or other game modes. Joystick
   support is optional follow-up, not a prerequisite or reason to delay keyboard
   parity.
3. Implement the steady loop: sample input, one due tick, publish sound state,
   update background, prepare hidden bank, and present at the next appropriate
   VSync. Enable/disable any SDK VSync facility according to its verified contract.
   Measure cadence to avoid inadvertently waiting twice and running at 25 Hz.
4. Keep real-time audio output alive across missed rendering frames. Drop logic
   backlog as specified by the core port record. Record misses; never quietly
   compensate by multiple logic ticks per display frame.
5. Wire all existing modes: hires title, text title, story, instructions, new
   game/deploy, play, banner, both death paths, tally/game over, and initials.
   Invalidate banks on full scene replacement even when the `present` flag is
   still `PRESENT_TEXT`; transitions must not retain old object footprints.
6. Process full scene rebuilds in hidden storage. Keep the last complete frame
   visible until a rebuild can be displayed. Measure transition costs and avoid
   freezing audio or advancing attract/typewriter/game timers at the wrong rate.
   If scene changes miss a display deadline, record them separately and optimize
   them before acceptance rather than concealing them in play averages.

**Exit:** The whole game runs through every mode, input agrees with SDL for the
same sampled sequence, and no presentation path exposes an unfinished buffer.
Core traces still pass; target state comparisons use field serialization rather
than raw `Game` memory, whose pointers/padding are host-dependent.

### Phase 6 — Integrated stress, optimization, and fidelity acceptance

1. Create repeatable diagnostic scenarios outside production gameplay: maximum
   visible sprites with overlap/clipping/parity variation; 16 animated bullets;
   simultaneous HUD/color updates; damaged rails and repairs; title with all
   voices; gameplay effects on three voices. Include a combined graphics+audio
   worst case and actual late-game/death/level transitions.
2. Run each scenario for 10 minutes on the baseline emulator configuration with
   audio enabled. Report averages, tail timing when measurable, VSync misses,
   underruns, restore traffic, and memory. Run representative real play too.
3. If a gate fails, identify costs by stage. Optimize the largest contributor
   first: tile transfer/coalescing, sprite masks/layout, avoidable decode work,
   integer synthesis, or interrupt/refill strategy. Inspect generated ARM code
   for alignment, division and software floating-point helpers. Add assembly
   only for a measured bottleneck with a retained correctness reference.
4. Re-run the affected frame/audio comparisons after each optimization, and
   repeat the combined budget check when its implementation changes. Do not
   broadly rewrite core logic to save frontend cycles.
5. Audit memory from linker map plus runtime allocations: app slot/stack,
   generated assets, background/cell histories, display banks, RMA sound storage,
   module footprint, and OS headroom. Nominal Mode 9 banks total 81,920 bytes and
   the packed game background is 32,000 bytes, before allocation rounding and
   all other storage. Screen storage and RMA are not covered by the app slot.
6. Verify palette quantization and display aspect visually, and compare audio
   listening captures as well as numerical checks. Preserve the pixel layout;
   document unavoidable hardware color/DAC differences explicitly.

**Exit / G4:** The integrated budget, correct frame composition, sound behavior,
and 2 MB memory requirement pass. A faster emulator setting or a silent run is
not a substitute. Keep performance evidence tied to the exact tested build.

### Phase 7 — Package, hardware validation, and handoff

1. Produce `!RailGunner` with launcher, application icon, executable, and any
   required sound module/data/licences. Set a measured adequate Wimp slot with
   stack/headroom; do not copy Time Pilot's 640 KB value without checking.
   Avoid global installation requirements where possible.
2. Build `RailGunner-HostFS.zip` with comma type suffixes and
   `RailGunner-RISCOS.zip` with native Acorn ZIP metadata, following the reference
   packagers. Verify archive integrity, file types, launcher paths, and extraction
   in RISC OS. Exercise normal launch from a clean packaged directory.
3. Test clean launch, repeated exit/relaunch, missing sound support, and partial
   initialization failure. Optional silent operation is useful for diagnostics
   but does not satisfy the sound acceptance gate. Restore changed OS sound
   settings and release storage only after callbacks/voices have stopped.
4. Validate on an actual A3010 with 2 MB/RISC OS 3.11: title sound, busy play,
   sprite overlaps and rail restoration, keyboard response, deaths, rank banner,
   game over/initials, and return to the OS. Check flicker, tearing, sustained
   cadence, sound crackle/latency, and long-session behavior.
5. If hardware is unavailable, complete emulator/package work and mark hardware
   acceptance pending. Provide a short reproducible hardware test procedure to
   the user; never report hardware verification from emulator results.
6. Update `agents/README.md`, `repo-layout.md`, and user build/run documentation
   to describe the actual port. Keep this plan's ledger and evidence current.
   Run `make core`, the C64 build, SDL build, Archie build, renderer/audio checks,
   and package verification on the final source state.

**Exit / G5:** Deliver the application and both ZIPs, build/run instructions,
measured performance/memory report, fidelity notes, and explicit validation
status. Declare hardware acceptance only after the actual hardware check.

## 5. Gate failure and execution record

Use this ledger while executing. Change a row to complete only when its exit
evidence exists. Record evidence under `build/archie/` and summarize durable
results here, including configuration and reproducible commands. A benchmark
failure is work to resolve, not an automatic request for permission. Ask the user
only when a concrete fidelity/hardware tradeoff or unavailable external input
prevents the agreed outcome.

| Phase | State | Evidence / remaining issue |
|---|---|---|
| 0 Baseline/build/instrumentation | Complete — G0 | `make core`: 13 traces pass; `make prg`, `make sdl-build`, `make archie` pass. Native diagnostic boots/exits. SDK GCC 8.5.0, ARM2/C11/O2/software float. Private Arculator 2.2 A3010/ARM250/2 MB/RISC OS 3.11/normal speed. |
| 1 Mode 9 banks — G1 | Complete — G1 | Two disjoint banks `0x1fd8000`, `0x1fe2000`; 320×256, stride 160, 4 bpp; allocation **163,840 bytes**. Latest repeat: 3,010 logic ticks/presents/VSyncs, zero misses, **6,010 centiseconds**. Returns to OS; checked allocation/bank/palette/pointer restoration succeeds. Palette readback matches quantized SDL RGB. `build/archie/evidence/G1-60seconds-report.txt`. |
| 2 Assets/full reference renderer | Complete — renderer correctness | Deterministic embedded SDL assets. `make archie-test`: 10,161 frames match full scalar composition and unchanged SDL indices under ASan/UBSan; pointers/colors/parity/player facings/title/clipping covered. Final native scalar/assembly comparison passes 256 scenes, including actual text-title ticks and all sprite frames. |
| 3 Incremental renderer — G2 | Accepted to proceed by user | Final host 10,161 comparisons and native 256 audits pass. User-approved 24-sprite synthetic batch: **7.79 ms graphics**, **8.30 ms core+graphics**. 3,050 presents over 60.46 seconds, **one missed VSync**. User approved progression with this limitation; see decision below. |
| 4 Native audio — G3 | Transport/fidelity complete; user approved budget progression | 2,251,800 host samples: exact phase/noise, max error 3 signed-16 units. Native 128-block audit passes. 60.90 seconds: zero underruns and VSync misses. Latest representative production batch 6.84 ms/interval; original 4 ms allowance exceeded. |
| 5 Complete frontend | Complete on baseline emulator | Native SDL-equivalent controls, Ctrl-Q exit, unchanged core dispatch, coherent sound snapshots, two banks, and audible game loop. Short actual play test has zero routine misses/underruns; two initial full-scene misses. |
| 6 Integrated performance/fidelity — G4 | User accepted available evidence; rare misses retained | Three 30,500-frame audible runs: title 97 misses/611.00 s; seeded level-15 play 49/610.13 s; eight sprites 2/609.18 s. All zero underruns and checked cleanup. 24-sprite short test: 1,100 frames, zero misses/underruns. Strict zero-miss gate is not claimed. |
| 7 Packaging/hardware/handoff — G5 | Emulator/package delivery complete; hardware pending | !RailGunner and both ZIPs generated, archive/file type/Acorn metadata checked. Clean packaged guest launch, Space starts play, Ctrl-Q returns to OS. Hardware, native ZIP extraction and failure injection remain unverified. |

The critical order is **banking proof → correct renderer → incremental graphics
gate → native audio gate → full integration → combined performance gate →
release validation**. Do not spend the bulk of the port on menus and packaging
before the two performance risks have working, measured solutions.

### Current reproducible execution

See `src/archie/README.md`. `make archie-run` launches a private windowed emulator;
open HostFS and `!RGDiag`. Use `Diagnostic graphics` for G2. Host correctness is
`make archie-test`. Native reports are under
`build/archie/arculator/hostfs/!RGDiag/`; retained binaries, maps and disassembly
are under `build/archie/evidence/`. Centisecond timing supports batch averages
only; tail timing remains unmeasured. Native sound has not been substituted
with prerecorded cues. G2 progression is user-approved with rare synthetic misses documented below.

### SDK diagnostic limitation

The installed SDK's `SDK/src/libc/string/memcmp.c` advances only its second
pointer. Disassembly confirms the first byte is repeatedly compared. Native
pixel audits use explicit volatile byte reads, and captured reference/fast
buffers independently matched on the host. The SDK installation is unchanged.
Do not use its `memcmp` as a renderer validation oracle.

### User-approved G2 progression (2026-10-10)

The user explicitly approved moving on from G2 despite rare missed VSyncs in
the 24-sprite synthetic test, noting that real play rarely exceeds eight sprites.
Retained `graphics-lategame-report.txt`: 7.79 ms graphics, 8.30 ms combined
with live level-15 core, 3,050 presents over 60.46 seconds, one missed VSync,
128 native scalar audits. This is acceptance to proceed, not a zero-miss claim.
Combined evidence and the subsequent user-directed measurement stop are recorded below.

### Phase 4 transport decision

Use a small position-independent RISC OS native sound voice generator in RMA,
attached to one physical channel. Foreground synthesis mixes all three core
voices into a bounded 1,024-byte ring; the sound callback only copies encoded
bytes, counts empty reads, and outputs silence on underrun. No allocation,
SWIs, file I/O, or application pointers in its interrupt path. Target configuration:
one channel, 208-byte DMA buffer, 48 microseconds/sample (approximately
20.833 kHz), VIDC logarithmic 8-bit encoding through a startup conversion LUT.
Query actual configuration, retain phase across refills, initially target 30 ms queued
audio (later increased to 40 ms for combined load), and report hardware buffer latency separately. Save and
restore prior configuration, channel attachment, enable/speaker/volume states;
detach and remove the voice before releasing its RMA storage. Validate integer
synthesis against unchanged SDL code at a common rate before G3.

### First native audio measurement

The bounded callback completes and checked sound/video restoration succeeds.
At 48 us / about 20.833 kHz, 1,000 intervals of 416 samples with three
high-frequency noise voices plus encoding cost **21.44 ms per interval**.
A short 100-frame transport repeat records 34,736 empty sample reads and
101 missed VSyncs over 3.99 seconds. G3 fails; optimize synthesis before full
integration. Callback DMA length 208 and stride 1 are verified. Native R8 is
`0x003000d0` (period 48 in high half, length 208 in low half), so retain it as
a raw callback configuration word, rather than mislabeling it microseconds.
Host comparison expanded to 2,251,800 samples including actual title/effect
sequencers, steals and resumption: phase/noise exact; max error 3 signed-16
units, mean 0.699. ELF text/data/BSS total 727,408 bytes including SDK stack
reservation; current app slot 786,432 bytes, RMA and screen storage separate.

### User-approved audio budget progression (2026-10-11)

The user selected “Prioritize full game and total frame budget”. Continue full
frontend integration and judge the total 20 ms frame budget; the standalone
4 ms audio allowance is exceeded and remains explicitly recorded. At that decision,
`audio-cache-report.txt` recorded: 7.14 ms production per 416-sample interval, 128 native
scalar audit blocks, 100 frames in 2.00 seconds with zero misses/underruns and
checked cleanup. Earlier `audio-60seconds-report.txt` proves 3,050 frames over
60.90 seconds with zero misses/underruns. No fidelity substitution was made.

### Full-loop integration measurements

Native SDL-equivalent controls and Ctrl-Q exit are wired to the unchanged core.
The first 3,050-frame audible integration run recorded 228 VSync misses and
47,424 empty sample reads; this was not accepted as G4. Subsequent stage
measurements identified periodic text-title score recoloring. Invisible color
changes on blank glyphs no longer damage either bank; the bulk rebuild threshold
is raised from 128 to 768 visible changed cells and full pending banks use an
aligned whole-frame transfer. The expanded host test includes 1,000 actual text
title ticks and blank recoloring: 10,161 frames pass unchanged SDL indices under
ASan/UBSan. Audio remains continuous; short tests now have zero underruns.
`integrated-key-asm-report.txt` still records 36 missed VSyncs in 1,100 frames;
this historical result was superseded by the final combined tests below. Profiling SWIs are disabled in the
production loop; scenario 4 retains intrusive coarse stage profiling. Native
key and bank presentation routines use the same checked OS_Byte contracts,
avoiding general-purpose wrapper overhead.

### Combined short tests before long repeats

`integrated-short-railgunner,ff8` and matching ELF/map identify this build.
1,100-frame repeats: actual initial-level play 22.01 seconds, two cold scene
misses, zero underruns; eight-sprite and 24-sprite synthetic graphics with
continuous three-voice sound each 21.96 seconds, zero misses/underruns. Title
profile averages 10.45 ms work (1.53 ms input/core, 6.54 ms audio, 2.38 ms
render), with instrumentation overhead and four scene/timing misses; no fine
tail claim. Batched dirty glyph painting removed recurring menu recolor misses;
256 native scalar pixel audits passed. Long repeats use 30,500 frames per
scenario, production timing (no per-frame timer SWIs), seeded level-15 real
play, and per-scenario reports. The 896 KiB slot holds a 745,696-byte ELF
footprint including SDK stack reservation; 163,840-byte screen allocation and
about 1.3 KiB RMA sound storage remain separate.


### Final delivery and user-directed measurement stop (2026-10-11)

The user judged the collected data sufficient and requested moving on. No further
performance tuning or long runs are required for this delivery. Retained
`long-G4-title.txt`, `long-G4-actual.txt`, `long-G4-eight.txt` refer to
`integrated-soak-railgunner,ff8` and its matching ELF/map. All three runs have
30,500 frames, zero empty sound reads and checked cleanup. Title missed 97
VSyncs (20 full-scene, 77 routine); late-level play missed 49 (39 full-scene,
10 routine), with five peak sprites; eight-sprite stress missed two. These
are accepted limitations, not a strict zero-miss G4 result. The remaining
24-sprite long run was not retained as completed; its 1,100-frame short check
passed without misses or underruns. Coarse profiling averages 10.45 ms total
work; production tests do not measure fine percentiles or maximum CPU time.
Latest standalone sound production batch is 6.84 ms per 416-sample interval.

Final footprint: 745,696 bytes ELF text/data/BSS including SDK 64 KiB stack,
896 KiB application slot, 163,840 bytes screen allocation, about 1.3 KiB sound
RMA. Baseline 2 MB allocations succeeded. Deliverables live under
`build/archie/release`: !RailGunner, RailGunner-HostFS.zip,
RailGunner-RISCOS.zip and SHA256 manifest. The HostFS application was launched
from its packaged launcher in a clean booted guest, entered play with Space,
and returned to the OS with Ctrl-Q; a second launch/exit also passed. Archive contents and Acorn metadata are
validated on the host; native ZIP extraction, listening captures, injected
missing-module/partial-initialization failures and actual hardware remain
unverified. See `src/archie/README.md` for the hardware procedure.

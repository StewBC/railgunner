# IIgs beam renderer results — 2026-10-18

## Outcome and acceptance limits

The implementation now schedules immutable region restoration/redraw behind the
beam, following Time Pilot's ordering principles. It removes the long foreground
service interruptions between erasure and dependent drawing. Accelerated test
runs show no possible scan-time exposure under conservative transaction bounds.
This is an implemented renderer repair, not the preceding cleanup-only work.

**The full requested acceptance target is not established.** The 14.3 MHz run
exceeds 30 presentations/sec and has zero exposure violations, but is not locked
30 Hz.7.159 MHz is scan-stable in the tested workload but below 30 presentations/sec.
2.8 MHz remains too slow and has potential scan exposure. Natural gameplay reached
six visible objects at the accelerated speeds, not the requested 8–10. Synthetic
10-object stress is reported separately. Real hardware/user visual acceptance
remains outstanding. No simulation speed, collision rule, art, or audio was changed.

## Ordinary gameplay: measured wrap-correct executable

All runs use a private **windowed** GSSquared ROM3, physical NTSC timing, the same
level 9 late-half seed, and continuous held fire through shipping native gameplay.
Each retained interval lasts 60 physical seconds; the rate denominator below is
only adjacent sampled PLAY endpoints, excluding frontends. The scene was not busy
for the whole interval. The player dies/respawns and ultimately leaves PLAY.

| MHz | Logic ticks/s | Completed presentations/s | Dropped PLAY ticks | Exposure violations / region transactions | Longest restore/redraw bound | Worst adjacent changed-PLAY completion gap | Sampled PLAY seconds |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2.8 | 59.474 | 5.154 | 13 | 19/1823 | 19.30 ms | 499.37 ms | 30.27 |
| 7.159 | 59.956 | 18.666 | 0 | 0/7120 | 6.69 ms | 93.12 ms | 33.11 |
| 14.3 | 59.923 | 35.321 | 0 | 0/13570 | 4.78 ms | 36.88 ms | 34.14 |

Exposure and maximum timing counters cover the full unpaused run, including
ordinary non-full frontend updates; rates are PLAY-only. A nonzero conservative
exposure bound is not proof of the exact intermediate pixels scanned, but it
prevents claiming scan-time safety. Zero violations prove every bracketed region
finished before its next scan under this instrumentation.

The maximum gap excludes unchanged candidates and deliberate full-screen blank
transitions, which reset the busy cadence chain. It is measured at actual completed
candidates, not inferred from the host's 250 ms polling interval. The old coarse
`longest_sampled_presentation_gap_seconds` field remains for compatibility and
must not be mistaken for this measurement.

Exact gap histogram (ceiling of gap/262 physical lines; bin 16 means 16 or more):

- 2.8 MHz: `[0, 0, 0, 0, 1, 12, 18, 10, 16, 10, 19, 20, 10, 8, 4, 27]`.
- 7.159 MHz: `[0, 61, 256, 260, 42, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]`.
- 14.3 MHz: `[182, 785, 249, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]`.

Stage maxima retained during the first sampled PLAY episode (preparation includes
bounded live-logic service; presentation includes region waits and safe-boundary
service, so these are not isolated kernel costs):

| MHz | Preparation max | Presentation/wait high-water (may include warmup) | Logic call max | Sampled visible-object peak |
|---:|---:|---:|---:|---:|
| 2.8 | 192.10 ms | 343.95 ms | 11.66 ms | 4 |
| 7.159 | 37.45 ms | 49.87 ms | 4.78 ms | 6 |
| 14.3 | 14.14 ms | 20.45 ms | 2.42 ms | 6 |

The profiled images at all three speed settings have identical machine code;
speed is emulator configuration, not a distinct gameplay implementation. Profiled
binary SHA256: `5e50d9438698423d7954159f6f384506b0dfa8e3e71f451f30f0c0e93ed667f1`.

## Separate synthetic ten-object stress

The final 14.3 MHz executable completed 33.849 presentations/s
with 59.922 logic ticks/s and 0 dropped PLAY ticks.
There were 0/11081 exposure violations;
worst changed-PLAY completion gap was 50.19 ms.
The sampled visible-object peak was 8.
The 10-object state is explicitly seeded, uses actual game objects/handlers,
and does not stay at 10 for the entire run. Its object-count histogram is in
`wrapstress14/continuous-profile.json`. It is not evidence of natural sustained
8–10-object play. The earlier 7.159 MHz synthetic test also had zero exposure
violations, but used the predecessor binary before the final modulo-wrap fix;
its own hash and measurements are retained in `finalstress7/`.

## Why the scan-time evidence is stronger than a final screenshot

`beam_trace_begin/end` bracket every region's stores with the coherent 32-bit
physical clock and raster line. They include interrupt time and mapping restoration.
For region topT, the next scan deadline is `(T - start_line) mod 262`; starting
inside the region is unsafe. Completion must precede that deadline. Sampling
across wrap does not grant an extra refresh. Cumulative counters cover every
transaction; the 128-record ring is retained as additional boundary evidence.

The scheduler itself computes `(line - bottom) mod 262` and releases in its
first 128 lines. Lower regions retain their valid window through wrap. Preparation
remembers the next absolute crossing of physical line 200, so late work never
causes an unnecessary new full-refresh wait. Native tests cover these boundaries,
pending-candidate preservation, wrap during sampling, and safe/unsafe deadlines.

The display is composed of disjoint eight-row transactions. Within each, all
background work precedes all sprites in stable layer/slot order. This makes a
moving overlapping pair plus a changing rail safe without a full-screen overlap
closure: a later transaction never writes an earlier transaction's rows.

## Verification

- Native scheduler:31 arithmetic/boundary assertions passed in assembled code.
- Native clock: deadline/drop/wrap self-test and 55 coherent fast-path assertions passed.
- Sprite compiler:41,664 original-art/mode/parity/row/color combinations passed.
- Final-image scene suite:23 cases passed, including changed rails/glyphs/HUD,
  overlap, clipping, appearance/disappearance, transitions,24 slots and 24-slot removal.
- Real keyboard smoke: native navigation, movement/fire, key release, black C022
  transitions, completed play pixels, Ctrl-Q and input cleanup passed.
- Real compiled/clipped fragment diagnostic: 1,940 calls across 36 scenes passed,
  with zero ABI or pixel failures. Maximum traced IRQ-off duration at 2.8 MHz
  was 18,607 master ticks (1.30 ms); this is an observed bound, not a universal WCET.
- Caller restoration: patterned, distinct bank01/E1 images, CPU/display state,
  input ownership and post-QuitGS checks passed.
- The unpaused timing reports independently compare 32,000 completed framebuffer
  bytes against the host oracle and verify publication of that exact candidate.

The exact final real-input executable passed `wrapscene` and `wrapsmoke`.
The patterned lifecycle and fragment diagnostics use the predecessor binary
before the final modulo-wrap fix. Their source paths were unchanged by that fix;
the reports retain their own exact binary hashes. Do not substitute those hashes
for the final profile hash above.

## Evidence and reproduction

Retained under `build/iigs/beam-evidence/2026-10-18/`:

- `index.json`: reports and exact tested hashes.
- `wrap14/`, `wrap7/`, `wrap2/`: session metadata, native binaries, physical-time
  reports, seed state, trace ring/bad-bound records, independent pixel captures.
- `builds/`: frozen generated assembly, generator snapshots and matching manifests.
- `wrapscene/`, `wrapsmoke/`: final shipping-binary regression evidence.
- `finallifecycle/`, `finalsprite/`: patterned restoration and fragment evidence.
- `unit-tests/`: assembled clock and scheduler self-tests, wrappers and logs.
- Stress runs are explicitly synthetic, and their actual object-count histories
  remain in each report. Do not describe them as a sustained natural 10-object run.

Build normally with `make iigs-game IIGS_GAME_SPEED=14.3mhz`. For measurements,
run `native_specialized_build.py` with `--profile --fixture-input --held-fire`,
launch it through `native_probe.py` with matching binary/manifest/source and speed,
then use `native_continuous_profile.py --session ... --seconds 60 --level 9 --mid-level`.
`--stress` is the separate synthetic ten-object test. Every diagnostic VM owns
private media and is closed by its test; sibling repositories and their media
are read-only. No headless emulator is used.

## Remaining acceptance work

Stock-speed rendering still needs a substantially cheaper plan/draw path or
smaller dependency-safe transactions. Preserve late immutable completion: do not
replace these shortcomings with predicted whole-frame rejection. The current
region bound is not a universal guarantee for arbitrary 24-slot overload.

Tighter 30 Hz cadence and natural 8–10-visible-object evidence remain unproven.
The profiler's `pass` is a scan-plus-throughput sanity gate; it explicitly does
not certify those missing requirements or real hardware acceptance.

## Subsequent frontend, formatting and packaging follow-up

The timing tables above describe the frozen beam-repair build, before the later
frontend change; they are not new measurements of the final packaged image.
The user reports good gameplay at 7.159 MHz and unplayable 2.8 MHz. Treat
7.159 MHz or faster as the practical target, retaining the acceptance limits above.

Cadius source formatting exposed whitespace-sensitive generator substitutions.
Checked assembly anchors now tolerate spaces/tabs, preserve quoted data and label
columns, and reject missing/duplicate matches. Seven regression tests passed;
the formatted beam-repair binary was byte-identical to its pre-format reference.

The shipping high-score table now has a light-grey base and one yellow moving
row. The original ten-tick cadence remains; each step writes two rows. Native
execution passed 611 assertions for cadence, row count, colours and wrap. The
7.159 MHz windowed twelve-step test used the preceding cyan-colour version:
every step changed exactly 80 cells in two rows, including wrap, with zero
completed-pixel mismatches. Input/fire, black transitions and Ctrl-Q cleanup
also passed. Those reports/screenshots are in `build/iigs/highscore-color-evidence/`.
The final cyan-to-yellow constant change passed the native 611-assertion suite;
no new scan-time or hardware claim is implied by the colour-only test.

Final yellow-highlight executable SHA256: `be450fbe57901b3022ee2d94f811b035ba1090c35f45ddce11798a9655921cf4`.
Packages are `railgunner-iigs.2mg` (private GS/OS boot image),
`railgunner-iigs-transfer.2mg`, and `railgunner-iigs-800K.po` (non-bootable raw
ProDOS-order transfer floppy, exactly 819,200 bytes). All three volume checks
and extracted-executable byte comparisons passed. The package manifest records
hashes under `build/iigs/native-game-package/`. Speed selection changes emulator
configuration and metadata only; the executable is identical across settings.

# Native IIgs input handoff

Tool9 owns the firmware IRQ path. `src/iigs/input.asm` is a native16
foreground component (DBR=PBR, D preserved); callback enters M=X=8 and saves
physical A/X/Y, DBR, D and P, returning with CLC/RTL after restoring P.

`input_init` reads configured keyboard address and saves mode bit0, then disables
autopoll using only that bit. `input_poll` submits one asynchronous register0
request, publishing pending before the call. Busy means nonacceptance; ambiguous
errors retain pending and callback storage. `input_snapshot` briefly masks IRQs
to copy the 16-byte held map; faults produce neutral sampled input.
`input_decode` maps arrows/WASD, Space, S, I, Escape and Ctrl-Q into word outputs
`input_dirs_value`, `input_fire_value`, `input_key_s_value`, `input_key_i_value`,
`input_runstop_value`, `input_leave_value`. Direction bits are 1/2/4/8. Core input
edge detection remains separate. Call these services outside renderer blackout.

`input_close` stops new requests and returns zero only after pending completion,
restoration and Toolbox verification of original autopoll bit, and matching
ADBShutDown. A nonzero return requires retaining callback code/data and retrying
with IRQs enabled. Never unload on an arbitrary timeout.

The address record follows Apple's Volume3 chapter26 erratum: byte0 low nibble
keyboard/high mouse, byte1 layout/language, byte2 repeat. Volume1's order is wrong.
The actual ROM completion buffer uses N-1 (zero means no packet) and stores data
in reverse wire order; traverse from N down to1. This agrees with the descending
sample loop in Volume1 printed3-8, despite its prose description. Ignore FF
padding, handle7F7F power packets separately, and preserve packet event order.

Read-only configuration probe returned address/layout/repeat `32 00 24`.
The historical13-check component proof was in
`build/iigs/native-adb/input-proof/` (retired build outputs moved outside the tree;
see `iigs-cleanup.md`; the component tests remain reproducible). The subsequent 21-check mapping proof in
`input-map-proof/` also verifies WASD, start, instructions and Escape mappings.
Five injected-status ownership/error tests additionally pass in
`build/iigs/native-adb/fault-proofs/`. These simulate returned status, not actual
hardware failures. The ambiguous pending condition is fabricated only after the
real callback completes; its eventual test-only release is not cancellation.
The 22-check `input-mode1-proof/` additionally starts with modes `$11`:
autopoll already disabled and an unrelated mode bit set. Component cleanup
preserves both bits, and test-fixture cleanup restores the caller’s original
mode. These functional proofs use actual ROM callbacks at2.8MHz, simultaneous holds, independent releases,
modifier ordering, duplicate downs, fully drained short taps and a submitted
callback before quit. Saved modes are reread before ADBShutDown. Real-input gameplay smoke now passes. Revised beam scheduling must recheck
service latency and blackout interaction; physical hardware acceptance is pending.

Matching GSSquared aff788b only refills its two-byte keyboard register inside
ADB_Keyboard::process_event, not Talk. Three host key events before a poll strand
the third queued event until another SDL event; failed evidence is retained at
`/tmp/railgunner-iigs-m5w_ct3y/`. Mapping tests serialize three independent releases
rather than claim this burst passes. Do not change the sibling emulator repository
or add fake guest events as a runtime workaround. Validate burst behavior on real
hardware. Original IIgs keyboard keycodes are tested; other keyboard handlers
need hardware validation, with WASD available independently of arrow layout.

Primary references: Apple Toolbox Reference Volume1 chapter3 and Volume3
chapter26 (26-2 erratum). Copies were inspected from the Asimov mirror:
https://mirrors.apple2.org.za/ftp.apple.asimov.net/documentation/programming/65816_gs/
The Volume3 file there is named `Apple IIGS Toolbox Reference Volue 3 part 1.pdf`.

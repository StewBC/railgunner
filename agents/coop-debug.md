# Cooperative live debugging (agent handoff)

**Role:** How a **coder agent** and a **human player** debug intermittent
RailGunner bugs together using the c64m control port — freezes, evidence packs,
watchpoints, and chat. No c64m source edits required.

**Companions:** [`build-debug.md`](build-debug.md) (control port basics),
[`README.md`](README.md) (repo boundary — do not patch `../c64m/`).

**Tools:**

| Path | Role |
|------|------|
| `tools/coop_debug_rg.py` | **RailGunner entry** — coop_watch + symbols from `build/symbols.txt` |
| `tools/coop_watch.py` | Symlink → `../c64m/tools/coop_watch.py` (generic daemon) |
| `tools/c64_control_client.py` | Symlink → c64m `Ctl` client |
| `build/debug/snap-NNN.txt` | Evidence pack written on every freeze |
| `build/debug/coop_inbox` | Agent → daemon command channel (append lines) |

---

## 1. Topology (why one session holds the socket)

```
  Human (plays + chat)          Coder agent (this session)         coop_debug_rg
         |                              |                                |
         |  play / pause key            |                                |
         |  describe glitch in chat --->|                                |
         |                              |  read snap-NNN.txt             |
         |                              |  echo 'arm …' >> coop_inbox -->|
         |                              |  echo resume >> coop_inbox --->|
```

- **One process holds the control socket** and runs the `wait-paused` loop:
  `tools/coop_debug_rg.py`.
- That process is **not** a subagent with a separate chat. The **coder agent**
  (main conversation with the human) steers it by **appending lines** to
  `build/debug/coop_inbox` and by **reading** `build/debug/snap-*.txt`.
- Do **not** spawn a subagent solely to hold the socket and expect human chat to
  reach it — steers would need an explicit relay and lose “still frozen, still
  looking” immediacy.

**CTRL-ENTER / human chat** = free-text description *after* pause.  
**Pause key** = freezes the machine so history, the **frame ring**, and the
**VIC ring** are still meaningful. A pause one second late is ~50 PAL frames
past a one-frame glitch — the flight recorder still has the bus traffic, the
frame ring still has the pixels (~16.5 s default), and the VIC ring still has
per-line latched sprite X (~10 s default). Scrub before assuming the glitch
is gone.

Protocol stack (c64m): **C64M/6** — history (C64M/3) + guarded `when=` (C64M/4)
+ frame ring (C64M/5) + VIC ring (C64M/6). Details:
[`build-debug.md`](build-debug.md) §§6.5b–6.7c.

---

## 2. Prerequisites

```bash
# From RailGunner repo root
tools/build-prg.sh                  # refresh build/symbols.txt for regions
```

Symbols drive which ZP/pool addresses appear in every snap. Stale symbols →
wrong dumps after layout changes.

Human pause key: whatever the c64m frontend debugger uses (user knows it;
confirm in c64m `agents/frontend-debugger.md` if unsure).

---

## 3. Launch a coop session

### Preferred: one command

```bash
make coop
# same: tools/coop.sh
```

This will:

1. `make prg` (fresh PRG + `build/symbols.txt` for region dumps)
2. If port **6510** is free: start windowed c64m with `--control-port`, `--prg`,
   `--autorun` (game boots; you play from title)
3. Run `tools/coop_debug_rg.py` in the **foreground** (owns the control socket)

Env: `C64M_PORT` (default 6510). If the port is already open, only the watcher
starts (attach mode).

### Manual two-terminal (same as before)

**Terminal A — emulator (windowed, control port):**

```bash
tools/c64m --control-port 6510
# or: tools/agent_session.py
```

**Terminal B — watcher (from RailGunner root):**

```bash
tools/build-prg.sh
tools/coop_debug_rg.py
```

**Never** `--headless` for coop play. **Never** leave turbo at warp (3) for
visual truth — the watcher forces `set-turbo 1`.

Expected log:

```text
coop: starting … --control-port=6510 --prg … --autorun
[coop_debug_rg] symbols=… regions=… out=…/build/debug port=6510
[coop] connected port=6510 turbo=1 history=on …
[coop] watching -- hit the c64m pause key when you see a glitch
```

If connect fails: nothing on 6510, or another client already holds the sole
socket. One control client at a time.

Ctrl-C stops the **watcher** only; the emulator window keeps running if
`make coop` started it.

---

## 4. Human workflow

1. Play normally.
2. See a glitch (sprite flicker, wrong rail, hitch, etc.).
3. **Hit pause immediately** (frontend pause key).
4. Tell the agent in chat what you saw (quadrant Q1–Q4, which sprite, approx
   when: after kill, on mount, multi-drone, …).
5. Leave the machine **paused** until the agent says to resume (or you unpause
   in the UI — the watcher detects `state=running` and re-arms).

---

## 5. Agent workflow (on freeze)

### 5.1 Read the evidence pack

On pause the daemon writes:

```text
build/debug/snap-NNN.txt
```

Contents (while paused — hot cache / legal history):

| Section | Use |
|---------|-----|
| `stop=` | `pause` (human) vs `breakpoint` (watchpoint hit) |
| CPU | PC, regs, cycle |
| VIC | raster, badline, BA — timing vs sprite writes |
| SPRITES table | enable/x/y/expand/pri/mc/color for HW 0–7 |
| GAME REGIONS | RailGunner ZP + object SoA + mux scalars (from symbols) |
| RECENT WRITES | Flight recorder: writes to sprite regs + selected SoA |
| Frame ring (via inbox) | `scrub` / `frame` — retained pixels + cycle for history |
| VIC ring (via inbox) | `vic <frame>` — per-line latched `spr_x` / enable (why the pixels) |

**Read the snap first**, then the human’s description. Answer in chat with a
hypothesis or next instrument step.

### 5.2 Steer via inbox

Append **one command per line** to `build/debug/coop_inbox` (create if missing).
Commands are only consumed while **paused**.

```bash
# From repo root (agent shell)
INBOX=build/debug/coop_inbox

echo 'note Q2 C flicker after kill' >> "$INBOX"
echo 'scrub 60' >> "$INBOX"                    # last ~1s of frames → PNGs
echo 'frame 912' >> "$INBOX"                   # after you spot the bad frame#
echo 'vic 912' >> "$INBOX"                     # latched spr_x per line for that frame
echo 'vic 912 50-120' >> "$INBOX"              # optional raster window only
echo 'hist $D000 write 64' >> "$INBOX"
echo 'dump $C078 24 map' >> "$INBOX"          # obj_flags (re-check symbols!)
echo 'arm write $C120' >> "$INBOX"             # example: write trap
echo 'arm write $D010 when=value!&1,mem($D000)>$F0' >> "$INBOX"
echo resume >> "$INBOX"
```

| Command | Effect |
|---------|--------|
| `resume` | `run` — clear sticky pause/breakpoint latches; back to watch |
| `quit` | Stop daemon (does not kill c64m) |
| `arm <access> <addr> [opts…]` | `break-create … actions=break` — next hit auto-pauses. **opts** pass through (e.g. `end=$…`, `when=…`) |
| `count <access> <addr> [opts…]` | Count-only watchpoint (no pause); same opts including `when=` |
| `clear` | `break-clear-all` |
| `dump <addr> <len> [map\|ram]` | Extra memory → current snap file |
| `hist <addr> [access] [limit]` | Extra history-find → current snap |
| `scrub [count]` | Dump last N ring frames as PNGs under `build/debug/snap-NNN-frames/` |
| `frame <n>` | Pull one ring frame + machine cycle into the pack (key for `hist` / `vic`) |
| `vic <frame> [first-last]` | Per-line VIC state for that frame (latched `spr_x` with `$D010` MSB, enable/visible/active) |
| `note <text…>` | Append human/agent note into snap |

`access`: `exec` \| `read` \| `write` \| `read-write`  
Addresses: `$C078` or `0xC078`.

**Guarded arms (`when=`):** up to 4 ANDed terms; no whitespace inside the
condition. Same grammar as control-port `break-create` (see build-debug §6.5b).
Examples from upstream `coop_watch.py`:

```text
arm write $D021 when=i==1
arm write $D010 when=value!&1,mem($D000)>$F0
arm write $00C3 when=raster>=250
count write $D015 when=raster<50
```

### 5.3 Late pause — scrub → vic → hist (full chain)

When the human saw a **one-frame** flash / wrong sprite / hitch and paused a
beat later, the live `get-frame` is already the aftermath. Use all three black
boxes on **one machine-cycle axis**:

1. `echo 'scrub 60' >> build/debug/coop_inbox` (or `scrub 200` for ~4 s)  
2. Open `build/debug/snap-NNN-frames/*.png` — find the bad frame by eye  
3. `echo 'frame <n>' >> …` — pack gets pixels + **machine cycle**  
4. `echo 'vic <n>' >> …` (optional `vic <n> 40-120` for a raster band) —  
   **latched** `spr_x` / `spr_en` / `spr_vis` per line. Compare to what the
   game/mux thinks it wrote (`hist $D000` / `$D010`, or SoA `obj_x_*`)  
5. `echo 'hist …'` / `history-find cycle=…` for bus traffic at that moment  

**Kill criterion for “ghost on left edge” / wrong X for one frame:**  
`vic` shows `spr_x` for that HW lane **≠** the X from `hist`/`obj_x` on the
same frame’s lines. That is the latched-XMSB bug class — neither pixels alone
nor the flight recorder alone can prove it.

Check scrub log for **`dropped=`**: non-zero means the glitch may have rolled
off — raise `[debug] frame_ring_memory_mb` / `vic_ring_memory_mb` or pause
faster. Frame ring does not record at turbo 3.

### 5.4 Arm-and-reproduce (intermittent bugs)

When the manual pause was too late **and** the ring did not catch a clear
visual, or the bug is conditional:

1. From description, pick a **write** (or exec) that should fire if the bug is real  
   - Mux wrong pointer: `arm write` range over `objects::obj_sprite_ptr` or sprite regs  
   - Kill double-count: `arm write $xxxx` score / kill counter  
   - Mid-IRQ only / raster band only: add **`when=`** so free-run does not stop
     on every access  
2. `echo 'arm write $ADDR when=…' >> build/debug/coop_inbox`  
3. `echo resume >> build/debug/coop_inbox`  
4. Human reproduces  
5. Next snap has `stop=breakpoint` at the **exact instruction** — smoking gun  
6. When done: `echo clear >> …` then `echo resume >> …`

Optional: `count write $ADDR when=…` first to see if the address is hot even
without a visible glitch.

### 5.5 After analysis

- Prefer fixing the bug in a follow-up change (then rebuild + re-assemble).  
- Do **not** commit coop docs/tools until the human confirms a successful
  end-to-end freeze→snap→inbox→resume path (project convention for this feature).

---

## 6. Protocol rules the daemon already honors

| Rule | Behavior |
|------|----------|
| One wait outstanding | Only a single `wait-paused` in flight |
| History needs pause | `history-find` / `hist` only after freeze |
| Frame ring lookup | `scrub` / `frame` / `get-frame-at` OK while running, but **pause** for a stable window |
| `run` clears sticky latches | Next wait is the *next* stop, not the old one |
| Turbo 1 | Real-time play; live pixels; never warp for visual QA (warp also stalls the frame ring) |
| Frame payload | `indexed8` is the native representation; existing `argb8888` reads remain compatible |
| Mid-raster `get-frame` | Partial buffer — pack uses CPU/VIC/sprites/history first; full live frame needs `run-to-raster` / `step-frame`; **past** frames use the ring |
| Sole control client | No second `agent_session` / second watcher on the same port |

---

## 7. RailGunner regions (what gets dumped)

`tools/coop_debug_rg.py` resolves names from `build/symbols.txt`:

**Session / player / level (ZP):** `game_mode`, `input_dirs`, score, lives,
`level`, `level_kills`, `level_quota`, `level_banner_t`, `pending_mode`, player
rail/swing/move, drone spawn timers, cargo/mine flags, parcel slot. Prefer
[`level-rework.md`](level-rework.md) over older “wave quota” wording.

**Objects / mux:** `obj_flags`, `obj_kind`, `obj_x_lo`/`hi`, `obj_y_int`,
`obj_sprite_ptr`, `obj_reserved` (HP), `hw_owner`, `free_count`, front/back/ready
plan, command count, `mux_last_error`, dirty/miss/seq.

**Write traces:** `$D000..$D02E` sprite regs + SoA ranges for flags/kind/y/ptr/hw_owner.

After a big layout change: `tools/build-prg.sh` then restart the watcher so
addresses refresh.

---

## 8. Glitch classes → first probe

| Symptom | First look in snap | Then arm / scrub |
|---------|-------------------|------------------|
| One-frame flash / gone before pause | `scrub 60` → bad PNG; `frame n` → cycle; **`vic n`** for latched X | `hist` on `$D000`/`$D010`; compare `spr_x` vs write; `when=` if conditional |
| Sprite flicker / wrong frame | SPRITES table; `obj_sprite_ptr` / `obj_flags`; scrub + **vic** if late | `arm write` on that slot’s ptr or `$D000` range; `when=raster…` if band-specific |
| One-frame left-edge / wrong X | `vic n` `spr_x` vs game X on that line | `arm write $D010 when=…` if MSB thrash |
| Mux freeze / hitch | `mux_last_error`, plan ready/count, `mux_plan_miss` | exec on mux build fail path if known |
| Player teleport / wrong rail | `player_rail`, x/y slot 0 | write to player move or `obj_x_lo` |
| Wave advances wrong | `wave_kills_*` vs quotas, `pending_mode` | write to kill counters |
| Rail damage wrong quadrant | (logic) re-check after pause; history less critical | — |
| Wrong VIC write only in IRQ / border | aftermath PC useless | `arm write $D0xx when=i==1` or `when=raster>=250` |

Quadrant names (playfield): **Q1** upper-right, **Q2** lower-right, **Q3**
lower-left, **Q4** upper-left.

---

## 9. What not to do

- Do not hold the socket in a **subagent** and expect chat steers to arrive there.  
- Do not `get-frame` every frame as a “glitch detector” (costly, weak signal) —
  use the **frame ring** + `scrub` after pause instead.  
- Do not edit `../c64m/` from a RailGunner session (boundary). Improve c64m via
  the friction log if the tool is awkward.  
- Do not use turbo 3 for coop visual sessions (no live pixels, ring stalls).  
- Do not open a second control client while the watcher owns 6510.  
- Do not save a guarded breakpoint from the **frontend** dialog — it clears
  `when=` (control-port / inbox only).

---

## 10. Minimal checklist (agent)

```text
[ ] make coop   (or manual: prg + emu on 6510 + coop_debug_rg.py)
[ ] game in play (turbo 1)
[ ] human pauses on glitch
[ ] read build/debug/snap-NNN.txt + human description
[ ] if visual / one-frame: scrub → find PNG → frame n → vic n → hist on cycle
[ ] if wrong X: compare vic spr_x to hist/obj_x (latched vs written)
[ ] inbox: note / hist / dump / arm [when=…] as needed
[ ] inbox: resume (or clear + resume)
[ ] only commit coop tooling after a proven freeze→snap→resume run
```

---

## 11. File ownership

| File | Owner |
|------|--------|
| `../c64m/tools/coop_watch.py` | c64m (upstream); RG may symlink only |
| `tools/coop_debug_rg.py` | RailGunner — game CONFIG + symbol resolve |
| `agents/coop-debug.md` | RailGunner — this protocol |
| `build/debug/*` | Ephemeral session artifacts (do not require commit) |

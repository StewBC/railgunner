#!/usr/bin/env python3
"""RailGunner entry point for c64m cooperative live-debug (coop_watch).

Wraps ../c64m/tools/coop_watch.py with game-specific regions/trace addresses
resolved from build/symbols.txt (rebuilt by tools/build-prg.sh).

  # Terminal A — windowed emu with control port (turbo set by watcher)
  tools/c64m --control-port 6510
  # or: tools/agent_session.py  then attach watcher with --port 6510

  # Terminal B — from RailGunner repo root
  tools/coop_debug_rg.py

  # Play, hit pause on glitch → build/debug/snap-NNN.txt
  # Agent steers: echo resume >> build/debug/coop_inbox

Full agent protocol: agents/coop-debug.md
"""
from __future__ import annotations

import os
import re
import sys

RG_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
C64M_TOOLS = os.path.abspath(os.path.join(RG_ROOT, "..", "c64m", "tools"))
SYMBOLS = os.path.join(RG_ROOT, "build", "symbols.txt")
OUT_DIR = os.path.join(RG_ROOT, "build", "debug")

# ZP / small scalars: name -> length (bytes)
ZP_REGIONS = {
    "game_mode": 1,
    "input_dirs": 1,
    "score0": 3,  # score0..score2
    "health": 1,
    "lives": 1,
    "level": 1,
    "wave": 1,
    "pending_mode": 1,
    "player_rail": 1,
    "player_rest_dir": 1,
    "player_swing_t": 1,
    "player_move_dir": 1,
    "player_cross_decided": 1,
    "drone_spawn_timer": 1,
    "drone_spawn_seq": 1,
    "wave_quota": 1,
    "wave_kills_c": 1,
    "wave_kills_b": 1,
    "wave_kills_a": 1,
    "wave_cadence": 1,
    "wave_max_active": 1,
    "wave_approach_mask": 1,
    "wave_b_quota": 1,
    "wave_a_quota": 1,
}

# Pool / mux (SoA base + length)
# OBJECT_CAPACITY = 24
POOL_REGIONS = {
    "objects::obj_flags": 24,
    "objects::obj_kind": 24,
    "objects::obj_x_lo": 24,
    "objects::obj_x_hi": 24,
    "objects::obj_y_int": 24,
    "objects::obj_sprite_ptr": 24,
    "objects::obj_reserved": 24,  # HP
    "objects::hw_owner": 8,
    "objects::free_count": 1,
    "objects::mux_front_plan": 1,
    "objects::mux_back_plan": 1,
    "objects::mux_ready_plan": 1,
    "objects::mux_plan_ready": 1,
    "objects::mux_front_command_count": 1,
    "objects::mux_last_error": 1,
    "objects::mux_objects_dirty": 1,
    "objects::mux_build_seq": 1,
    "objects::mux_plan_miss": 1,
    "mux_build_failed": 1,  # CODE flag if present
}

# Flight-recorder write traces: (label, symbol_or_None, abs_addr, end_or_None)
# If symbol is set, addr is resolved from symbols.txt
TRACE_SPEC = [
    ("sprite-regs", None, 0xD000, 0xD02E),
    ("obj_flags", "objects::obj_flags", None, None),  # base only; range filled after resolve
    ("obj_kind", "objects::obj_kind", None, None),
    ("obj_y_int", "objects::obj_y_int", None, None),
    ("obj_sprite_ptr", "objects::obj_sprite_ptr", None, None),
    ("hw_owner", "objects::hw_owner", None, None),
]


def load_symbols(path: str) -> dict[str, int]:
    """Parse c64masm -s style 'HHHH  name' lines."""
    syms: dict[str, int] = {}
    if not os.path.isfile(path):
        return syms
    # "0015  player_rail" or "C078  objects::obj_flags"
    pat = re.compile(r"^([0-9A-Fa-f]+)\s+(\S+)\s*$")
    with open(path) as f:
        for line in f:
            m = pat.match(line.strip())
            if not m:
                continue
            syms[m.group(2)] = int(m.group(1), 16)
    return syms


def build_config(syms: dict[str, int]) -> dict:
    regions: dict[str, tuple[int, int]] = {}
    missing: list[str] = []

    for name, length in {**ZP_REGIONS, **POOL_REGIONS}.items():
        if name not in syms:
            missing.append(name)
            continue
        regions[name] = (syms[name], length)

    trace_writes: list = [("sprite-regs", 0xD000, 0xD02E)]
    for entry in TRACE_SPEC:
        label = entry[0]
        if label == "sprite-regs":
            continue
        _, sym, _, _ = entry
        if sym not in syms:
            missing.append(sym)
            continue
        base = syms[sym]
        # 24-byte SoA rows (or 8 for hw_owner)
        end = base + (POOL_REGIONS.get(sym, 24) - 1)
        trace_writes.append((label, base, end))

    if missing:
        print(
            f"[coop_debug_rg] warning: missing symbols (rebuild PRG?): "
            f"{', '.join(missing[:12])}"
            + ("..." if len(missing) > 12 else ""),
            flush=True,
        )

    return {
        "port": 6510,
        "out_dir": OUT_DIR,
        "wait_ms": 600000,
        "regions": regions,
        "trace_writes": trace_writes,
        "trace_limit": 48,
    }


def main() -> None:
    if not os.path.isdir(C64M_TOOLS):
        print(f"error: c64m tools not found at {C64M_TOOLS}", file=sys.stderr)
        sys.exit(1)

    # Prefer local symlink of client; coop_watch lives in c64m
    sys.path.insert(0, C64M_TOOLS)
    sys.path.insert(0, os.path.dirname(__file__))

    import coop_watch  # noqa: E402  # type: ignore

    syms = load_symbols(SYMBOLS)
    if not syms:
        print(
            f"error: no symbols at {SYMBOLS} — run tools/build-prg.sh first",
            file=sys.stderr,
        )
        sys.exit(1)

    cfg = build_config(syms)
    os.makedirs(cfg["out_dir"], exist_ok=True)

    # Allow CLI overrides (same flags as coop_watch)
    import argparse

    ap = argparse.ArgumentParser(
        description="RailGunner cooperative debug (coop_watch + game symbols)"
    )
    ap.add_argument("--port", type=int, default=cfg["port"])
    ap.add_argument("--out-dir", default=cfg["out_dir"])
    ap.add_argument("--wait-ms", type=int, default=cfg["wait_ms"])
    args = ap.parse_args()
    cfg["port"] = args.port
    cfg["out_dir"] = args.out_dir
    cfg["wait_ms"] = args.wait_ms

    print(
        f"[coop_debug_rg] symbols={len(syms)} regions={len(cfg['regions'])} "
        f"out={cfg['out_dir']} port={cfg['port']}",
        flush=True,
    )

    watcher = coop_watch.CoopWatch(cfg)
    watcher.setup()
    try:
        watcher.watch_loop()
    except KeyboardInterrupt:
        watcher._log("stopped")
    finally:
        watcher.c.close()


if __name__ == "__main__":
    main()

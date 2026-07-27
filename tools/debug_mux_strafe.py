#!/usr/bin/env python3
"""Reproduce mux lock while under B drone: tight strafe + continuous fire.

Keep killing B before it reaches the H-rail (player aims up by default).
"""
from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from c64_control_client import Ctl  # noqa: E402

JOY_UP, JOY_DOWN, JOY_LEFT, JOY_RIGHT, JOY_FIRE = 0x01, 0x02, 0x04, 0x08, 0x10

# From build/symbols.txt
MUX = {
    "front_plan": 0xC35D,
    "back_plan": 0xC35E,
    "ready_plan": 0xC35F,
    "plan_ready": 0xC360,
    "build_valid": 0xC361,
    "cmd_count": 0xC362,
    "plan_miss": 0xC36C,
    "event_overrun": 0xC36D,
    "last_error": 0xC36E,
    "build_seq": 0xC36F,
    "objects_dirty": 0xC378,
}
MUX_ERR = {
    0: "OK",
    1: "TOO_MANY_VISIBLE",
    2: "LANE_CAPACITY",
    3: "PRIORITY",
    4: "RASTER_DEADLINE",
    5: "COMMAND_CAPACITY",
    6: "PLAN_BUSY",
    7: "BAD_COORDINATE",
}
OBJ_FLAGS, OBJ_KIND = 0xC050, 0xC068
OBJ_X_LO, OBJ_X_HI, OBJ_Y = 0xC098, 0xC0B0, 0xC0E0
OBJ_CAPACITY = 24
VIC_SPR_ENABLE = 0xD015

# Slice geometry
PLAYER_X_START = 153
B_SPAWN_X = 220
# Stay within ~±3 char cols of B (24px) while spraying
STRAFE_HALF = 24  # pixels either side of B_SPAWN_X


def port_open(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.25):
            return True
    except OSError:
        return False


def joy(ctl: Ctl, mask: int) -> None:
    ctl.ok(f"joystick 2 {mask}")


def release(ctl: Ctl) -> None:
    joy(ctl, 0)


def hold(ctl: Ctl, mask: int, seconds: float) -> None:
    joy(ctl, mask)
    time.sleep(seconds)


def read_objects(ctl: Ctl) -> list[dict]:
    flags = ctl.mem(OBJ_FLAGS, OBJ_CAPACITY, mode="ram")
    kinds = ctl.mem(OBJ_KIND, OBJ_CAPACITY, mode="ram")
    xlo = ctl.mem(OBJ_X_LO, OBJ_CAPACITY, mode="ram")
    xhi = ctl.mem(OBJ_X_HI, OBJ_CAPACITY, mode="ram")
    y = ctl.mem(OBJ_Y, OBJ_CAPACITY, mode="ram")
    out = []
    for i in range(OBJ_CAPACITY):
        f = flags[i]
        if not (f & 1):
            continue
        out.append(
            {
                "i": i,
                "f": f,
                "k": kinds[i],
                "x": xlo[i] + 256 * (xhi[i] & 1),
                "y": y[i],
                "render": bool(f & 2),
                "retiring": bool(f & 4),
            }
        )
    return out


def read_mux(ctl: Ctl) -> dict:
    m = {n: ctl.mem(a, 1, mode="ram")[0] for n, a in MUX.items()}
    m["err_name"] = MUX_ERR.get(m["last_error"], f"?{m['last_error']}")
    m["spr_enable"] = ctl.mem(VIC_SPR_ENABLE, 1, mode="map")[0]
    m["objects"] = read_objects(ctl)
    m["player"] = next((o for o in m["objects"] if o["i"] == 0), None)
    m["b"] = next((o for o in m["objects"] if o["k"] == 2), None)  # OBJ_DRONE_B
    m["c"] = next((o for o in m["objects"] if o["k"] == 3), None)
    return m


def fmt_mux(m: dict) -> str:
    def o(tag, obj):
        if not obj:
            return f"{tag}=—"
        return (
            f"{tag}=#{obj['i']}@({obj['x']},{obj['y']})"
            f"{'R' if obj['render'] else ''}{'T' if obj['retiring'] else ''}"
        )

    return (
        f"err={m['last_error']}({m['err_name']}) miss={m['plan_miss']} "
        f"over={m['event_overrun']} seq={m['build_seq']} cmds={m['cmd_count']} "
        f"ready={m['plan_ready']} valid={m['build_valid']} dirty={m['objects_dirty']} "
        f"D015=${m['spr_enable']:02X} {o('P', m['player'])} {o('B', m['b'])} {o('C', m['c'])}"
    )


def screen_row0(ctl: Ctl) -> str:
    raw = ctl.mem(0x0400, 40, mode="ram")
    out = []
    for b in raw:
        if 1 <= b <= 26:
            out.append(chr(b + 64))
        elif b == 32:
            out.append(" ")
        elif 48 <= b <= 57:
            out.append(chr(b))
        else:
            out.append(".")
    return "".join(out)


def enter_play(ctl: Ctl) -> None:
    print("enter play…", flush=True)
    for i in range(5):
        hold(ctl, JOY_FIRE, 0.12)
        release(ctl)
        time.sleep(0.45)
        row = screen_row0(ctl)
        print(f"  fire{i+1}: {row[:28]!r}", flush=True)
        if row.startswith("000") or (row[0:1].isdigit() and "H" in row):
            print("  → play HUD", flush=True)
            return
    print("  (assuming play)", flush=True)


def park_under_b(ctl: Ctl, timeout: float = 3.0) -> bool:
    """Move player X toward B_SPAWN_X (or live B.x). Fire while approaching."""
    print(f"park under B (target X~{B_SPAWN_X})…", flush=True)
    deadline = time.time() + timeout
    while time.time() < deadline:
        m = read_mux(ctl)
        p = m["player"]
        b = m["b"]
        target = b["x"] if b else B_SPAWN_X
        if not p:
            time.sleep(0.05)
            continue
        dx = target - p["x"]
        if abs(dx) <= 8:
            print(f"  parked player X={p['x']} B={b}", flush=True)
            release(ctl)
            return True
        mask = JOY_FIRE | (JOY_RIGHT if dx > 0 else JOY_LEFT)
        joy(ctl, mask)
        time.sleep(0.04)
    release(ctl)
    print(f"  park timeout: {fmt_mux(read_mux(ctl))}", flush=True)
    return False


def hunt_strafe(ctl: Ctl, duration: float = 12.0) -> list[dict]:
    """Hold fire, wiggle only ±STRAFE_HALF around B, sample mux."""
    print(
        f"hunt: fire + ±{STRAFE_HALF}px around B for {duration:.1f}s…",
        flush=True,
    )
    log: list[dict] = []
    t0 = time.time()
    phase = 0  # 0 go left, 1 go right
    phase_t = time.time()
    phase_dur = 0.18  # short legs → small travel

    while time.time() - t0 < duration:
        m = read_mux(ctl)
        p, b = m["player"], m["b"]
        # Anchor band on live B x, else spawn x
        cx = b["x"] if b else B_SPAWN_X
        lo, hi = cx - STRAFE_HALF, cx + STRAFE_HALF

        if time.time() - phase_t > phase_dur:
            phase ^= 1
            phase_t = time.time()

        mask = JOY_FIRE
        if p:
            if p["x"] <= lo:
                phase = 1
            elif p["x"] >= hi:
                phase = 0
            mask |= JOY_RIGHT if phase else JOY_LEFT

        joy(ctl, mask)
        time.sleep(0.05)

        m = read_mux(ctl)
        m["step"] = len(log)
        log.append(m)
        flag = ""
        if m["last_error"]:
            flag += " ERR"
        if m["plan_miss"] and m["plan_miss"] % 50 < 5:
            flag += " MISS"
        # freeze: seq stuck + cmds 0 + ready 0 while objects want render
        if (
            len(log) > 5
            and m["cmd_count"] == 0
            and m["plan_ready"] == 0
            and any(o.get("render") for o in m["objects"])
        ):
            flag += " FREEZE?"
        if flag or len(log) % 8 == 0:
            print(f"  [{len(log):03d}]{flag} {fmt_mux(m)}", flush=True)

        # Detect freeze: build_seq unchanged for many samples while dirty or miss climbing
        if len(log) >= 10:
            recent = log[-10:]
            seqs = {r["build_seq"] for r in recent}
            if len(seqs) == 1 and recent[-1]["plan_miss"] > recent[0]["plan_miss"] + 20:
                print("  *** build_seq frozen while plan_miss climbs — mux stuck", flush=True)
                break

    release(ctl)
    return log


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=int(os.environ.get("C64M_PORT", 6510)))
    ap.add_argument("--boot", action="store_true")
    ap.add_argument("--duration", type=float, default=14.0)
    ap.add_argument("--turbo", type=int, default=1, help="1=normal 2=max")
    opts = ap.parse_args()

    if opts.boot or not port_open(opts.port):
        print("booting…", flush=True)
        r = subprocess.run(
            [sys.executable, str(TOOLS / "agent_session.py"), "--once"],
            cwd=str(TOOLS.parent),
        )
        if r.returncode != 0:
            return r.returncode
        time.sleep(1.0)

    ctl = Ctl(port=opts.port, timeout=60.0)
    print(ctl.cmd("hello"), flush=True)
    if "paused" in ctl.cmd("get-state")[1]:
        ctl.ok("run")
    if opts.turbo != 1:
        ctl.ok(f"turbo {opts.turbo}")

    enter_play(ctl)
    time.sleep(0.3)
    print(f"entry {fmt_mux(read_mux(ctl))}", flush=True)

    park_under_b(ctl)
    log = hunt_strafe(ctl, duration=opts.duration)

    errs = {m["last_error"] for m in log if m["last_error"]}
    print("\n=== SUMMARY ===", flush=True)
    print(f"samples={len(log)} unique_errors={errs}")
    if log:
        print(f"max_miss={max(m['plan_miss'] for m in log)} max_over={max(m['event_overrun'] for m in log)}")
        print(f"final {fmt_mux(log[-1])}", flush=True)
        # freeze detection
        frozen = [
            m
            for m in log
            if m["cmd_count"] == 0 and m["plan_ready"] == 0 and m["build_seq"] > 0
        ]
        print(f"zero-cmd samples={len(frozen)}")
    print(f"row0={screen_row0(ctl)!r}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

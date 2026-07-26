#!/usr/bin/env python3
"""AGENT path: windowed c64m + control port for assemble / debug / inspect.

This is how agents chase user bug reports: launch (or attach), build into the
live machine, keep the control port open, use breakpoints / get-memory /
get-cpu / get-frame. The human still sees the SDL window (never --headless).

User play/test without an agent session: use tools/play.sh instead
(offline PRG + --autorun; no remote API).

Typical agent flow:
  1. tools/agent_session.py              # start emu, assemble, paste RUN
  2. Drive remote API (or this process stays up for attach tooling)
  3. tools/agent_session.py --attach     # re-attach to an open session

Equivalent human steps for the boot: Shift+Opt+A, fix pointers, type RUN —
or load the offline PRG. Agents use the remote API so they can instrument.
"""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
RG_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from c64_control_client import Ctl  # noqa: E402

DEFAULT_PORT = 6510
SRC = RG_ROOT / "src" / "main.asm"
C64M_INI = Path(os.environ.get("C64M_INI", RG_ROOT / "c64m.ini"))
C64M_ROOT = Path(os.environ.get("C64M_ROOT", (RG_ROOT / ".." / "c64m").resolve()))
C64M_BIN = TOOLS_DIR / "c64m"

# Game code lives in CODE segment $080D.. (BASIC stub at $0801).
# Upper bound is soft — only used to detect "we're in game code after RUN".
GAME_PC_LO = 0x080D
GAME_PC_HI = 0x2000


def port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.25):
            return True
    except OSError:
        return False


def wait_port(host: str, port: int, timeout: float = 15.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if port_open(host, port):
            time.sleep(0.3)
            return
        time.sleep(0.1)
    raise RuntimeError(f"control port {host}:{port} not open within {timeout}s")


def parse_pc(cpu_payload: str) -> int | None:
    """Pull the program counter out of a get-cpu payload (e.g. 'pc=0860 a=1B ...')."""
    for tok in cpu_payload.split():
        if tok.startswith("pc="):
            return int(tok[3:].lstrip("$"), 16)
    return None


def wait_for_game_pc(ctl: Ctl, timeout: float = 6.0) -> bool:
    """Poll until the CPU is executing inside the game's code range."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        pc = parse_pc(ctl.cmd("get-cpu")[1])
        if pc is not None and GAME_PC_LO <= pc < GAME_PC_HI:
            return True
        time.sleep(0.1)
    return False


def screen_text(ctl: Ctl) -> str:
    raw = ctl.mem(0x0400, 1000, mode="ram")
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


def start_emulator(port: int, extra: list[str]) -> subprocess.Popen:
    if not C64M_BIN.exists():
        raise SystemExit(f"missing {C64M_BIN}")
    cmd = [str(C64M_BIN)]
    if C64M_INI.is_file():
        cmd += ["--inifile", str(C64M_INI)]
    joined = " ".join(extra)
    if "--control-port" not in joined:
        cmd += [f"--control-port={port}"]
    cmd += extra
    print(f"agent session starting: {' '.join(cmd)}", flush=True)
    return subprocess.Popen(
        cmd,
        cwd=str(C64M_ROOT),
        env={**os.environ, "RAILGUNNER_ROOT": str(RG_ROOT)},
        start_new_session=True,  # survive parent exit (--once / detach)
    )


def boot_game(ctl: Ctl, *, reset: bool = True) -> None:
    """Live assemble + BASIC-run in one command (instrumentable).

    Uses c64m's ``basic-run`` mode: after assembling it stages the image as a
    LOAD would (fixes TXTTAB/VARTAB/ARYTAB/STREND from the emitted origin+end)
    and RUNs it through the BASIC editor via paste — no manual $2B poke, no
    manual paste-RUN. reset=True (default) guarantees a READY prompt for the
    paste; c64m skips the reset when the machine is already at a fresh READY
    (e.g. right after launch), so a just-launched emulator does not pay for it.
    """
    src = SRC.resolve()
    reset_flag = 1 if reset else 0
    cmd = f"assemble basic-run=1 reset={reset_flag} {src}"
    print(f"assemble: {cmd}", flush=True)
    r = ctl.cmd(cmd)
    if r[0] != "ok":
        raise RuntimeError(f"assemble/basic-run failed: {r}")
    print(f"assemble ok: {r[1]}", flush=True)  # actual emitted origin, e.g. address=$0801

    # basic-run has fixed the BASIC pointers and pasted RUN; wait until BASIC has
    # SYS'd into game code before we inspect.
    if not wait_for_game_pc(ctl):
        print("warning: PC did not reach game code range in time", flush=True)
    time.sleep(0.5)  # let the title draw
    print(f"state: {ctl.cmd('get-state')}", flush=True)
    print(f"cpu: {ctl.cmd('get-cpu')}", flush=True)
    print(f"start: {ctl.cmd('find-symbol start')}", flush=True)


def main() -> int:
    if any(a == "--headless" or a.startswith("--headless=") for a in sys.argv[1:]):
        print(
            "error: RailGunner never uses --headless (see agents/README.md)",
            file=sys.stderr,
        )
        return 2

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--attach", action="store_true", help="use existing control port")
    ap.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("C64M_PORT", DEFAULT_PORT)),
    )
    ap.add_argument(
        "--no-reset",
        action="store_true",
        help="assemble with reset=0 (default is reset=1; use only on fresh READY)",
    )
    ap.add_argument(
        "--no-boot",
        action="store_true",
        help="start/attach only; do not assemble or RUN",
    )
    ap.add_argument(
        "--verify",
        action="store_true",
        help="check title screen text, then exit (stops emu if we started it)",
    )
    ap.add_argument(
        "--once",
        action="store_true",
        help="boot game then exit this script (leave emu running if we started it "
        "only when not --verify; with default, keep script alive so child is not reaped)",
    )
    ap.add_argument("emu_args", nargs="*", help="extra c64m args")
    opts = ap.parse_args()

    proc: subprocess.Popen | None = None
    try:
        if not opts.attach:
            if port_open("127.0.0.1", opts.port):
                print(f"port {opts.port} busy — attaching", flush=True)
            else:
                proc = start_emulator(opts.port, opts.emu_args)
                wait_port("127.0.0.1", opts.port)
                time.sleep(1.2)
        elif not port_open("127.0.0.1", opts.port):
            raise SystemExit(f"nothing on port {opts.port}")

        ctl = Ctl(port=opts.port, timeout=60.0)
        print(f"hello: {ctl.cmd('hello')}", flush=True)

        if not opts.no_boot:
            # Re-assemble without relaunch ⇒ need reset (default).
            boot_game(ctl, reset=not opts.no_reset)

        if opts.verify:
            # Title is a hires bitmap: $D011 BMM set, colour matrix + pixels loaded.
            # Art is letterboxed — top bitmap rows may be zero; sample mid-screen.
            d011 = ctl.mem(0xD011, 1, mode="map")[0]
            d018 = ctl.mem(0xD018, 1, mode="map")[0]
            bmp = ctl.mem(0x2000 + 40 * 8 * 8, 128, mode="ram")  # ~row 8 of cells
            cols = ctl.mem(0x0400, 200, mode="ram")
            bmm = bool(d011 & 0x20)
            mem_ok = d018 == 0x18
            bmp_ok = any(b != 0 for b in bmp)
            col_ok = any(b != 0 for b in cols)
            ok = bmm and mem_ok and bmp_ok and col_ok
            print(
                f"verify: BMM={bmm} d011=${d011:02x} d018=${d018:02x} "
                f"bitmap_nonzero={bmp_ok} colors_nonzero={col_ok}",
                flush=True,
            )
            if proc is not None:
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
            print("VERIFY OK" if ok else "VERIFY FAILED", flush=True)
            return 0 if ok else 1

        if opts.once and proc is not None:
            # Detach: leave emulator running for the human or a later --attach
            print("boot done — emulator left running; re-attach with --attach", flush=True)
            return 0

        if proc is not None:
            print("agent session live — Ctrl+C stops emulator", flush=True)
            try:
                proc.wait()
            except KeyboardInterrupt:
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
        else:
            print("attached; script exiting (emulator stays up)", flush=True)
        return 0
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        if proc is not None:
            proc.terminate()
        return 1


if __name__ == "__main__":
    sys.exit(main())

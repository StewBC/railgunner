#!/usr/bin/env python3
"""Summarize RailGunner phase-marker history from a coop evidence pack."""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SYMBOLS = os.path.join(ROOT, "build", "symbols.txt")
DEBUG_DIR = os.path.join(ROOT, "build", "debug")
PAL_FRAME_CYCLES = 19_656

PHASES = {
    0x01: "main.wait_frame",
    0x02: "main.drain_events",
    0x03: "main.reap",
    0x04: "main.input",
    0x05: "main.mode_dispatch",
    0x06: "main.build_check",
    0x07: "main.publish",
    0x08: "main.build_failed",
    0x20: "play.player",
    0x21: "play.drones",
    0x22: "play.cargo",
    0x23: "play.parcels",
    0x24: "play.bullets",
    0x25: "play.collision",
    0x26: "play.wave_banner",
    0x27: "play.wave_clear",
    0x28: "play.score",
    0x29: "play.hud",
    0x2A: "play.mode_set",
    0x2B: "play.done",
    0x40: "mux.gate",
    0x41: "mux.gather",
    0x42: "mux.sort",
    0x43: "mux.assign",
    0x44: "mux.y_order",
    0x45: "mux.windows",
    0x46: "mux.emit",
    0x47: "mux.finish",
    0x48: "mux.busy_return",
    0x49: "mux.fail_return",
    0xE0: "irq.shell",
    0xE1: "irq.frame_start",
    0xE2: "irq.command",
    0xEF: "irq.exit",
}

IRQ_ENTER = 0xE0
IRQ_EXIT = 0xEF


@dataclass(frozen=True)
class Event:
    cycle: int
    phase: int


def symbol_address(name: str) -> int:
    pattern = re.compile(r"^([0-9A-Fa-f]+)\s+(\S+)\s*$")
    with open(SYMBOLS, encoding="utf-8") as handle:
        for line in handle:
            match = pattern.match(line.strip())
            if match and match.group(2) == name:
                return int(match.group(1), 16)
    raise RuntimeError(f"missing {name} in {SYMBOLS}; rebuild the PRG")


def latest_snap() -> str:
    paths = glob.glob(os.path.join(DEBUG_DIR, "snap-*.txt"))
    if not paths:
        raise RuntimeError(f"no coop evidence packs under {DEBUG_DIR}")
    return max(paths, key=os.path.getmtime)


def marker_events(path: str, address: int) -> list[Event]:
    heading = f"--- hist ${address:04X} write"
    sections: list[list[Event]] = []
    current: list[Event] | None = None
    value_pattern = re.compile(rf"\${address:04X}=\$([0-9A-Fa-f]{{2}})")
    cycle_pattern = re.compile(r"\bcyc=(\d+)")

    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("--- "):
                if line.startswith(heading):
                    current = []
                    sections.append(current)
                else:
                    current = None
                continue
            if current is None:
                continue
            cycle_match = cycle_pattern.search(line)
            values = value_pattern.findall(line)
            if cycle_match and values:
                current.append(Event(int(cycle_match.group(1)), int(values[-1], 16)))

    if not sections or not sections[-1]:
        raise RuntimeError(
            f"no marker history in {path}\n"
            f"while paused, send: hist ${address:04X} write 256"
        )
    # History is newest-first. Sorting also tolerates merged recorder output.
    return sorted(sections[-1], key=lambda event: event.cycle)


def add_sample(samples: dict[int, list[int]], phase: int | None, cycles: int) -> None:
    if phase is not None and cycles >= 0:
        samples[phase].append(cycles)


def phase_samples(events: list[Event]) -> dict[int, list[int]]:
    samples: dict[int, list[int]] = defaultdict(list)
    active: int | None = None
    active_start = 0
    active_accum = 0
    in_irq = False
    irq_phase: int | None = None
    irq_start = 0

    for event in events:
        phase = event.phase
        cycle = event.cycle

        if phase == IRQ_ENTER:
            if in_irq:
                add_sample(samples, irq_phase, cycle - irq_start)
            else:
                if active is not None:
                    active_accum += cycle - active_start
                in_irq = True
            irq_phase = phase
            irq_start = cycle
            continue

        if in_irq:
            add_sample(samples, irq_phase, cycle - irq_start)
            if phase == IRQ_EXIT:
                in_irq = False
                irq_phase = None
                if active is not None:
                    active_start = cycle
            else:
                irq_phase = phase
                irq_start = cycle
            continue

        if active is not None:
            active_accum += cycle - active_start
            add_sample(samples, active, active_accum)
        active = phase
        active_start = cycle
        active_accum = 0

    return samples


def print_report(path: str, address: int, events: list[Event]) -> None:
    samples = phase_samples(events)
    span = events[-1].cycle - events[0].cycle
    print(f"profile: {path}")
    print(
        f"marker=${address:04X} events={len(events)} "
        f"span={span} cycles ({span / PAL_FRAME_CYCLES:.2f} PAL frames)"
    )
    print()
    print(f"{'phase':24} {'calls':>5} {'avg':>8} {'min':>8} {'max':>8} {'avg frame':>10} {'total':>10}")
    print("-" * 85)

    rows = []
    for phase, values in samples.items():
        if phase == IRQ_EXIT or not values:
            continue
        total = sum(values)
        average = total / len(values)
        rows.append((total, phase, len(values), average, min(values), max(values)))

    for total, phase, calls, average, minimum, maximum in sorted(rows, reverse=True):
        name = PHASES.get(phase, f"unknown.${phase:02X}")
        print(
            f"{name:24} {calls:5d} {average:8.1f} {minimum:8d} {maximum:8d} "
            f"{average / PAL_FRAME_CYCLES * 100:9.1f}% {total:10d}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze objects::profile_marker writes in a coop snap"
    )
    parser.add_argument("snap", nargs="?", help="snap-NNN.txt (default: latest)")
    args = parser.parse_args()

    try:
        address = symbol_address("objects::profile_marker")
        path = os.path.abspath(args.snap) if args.snap else latest_snap()
        events = marker_events(path, address)
        print_report(path, address, events)
    except (OSError, RuntimeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

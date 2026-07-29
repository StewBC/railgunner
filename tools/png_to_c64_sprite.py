#!/usr/bin/env python3
"""Convert a PNG to a C64 multicolour VIC-II sprite binary (64 bytes).

Output:
  <stem>.bin   64 bytes — 63 sprite data + 1 pad (VIC sprite block)

Multicolour limits: 12×21 logical pixels, 2 bits per pixel. Bit pairs:
  00  transparent
  01  multicolour 1  ($D025, shared)
  10  sprite colour  ($D027+n, per sprite)
  11  multicolour 2  ($D026, shared)

Source art with at most three opaque colours maps cleanly. Extra colours are
snapped to the nearest of the three chosen roles. Alpha < 128 is transparent.

Canvas policy:
  • width ≤ 12 and height ≤ 21 — content is centered on a transparent 12×21
    canvas (nearest-neighbour; no scaling).
  • larger — error unless --fit is set. With --fit, nearest-neighbour scale
    to fit inside 12×21, then center (provisional; remaster art to true
    12×21 when possible).

Colour → bit-pair roles (stable, frequency-based):
  most common opaque  → 10 (sprite colour, $D027+n)
  2nd most common     → 11 (MC2 / $D026 — game: yellow)
  3rd most common     → 01 (MC1 / $D025 — game: dark gray)

Usage:
  tools/png_to_c64_sprite.py assets/sprites/drone1_tiny_native.png
  tools/png_to_c64_sprite.py assets/sprites/drone2_medium_native.png --fit -o assets/sprites/drone2_medium_native.bin
  tools/png_to_c64_sprite.py assets/sprites/*.png --fit
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

try:
    from PIL import Image
except ImportError as e:  # pragma: no cover
    raise SystemExit("Pillow required: pip install Pillow") from e

# Pepto / VICE-style C64 palette (sRGB approximations) — for register hints only.
C64_PALETTE: list[tuple[int, int, int]] = [
    (0, 0, 0),  # 0 black
    (255, 255, 255),  # 1 white
    (104, 55, 43),  # 2 red
    (112, 164, 178),  # 3 cyan
    (111, 61, 134),  # 4 purple
    (88, 141, 67),  # 5 green
    (53, 40, 121),  # 6 blue
    (184, 199, 111),  # 7 yellow
    (111, 79, 37),  # 8 orange
    (67, 57, 0),  # 9 brown
    (154, 103, 89),  # 10 light red
    (68, 68, 68),  # 11 dark gray
    (108, 108, 108),  # 12 mid gray
    (154, 210, 132),  # 13 light green
    (108, 94, 181),  # 14 light blue
    (149, 149, 149),  # 15 light gray
]

SPRITE_W = 12
SPRITE_H = 21
SPRITE_BYTES = 64  # 3 * 21 + 1 pad
ALPHA_OPAQUE = 128

# Bit-pair roles
BP_TRANS = 0b00
BP_MC1 = 0b01
BP_SPRITE = 0b10
BP_MC2 = 0b11

ROLE_NAMES = {
    BP_TRANS: "transparent",
    BP_MC1: "MC1 ($D025)",
    BP_SPRITE: "sprite ($D027+n)",
    BP_MC2: "MC2 ($D026)",
}


def nearest_c64(r: int, g: int, b: int) -> int:
    best_i, best_d = 0, 1 << 30
    for i, (cr, cg, cb) in enumerate(C64_PALETTE):
        d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
        if d < best_d:
            best_d, best_i = d, i
    return best_i


def rgb_dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def load_rgba_grid(im: Image.Image) -> list[list[tuple[int, int, int, int]]]:
    src = im.convert("RGBA")
    px = src.load()
    w, h = src.size
    return [[px[x, y] for x in range(w)] for y in range(h)]


def place_on_canvas(
    grid: list[list[tuple[int, int, int, int]]],
    *,
    fit: bool,
) -> tuple[list[list[tuple[int, int, int, int]]], str]:
    """Return a SPRITE_W × SPRITE_H RGBA grid and a status note."""
    h = len(grid)
    w = len(grid[0]) if h else 0
    note = f"source {w}x{h}"

    if w == 0 or h == 0:
        raise ValueError("empty image")

    content = grid
    cw, ch = w, h

    if w > SPRITE_W or h > SPRITE_H:
        if not fit:
            raise ValueError(
                f"image {w}x{h} exceeds multicolour canvas {SPRITE_W}x{SPRITE_H}; "
                f"remaster the art or pass --fit (nearest scale-to-fit)"
            )
        scale = min(SPRITE_W / w, SPRITE_H / h)
        nw = max(1, int(round(w * scale)))
        nh = max(1, int(round(h * scale)))
        while nw > SPRITE_W or nh > SPRITE_H:
            scale *= 0.95
            nw = max(1, int(round(w * scale)))
            nh = max(1, int(round(h * scale)))
        # Nearest-neighbour via PIL for correct pixel art scaling.
        flat = Image.new("RGBA", (w, h))
        flat.putdata([grid[y][x] for y in range(h) for x in range(w)])
        scaled = flat.resize((nw, nh), Image.Resampling.NEAREST)
        sp = scaled.load()
        content = [[sp[x, y] for x in range(nw)] for y in range(nh)]
        cw, ch = nw, nh
        note += f" --fit → {cw}x{ch} (WARNING: not native 12×21; remaster recommended)"

    canvas = [[(0, 0, 0, 0) for _ in range(SPRITE_W)] for _ in range(SPRITE_H)]
    ox = (SPRITE_W - cw) // 2
    oy = (SPRITE_H - ch) // 2
    for y in range(ch):
        for x in range(cw):
            canvas[oy + y][ox + x] = content[y][x]
    note += f" → centered on {SPRITE_W}x{SPRITE_H}"
    return canvas, note


def build_colour_map(
    canvas: list[list[tuple[int, int, int, int]]],
) -> tuple[dict[tuple[int, int, int], int], list[tuple[tuple[int, int, int], int, int]]]:
    """Map opaque RGB → bit pair. Returns (map, role table for logging)."""
    counts: Counter[tuple[int, int, int]] = Counter()
    for row in canvas:
        for r, g, b, a in row:
            if a >= ALPHA_OPAQUE:
                counts[(r, g, b)] += 1

    # Stable rank: count desc, then RGB.
    ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    if len(ranked) > 3:
        # Keep top 3 by frequency; snap the rest later.
        primary = [c for c, _ in ranked[:3]]
    else:
        primary = [c for c, _ in ranked]

    # Roles: unique first; 2nd colour → $D026 (MC2); 3rd → $D025 (MC1).
    # Matches game palette: SPR_MC1_COLOR yellow, SPR_MC0_COLOR dark gray.
    role_order = [BP_SPRITE, BP_MC2, BP_MC1]
    colour_to_bp: dict[tuple[int, int, int], int] = {}
    role_table: list[tuple[tuple[int, int, int], int, int]] = []
    for i, rgb in enumerate(primary):
        bp = role_order[i]
        colour_to_bp[rgb] = bp
        role_table.append((rgb, bp, counts[rgb]))

    # Snap remaining colours to nearest primary.
    for rgb, n in ranked[3:]:
        best = min(primary, key=lambda p: rgb_dist(rgb, p))
        colour_to_bp[rgb] = colour_to_bp[best]
        role_table.append((rgb, colour_to_bp[best], n))  # logged as snapped

    return colour_to_bp, role_table


def encode_sprite(
    canvas: list[list[tuple[int, int, int, int]]],
    colour_to_bp: dict[tuple[int, int, int], int],
) -> bytes:
    out = bytearray(SPRITE_BYTES)
    for y in range(SPRITE_H):
        for byte_i in range(3):
            value = 0
            for pix in range(4):
                x = byte_i * 4 + pix
                r, g, b, a = canvas[y][x]
                if a < ALPHA_OPAQUE:
                    bp = BP_TRANS
                else:
                    bp = colour_to_bp[(r, g, b)]
                value = (value << 2) | (bp & 0x03)
            out[y * 3 + byte_i] = value
    # out[63] remains 0 (pad)
    return bytes(out)


def convert_one(png: Path, out_path: Path, *, fit: bool) -> int:
    im = Image.open(png)
    grid = load_rgba_grid(im)
    try:
        canvas, note = place_on_canvas(grid, fit=fit)
    except ValueError as e:
        print(f"error: {png}: {e}", file=sys.stderr)
        return 1

    colour_to_bp, role_table = build_colour_map(canvas)
    data = encode_sprite(canvas, colour_to_bp)
    if len(data) != SPRITE_BYTES:
        print(f"error: internal size {len(data)}", file=sys.stderr)
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(data)

    print(f"wrote {out_path} ({len(data)} bytes)")
    print(f"  {note}")
    if not role_table:
        print("  colours: (fully transparent)")
    else:
        print("  colour roles:")
        primaries = {rgb for rgb, _bp, _n in role_table[:3]}
        hints: dict[int, int] = {}
        for rgb, bp, n in role_table:
            c64 = nearest_c64(*rgb)
            tag = ROLE_NAMES[bp]
            snap = "" if rgb in primaries else " [snapped]"
            print(
                f"    RGB{rgb} ×{n} → {bp:02b} {tag}  "
                f"(nearest C64 index {c64}){snap}"
            )
            if rgb in primaries:
                hints[bp] = c64
        parts = []
        if BP_MC1 in hints:
            parts.append(f"$D025≈{hints[BP_MC1]}")
        if BP_MC2 in hints:
            parts.append(f"$D026≈{hints[BP_MC2]}")
        if BP_SPRITE in hints:
            parts.append(f"sprite≈{hints[BP_SPRITE]}")
        if parts:
            print(f"  register hint: {', '.join(parts)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="PNG → C64 multicolour sprite .bin (64 bytes)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument(
        "pngs",
        nargs="+",
        type=Path,
        help="source PNG(s)",
    )
    ap.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="output .bin path (only valid with a single input PNG; "
        "default: <png_dir>/<stem>.bin)",
    )
    ap.add_argument(
        "--fit",
        action="store_true",
        help="if larger than 12×21, nearest-neighbour scale-to-fit (with warning)",
    )
    opts = ap.parse_args()

    if opts.output is not None and len(opts.pngs) != 1:
        print("error: -o/--output requires exactly one input PNG", file=sys.stderr)
        return 1

    rc = 0
    for png in opts.pngs:
        if not png.is_file():
            print(f"error: not found: {png}", file=sys.stderr)
            rc = 1
            continue
        out = opts.output if opts.output is not None else png.with_suffix(".bin")
        if convert_one(png, out, fit=opts.fit) != 0:
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())

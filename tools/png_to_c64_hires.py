#!/usr/bin/env python3
"""Convert a PNG to C64 standard (hires) bitmap + colour-matrix binaries.

Output (default names next to the source PNG):
  <stem>_hires.bin      8000 bytes — VIC bitmap layout
  <stem>_hires_col.bin  1000 bytes — screen matrix (fg<<4 | bg per 8×8 cell)

Hires limits: 320×200, two colours per 8×8 cell. Source images are scaled/
letterboxed into 320×200; each cell is reduced to its two most common C64
palette colours (remaining pixels snapped to the nearer of those two).

Usage:
  tools/png_to_c64_hires.py assets/screens/title.png
  tools/png_to_c64_hires.py assets/screens/title.png -o assets/screens/title
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

# Pepto / VICE-style C64 palette (sRGB approximations)
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

BITMAP_W = 320
BITMAP_H = 200
CELLS_X = 40
CELLS_Y = 25
BITMAP_SIZE = 8000
COLOR_SIZE = 1000


def nearest_c64(r: int, g: int, b: int) -> int:
    best_i, best_d = 0, 1 << 30
    for i, (cr, cg, cb) in enumerate(C64_PALETTE):
        d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
        if d < best_d:
            best_d, best_i = d, i
    return best_i


def rgb_distance(c0: int, c1: int) -> int:
    r0, g0, b0 = C64_PALETTE[c0]
    r1, g1, b1 = C64_PALETTE[c1]
    return (r0 - r1) ** 2 + (g0 - g1) ** 2 + (b0 - b1) ** 2


def image_to_c64_index(im: Image.Image) -> list[list[int]]:
    """Return BITMAP_H rows × BITMAP_W C64 colour indices, letterboxed."""
    src = im.convert("RGB")
    sw, sh = src.size

    # Fit inside 320×200 preserving aspect (nearest-neighbour — pixel art).
    scale = min(BITMAP_W / sw, BITMAP_H / sh)
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    # Prefer exact width for already-320 art
    if sw == BITMAP_W and sh <= BITMAP_H:
        nw, nh = sw, sh
    resized = src.resize((nw, nh), Image.Resampling.NEAREST)

    canvas = Image.new("RGB", (BITMAP_W, BITMAP_H), (0, 0, 0))
    ox = (BITMAP_W - nw) // 2
    oy = (BITMAP_H - nh) // 2
    canvas.paste(resized, (ox, oy))

    px = canvas.load()
    rows: list[list[int]] = []
    for y in range(BITMAP_H):
        row = [nearest_c64(*px[x, y]) for x in range(BITMAP_W)]
        rows.append(row)
    return rows


def reduce_cell(pixels: list[int]) -> tuple[list[int], int, int]:
    """Reduce cell pixels to two colours → (bits_as_0_1, fg, bg).

    Screen byte = (fg << 4) | bg; bitmap bit 1 draws fg, bit 0 draws bg.
    """
    counts = Counter(pixels)
    if len(counts) == 1:
        only = pixels[0]
        # Solid cell: use colour as both; bits don't matter. Prefer bg=black
        # when the only colour is black so the matrix reads $00.
        if only == 0:
            return [0] * len(pixels), 0, 0
        return [1] * len(pixels), only, 0

    # Two most frequent; break ties by lower index for stability.
    ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    c_a, c_b = ranked[0][0], ranked[1][0]

    # Prefer non-black as fg (bit=1) when one colour is black — denser look.
    if c_a == 0:
        fg, bg = c_b, c_a
    elif c_b == 0:
        fg, bg = c_a, c_b
    else:
        fg, bg = c_a, c_b

    out: list[int] = []
    for p in pixels:
        if p == fg:
            out.append(1)
        elif p == bg:
            out.append(0)
        else:
            out.append(0 if rgb_distance(p, bg) <= rgb_distance(p, fg) else 1)
    return out, fg, bg


def encode_hires(rows: list[list[int]]) -> tuple[bytes, bytes]:
    bitmap = bytearray(BITMAP_SIZE)
    colors = bytearray(COLOR_SIZE)

    for cy in range(CELLS_Y):
        for cx in range(CELLS_X):
            cell_px: list[int] = []
            for row in range(8):
                y = cy * 8 + row
                for col in range(8):
                    x = cx * 8 + col
                    cell_px.append(rows[y][x])

            bits, fg, bg = reduce_cell(cell_px)
            colors[cy * CELLS_X + cx] = ((fg & 0x0F) << 4) | (bg & 0x0F)

            base = (cy * CELLS_X + cx) * 8
            for row in range(8):
                byte = 0
                for col in range(8):
                    if bits[row * 8 + col]:
                        byte |= 0x80 >> col
                bitmap[base + row] = byte

    return bytes(bitmap), bytes(colors)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("png", type=Path, help="source PNG")
    ap.add_argument(
        "-o",
        "--out-prefix",
        type=Path,
        default=None,
        help="output prefix (default: <png_dir>/<stem>)",
    )
    opts = ap.parse_args()

    if not opts.png.is_file():
        print(f"error: not found: {opts.png}", file=sys.stderr)
        return 1

    prefix = opts.out_prefix
    if prefix is None:
        prefix = opts.png.with_suffix("")

    im = Image.open(opts.png)
    src_w, src_h = im.size
    rows = image_to_c64_index(im)
    bitmap, colors = encode_hires(rows)

    bmp_path = Path(str(prefix) + "_hires.bin")
    col_path = Path(str(prefix) + "_hires_col.bin")
    bmp_path.write_bytes(bitmap)
    col_path.write_bytes(colors)

    # Quick stats for the agent log
    used = sorted({b >> 4 for b in colors} | {b & 0x0F for b in colors})
    print(f"wrote {bmp_path} ({len(bitmap)} bytes)")
    print(f"wrote {col_path} ({len(colors)} bytes)")
    print(f"source {src_w}x{src_h} → 320x200 hires")
    print(f"colour indices used: {used}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

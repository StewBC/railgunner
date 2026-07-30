#!/usr/bin/env python3
"""Convert a monochrome 8×8 glyph atlas PNG to a C64 charset binary.

Layout: row-major cells, each 8×8 pixels. Glyph index = row * cols + col
matches screencode order (glyph N starts at byte N*8).

Ink: opaque pixels with luma >= threshold → bit set (MSB = leftmost).
Output is padded to 2048 bytes (256 glyphs) with zeros.

Usage:
  tools/png_to_c64_charset.py assets/charset/railgunner_charset.png \\
      -o assets/charset/railgunner_charset.bin
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("error: Pillow required (pip install Pillow)", file=sys.stderr)
    sys.exit(1)

CHARSET_BYTES = 2048
GLYPH_BYTES = 8
CELL = 8


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("png", type=Path, help="atlas PNG (width and height multiples of 8)")
    ap.add_argument("-o", "--output", type=Path, required=True, help="output .bin path")
    ap.add_argument(
        "--threshold",
        type=int,
        default=300,
        help="RGB sum threshold for ink (default 300)",
    )
    args = ap.parse_args()

    im = Image.open(args.png).convert("RGBA")
    w, h = im.size
    if w % CELL or h % CELL:
        print(f"error: size {w}x{h} not multiple of 8", file=sys.stderr)
        return 1

    cols, rows = w // CELL, h // CELL
    px = im.load()
    raw = bytearray()

    for row in range(rows):
        for col in range(cols):
            for ry in range(CELL):
                byte = 0
                for rx in range(CELL):
                    r, g, b, a = px[col * CELL + rx, row * CELL + ry]
                    on = a >= 128 and (r + g + b) >= args.threshold
                    byte = (byte << 1) | (1 if on else 0)
                raw.append(byte)

    if len(raw) > CHARSET_BYTES:
        print(
            f"error: {len(raw)} bytes ({cols*rows} glyphs) exceeds {CHARSET_BYTES}",
            file=sys.stderr,
        )
        return 1
    if len(raw) < CHARSET_BYTES:
        raw.extend(bytes(CHARSET_BYTES - len(raw)))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(raw)
    print(
        f"wrote {args.output} ({CHARSET_BYTES} bytes, "
        f"{cols}x{rows} cells from {args.png.name})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

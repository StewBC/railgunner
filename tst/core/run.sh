#!/bin/sh
# Run every tst/core/*.trace. A failure exits non-zero.
# A trace is driver commands, a line ===, then one expect block per dump.
# An expect line must appear verbatim, in order, in that dump.
# A line "!glyph LO HI" rejects a cell whose glyph is in that inclusive range.
set -eu
cd "$(dirname "$0")/../.."
exec python3 - build/railgunner-core tst/core << 'PY'
import pathlib
import subprocess
import sys

bin_path = pathlib.Path(sys.argv[1])
trace_dir = pathlib.Path(sys.argv[2])
failed = 0

def dumps_of(text):
    parts = text.split("\nframe ")
    out = []
    for i, part in enumerate(parts):
        if i:
            part = "frame " + part
        if part.startswith("frame "):
            out.append(part.splitlines())
    return out

def check(trace, output):
    raw = trace.read_text()
    if "\n===\n" not in raw and not raw.startswith("===\n"):
        return "missing === expect section"
    command, _, expect = raw.partition("\n===\n")
    proc = subprocess.run([str(bin_path), "/dev/stdin"], input=command,
                          capture_output=True, text=True)
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout).strip()
        return "driver exit %s: %s" % (proc.returncode, err)
    output.append(proc.stdout)
    blocks = []
    cur = []
    for line in expect.splitlines():
        if line == "---":
            blocks.append(cur)
            cur = []
        elif line.strip() == "" or line.startswith("#"):
            continue
        else:
            cur.append(line)
    blocks.append(cur)
    got = dumps_of(proc.stdout)
    if len(got) != len(blocks):
        return "dumps %d != expect blocks %d" % (len(got), len(blocks))
    for bi, (dump, block) in enumerate(zip(got, blocks)):
        pos = 0
        for pat in block:
            if pat.startswith("!glyph "):
                lo_s, hi_s = pat.split()[1:]
                lo, hi = int(lo_s), int(hi_s)
                for ln in dump:
                    if not ln.startswith("cell "):
                        continue
                    glyph = int(ln.split()[3])
                    if lo <= glyph <= hi:
                        return "dump %d has %s" % (bi + 1, ln)
                continue
            found = None
            for i in range(pos, len(dump)):
                if dump[i] == pat:
                    found = i
                    break
            if found is None:
                return "dump %d missing %s" % (bi + 1, pat)
            pos = found + 1
    return None

traces = sorted(trace_dir.glob("*.trace"))
if not traces:
    print("no traces in %s" % trace_dir)
    sys.exit(1)
for trace in traces:
    err = check(trace, [])
    if err:
        failed += 1
        print("FAIL %s: %s" % (trace.name, err))
    else:
        print("ok %s" % trace.name)
sys.exit(1 if failed else 0)
PY

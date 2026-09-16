#!/bin/sh
# check that tools/pack-symbols.sh output pastes cleanly into mach.toml: it
# parses as a TOML array, round-trips the names in order, keeps the manifest
# layout, and respects the width. the sample is every symbol the manifest
# already claims, so the real names (`$`, long objc selectors) are covered.
set -eu
cd "$(dirname "$0")/.."

width=80
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - mach.toml >"$tmp/names" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    manifest = tomllib.load(f)
for entry in manifest["link"].values():
    for name in entry.get("symbols", []):
        print(name)
PY
# an item wider than the limit must still land on its own line
printf '%s\n' "$(printf 'x%.0s' $(seq 1 90))" >>"$tmp/names"

tools/pack-symbols.sh "$width" <"$tmp/names" >"$tmp/body"

python3 - "$tmp/names" "$tmp/body" "$width" <<'PY'
import re, sys, tomllib
names = open(sys.argv[1]).read().splitlines()
body = open(sys.argv[2]).read()
width = int(sys.argv[3])
parsed = tomllib.loads("symbols = [\n" + body + "]\n")["symbols"]
if parsed != names:
    sys.exit("pack-symbols: names do not round-trip")
item = r'"[^"]*",'
for n, line in enumerate(body.splitlines(), 1):
    if not re.fullmatch(r"    " + item + r"(?: " + item + r")*", line):
        sys.exit(f"pack-symbols: line {n} breaks the manifest layout: {line!r}")
    if len(line) > width and " " in line.strip():
        sys.exit(f"pack-symbols: line {n} is {len(line)} columns: {line!r}")
print(f"pack-symbols: {len(names)} names in {len(body.splitlines())} lines ok")
PY

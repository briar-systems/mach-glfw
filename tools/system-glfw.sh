#!/bin/sh
# switch mach.toml to the opt-in system GLFW in place of the vendored archive.
# glfw.c attributes its imports to the [link.glfw] and [link.glfw-win] keys, so
# the swap rewrites those two entries from the vendored archive to the system
# library under the same keys, and every consumer receives them as before.
set -eu
cd "$(dirname "$0")/.."

python3 - mach.toml <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
vendored = 'path = "{project.work}/vendor/glfw/libglfw.a"'
edits = {
    ("link.glfw", 'source = "local"'): 'source = "system"',
    ("link.glfw", vendored): 'name = "glfw"',
    ("link.glfw-win", 'source = "local"'): 'source = "system"',
    ("link.glfw-win", vendored): 'name = "glfw3.dll"',
}
done = set()
section = None
for i, line in enumerate(lines):
    header = re.fullmatch(r"\[([^\]]+)\]", line)
    if header:
        section = header.group(1)
    key = (section, line)
    if key in edits:
        lines[i] = edits[key]
        done.add(key)
missing = [s + ": " + l.strip() for s, l in edits if (s, l) not in done]
if missing:
    sys.exit("system-glfw: mach.toml is not in its vendored form, missing " + "; ".join(missing))
open(path, "w").write("\n".join(lines))
PY
echo "mach.toml now links the system GLFW"

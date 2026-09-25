#!/bin/sh
# switch mach.toml to the opt-in system GLFW in place of the vendored archive.
# a consumer receives the library's exported link entries whatever the artifact
# names, so the swap moves the export from [link.glfw-static] to the system
# entries as well as swapping the artifact's own link list.
set -eu
cd "$(dirname "$0")/.."

python3 - mach.toml <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
edits = {
    ("artifact.glfw", '    "glfw-static",'): '    "glfw", "glfw-win",',
    ("link.glfw-static", "export = true"): "export = false",
    ("link.glfw", "export = false"): "export = true",
    ("link.glfw-win", "export = false"): "export = true",
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

#!/usr/bin/env bash
# a darwin link that failed before the demo existed is almost always a missing
# `symbols` attribution, so print the mapping read off the SDK for it
set -euo pipefail

archive=out/darwin/debug/vendor/glfw/libglfw.a
if [ "$MACH_CI_LEG" = x86_64-darwin ] && [ -f "$archive" ] && [ ! -f out/darwin/debug/bin/demo ]; then
  bash tools/darwin-symbol-map.sh "$archive" || true
fi

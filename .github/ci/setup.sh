#!/usr/bin/env bash
# per-leg toolchains the build needs: zig carries the windows sysroot and the
# mingw runtime, and a brewed glfw would shadow the vendored archive on darwin
set -euo pipefail

zig_version=0.16.0

install_zig() {
  local name="zig-x86_64-$1-$zig_version" root="$RUNNER_TEMP/zig"
  mkdir -p "$root"
  case "$1" in
    linux)
      curl -fsSL "https://ziglang.org/download/$zig_version/$name.tar.xz" | tar -xJ -C "$root"
      echo "$root/$name" >> "$GITHUB_PATH"
      ;;
    windows)
      curl -fsSL "https://ziglang.org/download/$zig_version/$name.zip" -o "$root/zig.zip"
      pwsh -NoProfile -Command "Expand-Archive -Path '$(cygpath -w "$root/zig.zip")' -DestinationPath '$(cygpath -w "$root")' -Force"
      cygpath -w "$root/$name" >> "$GITHUB_PATH"
      ;;
  esac
}

case "$MACH_CI_LEG" in
  windows-cross) install_zig linux ;;
  x86_64-windows) install_zig windows ;;
  x86_64-darwin)
    if brew list --versions glfw >/dev/null 2>&1; then
      brew uninstall --ignore-dependencies glfw
    fi
    ;;
esac

#!/usr/bin/env bash
# per-leg checks on what the standard build produced
set -euo pipefail

# mach builds only the default artifact, the library, without a selector, so the
# demo every leg checks below is built here
demo_args=(--bin demo --target "$MACH_CI_TARGET")
if [ "$MACH_CI_LEG" = x86_64-darwin ]; then
  demo_args+=(--pie)
fi
for profile in $MACH_CI_PROFILES; do
  "$MACH_COMPILER" build "$MACH_CI_PROJECT" --profile "$profile" "${demo_args[@]}"
done

# the demo's --smoke run prints the linked GLFW version and a success line
smoke() {
  local exe=$1 log=$2
  "${@:3}" "$exe" --smoke | tee "$log"
  grep -q '^GLFW 3\.4\.0$' "$log"
  grep -q '^smoke ok$' "$log"
  echo "$exe: smoke ok"
}

case "$MACH_CI_LEG" in
  x86_64-linux)
    tools/surface.sh check
    echo "surface up to date"
    tools/test-pack-symbols.sh
    for profile in $MACH_CI_PROFILES; do
      exe="out/linux-x86_64/$profile/bin/demo"
      archive="out/linux-x86_64/$profile/vendor/glfw/libglfw.a"
      ldd "$exe" > "$RUNNER_TEMP/glfw-$profile.ldd"
      if grep -qi glfw "$RUNNER_TEMP/glfw-$profile.ldd"; then
        echo "::error::$exe retains a dynamic GLFW dependency"
        exit 1
      fi
      llvm-nm --defined-only "$archive" > "$RUNNER_TEMP/glfw-$profile.nm"
      grep -q ' T glfwInit$' "$RUNNER_TEMP/glfw-$profile.nm"
      echo "$exe: no dynamic glfw, archive defines glfwInit"
      smoke "$exe" "$RUNNER_TEMP/glfw-$profile.log" xvfb-run -a
    done
    ;;
  windows-cross)
    exes=()
    for profile in $MACH_CI_PROFILES; do
      exes+=("out/windows/$profile/bin/demo")
      llvm-nm --defined-only "out/windows/$profile/vendor/glfw/libglfw.a" > "$RUNNER_TEMP/glfw-$profile.nm"
      grep -q ' T glfwInit$' "$RUNNER_TEMP/glfw-$profile.nm"
    done
    tools/check-windows-pe.sh "${exes[@]}"
    echo "${exes[*]}: PE imports and archives ok"
    ;;
  x86_64-windows)
    for profile in $MACH_CI_PROFILES; do
      smoke "out/windows/$profile/bin/demo" "$RUNNER_TEMP/glfw-native-$profile.log"
    done
    ;;
  x86_64-darwin)
    for profile in $MACH_CI_PROFILES; do
      exe="out/darwin/$profile/bin/demo"
      # otool -L opens with the binary's own path, which runs through this
      # checkout's name, so only the dependency lines are inspected
      otool -L "$exe" | tail -n +2 > "$RUNNER_TEMP/glfw-static-$profile.otool"
      if grep -qi glfw "$RUNNER_TEMP/glfw-static-$profile.otool"; then
        echo "::error::$exe retains a dynamic GLFW dependency"
        cat "$RUNNER_TEMP/glfw-static-$profile.otool"
        exit 1
      fi
      echo "$exe: no dynamic glfw"
      smoke "$exe" "$RUNNER_TEMP/glfw-static-$profile.log"
    done
    ;;
esac

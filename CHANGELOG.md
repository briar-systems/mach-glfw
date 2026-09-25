# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.1] - 2026-09-25

### Changed
- layout: The library surface moves from `src/glfw.mach` to
  `src/lib/glfw.mach`, following the family layout for artifact entries, and
  `tools/surface.sh` generates it there (#89). A bare `use glfw;` is
  unaffected, since it binds the default artifact's entry wherever that lives,
  and every other module path (`glfw.c`, `glfw.core`, `glfw.window`, ...) is
  unchanged. The entry module's own full path becomes `glfw.lib.glfw` in place
  of `glfw.glfw`. `src/lib/` is the artifact that builds a compiled library to
  ship, not the surface a direct dependency names, so a consumer that imported
  `use glfw.glfw;` imports the bare `use glfw;` instead. `mach test . --list`
  collects the same 3 tests as before.
- demo: The demo leaves the library for `demo/window/`, its own project with
  its own std pin and a path dependency on the repository root, so the library
  declares no binary (#89). `[artifact.demo]` and `src/main.mach` are gone, the
  demo is `demo/window/src/bin/main.mach` and builds to `bin/window`, and it
  imports the bare `use glfw;` like any consumer. The vendored archive and
  every platform link stay with the library and cascade to consumers as
  before, so a consumer still declares nothing beyond the dependency. CI builds
  the demo as a subproject on every leg and runs the same smoke, archive and
  PE checks on it.
- manifest: The system-GLFW opt-in is `tools/system-glfw.sh`, which also moves
  `export = true` from `[link.glfw-static]` to `[link.glfw]` and
  `[link.glfw-win]`. A consumer receives every exported entry whatever the
  library's artifact names, so swapping the artifact's link list alone never
  reached a consumer, and the demo is now one (#89).

### Fixed
- readme: The dependency stanza selects releases with `version = "^0.8.0"`, as
  `mach dep add` writes it, in place of following `branch/main`, and shows the
  `mach dep add` command first. The requirement line names Mach 5.12 and std
  8.1 in place of the stale Mach 5.5 and std 5.7 (#83).

## [0.8.0] - 2026-09-25

### Changed
- toolchain: Builds with std 8.1 (`[dep.std]` `version = "^8.1"`, pinned at
  v8.1.0 by the `dep/std` gitlink) and declares `[project].mach = "^5.12"`,
  which std 8 requires. 8.1.0 is the floor because 8.0.0 overwrote the C
  runtime's thread pointer on linux, so `glfwInit` segfaulted in `dlopen`
  (briar-systems/mach-std#915). Resolution is flat, so a consumer of glfw must
  move to mach-std 8.1 and mach 5.12 with it. std 7.0.0's and 8.0.0's breaking
  changes (`io.runtime.make` taking an allocator, `data.toml.Value` and
  `buffers.SecretSource` growing, the page, testing and arena allocators
  honouring `align`) touch no glfw call site, so no binding changed (#84).
- manifest: mach 5.12 tests only the selected artifact's closure, with that
  artifact's links (briar-systems/mach#3813). `glfw.mach` now uses
  `std.runtime`, and `[artifact.glfw]` names the same link list as the demo,
  so `mach test .` links and still runs all three tests. `mach build .` builds
  only the library, the default artifact, so CI builds the demo with
  `--bin demo` (#84).

## [0.7.0] - 2026-09-19

### Changed
- toolchain: Builds with std 6.0 (`[dep.std]` `version = "^6.0"`, pinned at
  v6.0.0 by the `dep/std` gitlink) and declares `[project].mach = "^5.9"`.
  std 6.0.0's breaking changes (natural ordering for sort, heap, map and set,
  `ct` width generics, `buffers.Budgets` by value) touch no glfw call site,
  so no source changed and glfw's own surface is unchanged.

## [0.6.0] - 2026-09-19

### Changed
- toolchain: Builds with std 5.7 (`[dep.std]` `version = "^5.7.1"`, pinned by
  the `dep/std` gitlink) and declares
  `[project].mach = "^5.5.2"`, the floor std 5.7.1 itself requires. glfw's
  own code needs nothing newer than 5.3, and no source changed. A consumer on
  std 5 overrides every dependency's std, so a library still on std 4 broke
  under it. The dependency is a range rather than an exact tag so a root on a
  later std 5.x resolves without conflict.
- manifest: `[project].mach = "^5.3"` declares the compiler range, so Mach 5.3
  and later build the project without the missing-range warning. Mach 5.2
  refuses the key.
- license: The copyright holder is Briar Systems LLC. The MIT terms are
  unchanged.
- ci: A pushed `v*` tag is released by `cd.yml`, which uses the family's
  shared release workflow (briar-systems/.github `mach-release.yml`). It
  checks the tag against `mach.toml` and this changelog, runs the full CI tier,
  and publishes the release with the version's changelog section as notes.
  A dispatch rehearses the same path.

## [0.5.1] - 2026-09-16

### Changed
- toolchain: Builds with Mach 5.2 and std 4.0 (`[dep.std]` at `tag/v4.0.0`).
  std 4.0 requires Mach 5.2.0 or later. None of the names std 4.0 removed are
  used here, and the public API is unchanged.
- tools: `darwin-symbol-map.sh` packs each generated `symbols` array the way
  the manifest lays it out, so the output pastes straight into `mach.toml`.
  The packing lives in `tools/pack-symbols.sh`, and CI checks that its output
  parses and round-trips. Based on #41 by @Angluca.

## [0.5.0] - 2026-09-16

### Changed
- toolchain: Builds with Mach 5.1 and std 3.2. The dependency is `[dep.std]`,
  pinned by the committed `dep/std` gitlink, and `mach.lock` is gone. Consumers
  declare this project as `[dep.glfw]`.
- manifest: A default `glfw` static library artifact rooted at `glfw.mach` binds
  a bare `use glfw;`. The smoke executable is now the `demo` artifact
  (`bin/demo`).
- api: **Breaking.** Refusals and absence are tags instead of sentinels. The raw
  `glfw.c` layer is unchanged.
  - module `glfw.err` and its code constants are replaced by `glfw.error`:
    `tag Error`, `error_from_code(i32) opt[Error]`, `take_error() opt[Error]`
    and `take_refusal() Error`. `core.get_error` is removed.
  - `init()` and `update_gamepad_mappings()` return `err[Error]`.
  - `create_window()`, `open_window()`, `create_cursor()` and
    `create_standard_cursor()` return `res[T, Error]`.
  - `create_window_surface(instance, window)` returns
    `res[u64, SurfaceError]` and no longer takes an out-param. `vulkan.SUCCESS`
    is removed.
  - `no_window()`, `no_monitor()`, `no_cursor()`, `window_is_valid()`,
    `monitor_is_valid()` and `cursor_is_valid()` are removed. Optional handle
    arguments are `opt[T]`: `create_window()` monitor and share,
    `set_window_monitor()`, `make_context_current()` and `set_cursor()`.
  - `get_primary_monitor()`, `get_window_monitor()` and `get_current_context()`
    return `opt` handles. `get_window_title()`, `get_monitor_name()`,
    `get_key_name()`, `get_clipboard_string()`, `get_joystick_name()`,
    `get_joystick_guid()` and `get_gamepad_name()` return `opt[str]`.
    `get_video_mode()` and `get_gamma_ramp()` return `opt` pointers,
    `get_key_scancode()` returns `opt[i32]`, and `get_proc_address()` and
    `get_instance_proc_address()` return `opt[ptr]`.
  - `get_gamepad_state(jid)` returns `opt[Gamepadstate]` instead of filling an
    out-param.
  - `set_clipboard_string()` and `get_clipboard_string()` drop the window
    argument GLFW 3.4 ignores.
- build: Windows executables import `advapi32.dll`, which std 3.2 links for
  owner-only file modes. The PE check expects it.
- ci: One `ci.yml` calls the family's tiered pipeline
  (briar-systems/.github `mach-lib.yml`) and ends in a `gate` job. A pull
  request into dev runs the linux leg, a pull request into main runs every
  leg plus the darwin system-GLFW job, and nothing runs on push.

### Fixed
- build: `build-glfw.sh` compiles into a scratch directory, so the step writes
  only its declared archive under the output tree.
- link: The darwin `libSystem` link entry uses std's logical library name, so
  both claim libSystem imports through one library.
- tools: `surface.sh` emits the generated imports in the order `mach fmt`
  produces, so the surface check agrees with the formatter.

## [0.4.0] - 2026-08-08

### Added
- vulkan: `glfw.vulkan` exposes the four GLFW/Vulkan interop entry points — `vulkan_supported`, `required_instance_extensions`, `create_window_surface`, and `get_instance_proc_address`. GLFW owns the window and therefore the platform surface a swapchain presents to, and the bindings previously exposed none of it, so a Vulkan renderer could not create a surface for a GLFW window. The surface is returned as a `u64` because `VkSurfaceKHR` is non-dispatchable and therefore 64-bit on every platform; typing it would force a dependency on a Vulkan binding this library does not have.
- build: Vendor GLFW 3.4 and build it into target-specific static archives for
  Linux, Windows, and Darwin.
- ci: Build and run the vendored path on Linux and Darwin, cross-build and
  inspect the Windows PE, and exercise the Darwin system-library fallback.

### Fixed
- link: Attributed every raw GLFW import to the stable `glfw` dependency name
  across Linux, Windows, and Darwin.
- link: Materialized Zig's MinGW runtime archives and attributed GLFW's Win32
  and UCRT imports so Windows builds remain self-contained.
- link: Attributed the vendored Cocoa backend's foreign imports to libSystem,
  libobjc, and the Darwin frameworks that provide them.

### Changed
- manifest: Re-touched to RFC-exact totality per mach#1964/mach#1979.
- distribution: The vendored static GLFW build is now the default; system GLFW
  remains an explicit opt-in fallback.

## [0.3.0] - 2026-07-07

### Changed
- manifest: Migrated manifest layout to comply with the V2 manifest spec.
- dependency: Updated `mach-std` dependency to git URL.

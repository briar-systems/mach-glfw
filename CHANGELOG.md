# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
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

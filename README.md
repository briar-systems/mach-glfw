# mach-glfw

Mach bindings for [GLFW](https://www.glfw.org/) 3.4: a thin raw C-ABI layer
plus an idiomatic Mach API on top. Project id is `glfw`, so consumers reach
everything as `glfw.*`.

```mach
use glfw;
use std.types.error.err;
use std.types.option.opt;
use std.types.result.res;

fun example() err[glfw.Error] {
    val started: err[glfw.Error] = glfw.init();
    if (sel started.err) { ret started; }
    val opened: res[glfw.Window, glfw.Error] = glfw.open_window(1280, 720, "hello");
    if (sel opened.err) {
        glfw.terminate();
        ret err[glfw.Error].err{opened.err};
    }
    val w: glfw.Window = opened.ok;
    glfw.make_context_current(opt[glfw.Window].some{w});
    for (!glfw.window_should_close(w)) {
        glfw.swap_buffers(w);
        glfw.poll_events();
    }
    glfw.destroy_window(w);
    glfw.terminate();
    ret err[glfw.Error].ok{};
}
```

Consuming projects vendor the bindings as a normal Mach dependency. GLFW is
vendored and linked statically, and the link requirements cascade from
`mach-glfw`'s own manifest, so consumers declare nothing beyond the dependency
itself. Add it with `mach dep add`, which declares the dependency at a caret
range over the newest compatible release and realizes it:

```sh
mach dep add . glfw --git https://github.com/briar-systems/mach-glfw
```

That writes this stanza to `mach.toml`:

```toml
[dep.glfw]
git = "https://github.com/briar-systems/mach-glfw"
version = "^0.8.0"
```

Requires Mach 5.12 or newer and std 8.1.

## Goals

- Complete coverage of the GLFW 3.4 window/input/monitor API.
- Zero-cost: the idiomatic layer is thin wrappers over `ext fun` imports;
  no allocation, no registries, no hidden state beyond what GLFW itself keeps.
- Mach-idiomatic naming and types (`snake_case`, `bool`, `str`, records),
  while staying recognizable to anyone who knows the GLFW C API.

## Non-goals (v1)

- Native-handle access (`glfw3native.h`) — platform-specific, deferred.
- An OpenGL loader. `get_proc_address` exposes `glfwGetProcAddress`; GL
  bindings belong in a separate project.
- `glfwInitAllocator` — Mach-side custom allocators for GLFW are deferred.

## Architecture

Two layers:

```
src/
  c.mach          raw layer: every ext fun import, C types verbatim
  lib/
    glfw.mach     library surface and artifact entry: generated, forwards
                  every public symbol
  core.mach       init/terminate, version, events, time, context
  error.mach      the Error tag and the error query
  hint.mach       init & window hint ids and values
  window.mach     Window + lifecycle, attributes, context, window callbacks
  monitor.mach    Monitor, video modes, gamma
  input.mach      keys, mouse, Cursor objects, clipboard, joystick, gamepad
  key.mach        key code, action, and modifier constants
  mouse.mach      mouse button and cursor shape constants
  joystick.mach   joystick, hat, and gamepad constants
  vulkan.mach     Vulkan support query, instance extensions, surface creation
demo/
  window/         the demo, its own project that consumes this library
```

### Raw layer — `glfw.c`

One file mirroring `glfw3.h` declaration order. Every GLFW function is a
`pub ext fun` attributed to the stable logical library name `glfw`, with its
C name and C-faithful types:

```mach
#[library("glfw")]
pub ext fun glfwCreateWindow(width: i32, height: i32, title: *u8, monitor: ptr, share: ptr) ptr;
```

Type mapping:

| C | Mach |
|---|---|
| `int`, `enum` | `i32` |
| `unsigned int` | `u32` |
| `float` / `double` | `f32` / `f64` |
| `const char*` | `*u8` |
| `GLFWwindow*`, `GLFWmonitor*`, `GLFWcursor*` (opaque) | `ptr` |
| `GLFWvidmode*`, `GLFWimage*`, … (transparent structs) | pointer to a Mach `rec` with identical layout |
| callback function pointers | `fun(...)` types, C-faithful signatures |
| `uint64_t` | `u64` |

Transparent structs (`GLFWvidmode`, `GLFWgammaramp`, `GLFWimage`,
`GLFWgamepadstate`) are declared as `rec`s in `c.mach` with C layout and
re-exported by the idiomatic layer.

No constants live in `c.mach` — they belong to the domain modules, which own
the names (`key.SPACE`, not `GLFW_KEY_SPACE`; the `glfw.` namespace already
says "GLFW").

### Idiomatic layer

Naming is mechanically derived from the C API, so any GLFW reference maps
directly and a generator could reproduce the surface: functions are the C
name minus the `glfw` prefix, snake_cased (`glfwCreateWindow` →
`create_window`, `glfwWindowShouldClose` → `window_should_close`); constants
are the C macro minus only `GLFW_` (`GLFW_KEY_ESCAPE` → `KEY_ESCAPE`). Every
name is globally unique, which lets `lib/glfw.mach` flatten all of them onto one
namespace.

A small set of convenience helpers has no C counterpart:
`window_from_handle()` / `monitor_from_handle()` (rewrap raw callback
pointers), `open_window()` (windowed `create_window` sugar), and the
`glfw.error` query functions.

Types:

- Opaque handles wrap in single-field records: `pub rec Window { handle: ptr; }`,
  `Monitor`, `Cursor`. Passed **by value** (one pointer wide). A handle record
  always holds a live handle. An optional one is `opt[Window]`, `opt[Monitor]`
  or `opt[Cursor]`, as an argument (`create_window`'s monitor and share,
  `set_window_monitor`, `make_context_current`, `set_cursor`) and as a result
  (`get_primary_monitor`, `get_window_monitor`, `get_current_context`).
- `bool` (`std.types.bool`) replaces `GLFW_TRUE`/`GLFW_FALSE` returns and
  parameters; `str` (`std.types.string`) replaces `const char*`. Strings
  returned by GLFW are GLFW-owned; the docs state their lifetime.
- Scalar out-params stay out-params (`get_window_size(w, ?width, ?height)`),
  the Mach idiom for multiple returns.

Error model:

- `glfw.error.Error` is a closed tag with one case per GLFW error code, plus
  `unrecognized` (a code this binding does not name) and `unreported` (GLFW
  refused without recording one).
- Calls GLFW can refuse clear the thread's last error, make the call, and
  report the recorded error on refusal: `init` and `update_gamepad_mappings`
  return `err[Error]`, `create_window`, `open_window`, `create_cursor` and
  `create_standard_cursor` return `res[T, Error]`. `create_window_surface`
  returns `res[u64, SurfaceError]`, which carries either a GLFW refusal or the
  VkResult of the platform surface call.
- Absence is `opt`: strings GLFW may not have (`get_key_name`,
  `get_clipboard_string`, `get_joystick_name`, ...), single GLFW-owned records
  (`get_video_mode`, `get_gamma_ramp`, `get_gamepad_state`), and function
  addresses (`get_proc_address`, `get_instance_proc_address`). Arrays returned
  with a count report emptiness through the count.
- Everything else follows GLFW semantics: misuse fires the error callback and
  sets the last error, which `take_error()` reads and clears. The callback
  receives the raw code, and `error_from_code` classifies it.
- The raw `glfw.c` layer keeps GLFW's C results unchanged.

Callback model:

- Callbacks are plain Mach functions; Mach compiles to the SysV C ABI on the
  supported target, so a `fun` passes directly to GLFW. A display-free test
  in `core.mach` pins this ABI guarantee in CI (GLFW invokes a Mach error
  callback).
- Callback `def` types live in the module that owns the setter and use **raw
  C-faithful signatures** — first parameter `ptr` (the `GLFWwindow*`), not
  `Window`, because GLFW is the caller and the C ABI is the contract:

  ```mach
  pub def KeyFun: fun(ptr, i32, i32, i32, i32);    # window, key, scancode, action, mods
  pub fun set_key_callback(w: Window, cb: KeyFun) { c.glfwSetKeyCallback(w.handle, cb); }
  ```

  Inside a callback, rewrap with `window_from_handle(h)`. Setters return
  nothing (the previous-callback return is dropped; v1 keeps the surface
  small); clear one by passing nil cast to the callback type
  (`nil::KeyFun`).
- There is no closure capture in Mach; callback state goes in module-level
  `var`s or through `set_window_user_pointer` / `get_window_user_pointer`
  (`glfwSetWindowUserPointer`).

### Library surface — `lib/glfw.mach`

`lib/glfw.mach` re-exports every public symbol of every split module (Mach has no
import splat, so the surface is explicit `fwd` lines). It is generated by
`tools/surface.sh gen` and CI fails if it drifts from the split modules
(`tools/surface.sh check`). It is the entry of the default `[artifact.glfw]`
static library, so a bare `use glfw;` resolves to it, binding the leaf as `glfw` and giving the whole
API as `glfw.init()`, `glfw.create_window(...)`, `glfw.KEY_ESCAPE`. The split
modules (`glfw.core`, `glfw.window`, …) remain importable individually for
smaller dependency surfaces.

### Requirements and vendoring

GLFW 3.4 is vendored under `vendor/glfw/` and compiled into a static archive
per target, so a shipped binary carries GLFW itself and end users need nothing
installed. `[step.build-glfw]` runs `tools/build-glfw.sh`, which selects the
compilation units and defines for the active build cell from `MACH_TARGET_OS`;
`[link.glfw-static]` consumes the resulting `libglfw.a`.

`vendor/glfw/UPSTREAM` records the pinned tag and how to bump it. The vendored
tree carries GLFW's zlib licence as `vendor/glfw/LICENSE.md`.

**Build-time toolchain.** A target matching the host builds with the system
`cc`; any other target goes through [`zig`](https://ziglang.org) (`zig cc`,
`zig ar`), which supplies the cross sysroots. `CC`, `AR` and `SYSROOT`
override the C build defaults; `ZIG` selects the Zig executable used to
materialize the Windows runtime archives.

Per target:

| Target | Also needs |
|---|---|
| linux | X11, Wayland and xkbcommon **headers**, plus `wayland-scanner` (`xorg-dev libwayland-dev libwayland-bin libxkbcommon-dev` on Debian/Ubuntu; `libx11 wayland libxkbcommon` on Arch) |
| windows | `zig`; its mingw-w64 headers and static CRT supply the Win32 declarations and ordinary C runtime routines. `tools/materialize-mingw-runtime.sh` asks that Zig invocation for its target-matched MinGW/compiler runtime archives; the manifest maps GLFW's remaining kernel32, user32, gdi32, shell32, and UCRT imports to their DLLs |
| darwin | the Apple SDK, so a macOS host or `MACOS_SDK` pointing at an SDK root. The manifest attributes the archive's measured foreign imports to libSystem, libobjc, AppKit, Foundation, CoreFoundation, CoreGraphics, CoreServices, and IOKit; Cocoa, CoreVideo, and OpenGL remain declared framework dependencies. `zig` carries no framework headers and Apple's SDK is not redistributable, so darwin cannot be cross-built from linux |

Both the X11 and Wayland backends are compiled in on linux; `glfwInit` picks
one at runtime, as a distro build of GLFW does. The X11, Wayland and OpenGL
client libraries stay **dynamic system dependencies** — GLFW `dlopen`s them by
soname and never links them — so they are not statically bound and are not
listed in the manifest. Only libc-level libraries (`pthread`, `m`, `dl`, `rt`)
are linked on linux. Windows links GLFW's ordinary MinGW/compiler runtime code
statically, then imports the measured kernel32, user32, gdi32, shell32, and UCRT
surface from the operating system.

Every raw GLFW import uses `#[library("glfw")]`, the stable logical dependency
name rather than a platform filename. Static builds resolve those declarations
from the vendored archive. The system fallback maps the same identity to the
selected target's concrete dependency: the resolved ELF SONAME (for example
`libglfw.so.3`) on Linux, `glfw3.dll` on Windows, or the resolved dylib's
`LC_ID_DYLIB` install name on Darwin.

The linux archive is currently built with `-fno-pic -fno-PIE` because Mach does
not yet support ELF's relaxable `R_X86_64_REX_GOTPCRELX` relocation
(mach#2534), so linux consumers cannot link this archive with `--pie` yet.
Darwin retains the toolchain's normal PIC code generation.

**System-GLFW fallback.** The `system` entries remain declared in `mach.toml`
as an opt-in. `tools/system-glfw.sh` rewrites the manifest to build against an
installed GLFW ≥ 3.4 (`pacman -S glfw`, `apt install libglfw3-dev`, …) instead
of the vendored source. A consumer receives every link entry the library
exports, whatever the library's artifact names, so the script swaps
`"glfw-static"` for `"glfw"` and `"glfw-win"` in `[artifact.glfw]` and moves
`export = true` from `[link.glfw-static]` onto the two system entries.

CI builds both profiles on all three operating systems. Linux and Darwin run
`glfwInit` through the demo's `--smoke` mode; the Darwin lane exercises both
the vendored archive and the system dylib. Windows is cross-built from Linux
for exact PE import/base-relocation inspection and built again on a native
Windows runner, where both profiles execute the real `glfwInit` path. Darwin
builds run natively because the Apple SDK needed by the Objective-C backend
cannot be redistributed to a Linux cross-runner.

## Scope of GLFW coverage

| Domain | In v1 |
|---|---|
| Init/terminate, init hints, version, error | yes |
| Window: create/destroy, hints, attributes, pos/size/limits/aspect, title, icon, show/hide/focus/minimize/maximize/attention, opacity, monitor mode, user pointer, all callbacks | yes |
| Context: make current, swap buffers/interval, proc address, extension query | yes |
| Monitor: enumerate, primary, pos/workarea/physical/scale/name, video modes, gamma, monitor callback | yes |
| Input: input modes, raw mouse motion, key/scancode/name, mouse buttons, cursor pos/enter, custom + standard cursors, clipboard, time/timer, key/char/mouse/scroll/drop callbacks | yes |
| Joystick/gamepad: presence, axes/buttons/hats, GUID, gamepad mappings/state, joystick callback | yes |
| Vulkan: support query, required instance extensions, surface creation, instance proc address | yes |
| Native handles | no (deferred) |

## Demo

`demo/window/` is its own project, so the library declares no binary. It
consumes the library the way any project would: `[dep.glfw]` is a path
dependency on this checkout, `../..`, beside its own pin of std, it imports the
bare `use glfw;`, and the vendored archive's links cascade to it from the
library's manifest. Error callback installed, window + OpenGL
context, `glClearColor`/`glClear` loaded through `get_proc_address`, animated
clear color, ESC closes via key callback. Serves as living documentation of
the callback, context, and event-loop idioms.

Pass `--smoke` to initialize GLFW, report its version, and terminate without
opening a window. This is intended for runtime/linker validation in CI. Build
and run it from the repository root:

```sh
mach dep pull demo/window
mach build demo/window
mach run demo/window -- --smoke
```

A path dependency is a copy, so run `mach dep pull demo/window` again after
changing the bindings or the manifest.

## Tests

`test` blocks live beside the code they cover and are display-free: the
version query and the pre-init error path (which doubles as the C→Mach
callback ABI regression test). Paths that need a live window — context
creation, swap, input events — are exercised by running the demo, not by
`mach test`.

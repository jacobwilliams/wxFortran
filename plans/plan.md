# wxFortran: project plan

Modern Fortran bindings for [wxWidgets](https://github.com/wxWidgets/wxWidgets),
using the [qt-fortran](https://github.com/jacobwilliams/qt-fortran) project as a
development and architecture reference.

## Goals

- Let Fortran applications create and manage native wxWidgets desktop GUIs
  through an idiomatic, documented Fortran API.
- Keep the language boundary small and explicit: Fortran
  `iso_c_binding` interfaces call a C-compatible ABI implemented by a small
  C++ shim, which in turn calls wxWidgets.
- Make development reproducible with pixi, package the Fortran library for fpm
  consumers where practical, and test the public API on supported platforms.
- Add functionality incrementally, prioritizing common desktop application
  workflows over wrapping all of wxWidgets.

## Non-goals for the first release

- A complete or source-compatible translation of the wxWidgets C++ API.
- Automatic wrapping of the entire wxWidgets interface/header tree.
- Custom native controls, OpenGL, advanced data views, or platform-specific
  APIs before the core event and lifetime model is proven.
- Hiding wxWidgets' normal platform requirements: applications still need the
  appropriate native GUI runtime and libraries.

## Guiding decisions

These are initial proposals. Phase 0 must validate the build and lifetime
assumptions before they become compatibility commitments.

| Topic | Proposal |
|---|---|
| Public API | Modern Fortran derived types and type-bound procedures; expose a small umbrella module such as `use wx`. |
| Language boundary | `bind(C)` interfaces and interoperable scalar/string types only; never expose C++ classes, references, templates, or exceptions to Fortran. |
| C++ shim | Keep it thin and hand-written for the initial API. Catch C++ exceptions at the boundary and return a documented status/error result rather than allowing an exception to cross C. |
| Object handles | Pass opaque `type(c_ptr)` handles. Define parent/child ownership, explicit destruction, and invalidation behavior before exposing wrappers; do not rely on Fortran finalizers to destroy parent-owned GUI objects. |
| Events | Start with a small, typed event surface. Use C-compatible callback trampolines plus an opaque user context, and document callback and context lifetimes. |
| Build | Use pixi for the development toolchain and fpm for the Fortran package. The Phase 0 spike selects how wxWidgets and the C++ shim are built and linked on each platform. |
| Binding generation | Hand-write the MVP. Consider declarative specifications and generated low-level/high-level bindings only after repeated patterns and API conventions are stable. |
| Platform support | Aim for Linux/GTK, macOS/Cocoa, and Windows/MSW, but advertise a platform only after its complete build, link, launch, and test path passes CI. |

## Proposed architecture

```text
Fortran application
        |
        v
Public Fortran modules (derived types, methods, callback interfaces)
        |
        v
Private Fortran bind(C) interfaces (ISO_C_BINDING)
        |
        v
Small C ABI shim (opaque handles, conversions, event trampolines)
        |
        v
wxWidgets C++ API (native platform port)
```

### API and interoperability rules

- Prefer Fortran character arguments and one shared conversion helper at the
  boundary. Define UTF-8 conversion, ownership, and error behavior consistently;
  do not pass compiler-specific Fortran character descriptors to C++.
- Use `integer(c_int)`, `logical(c_bool)` where supported by the selected
  compiler/toolchain, `real(c_double)`, `type(c_ptr)`, and `type(c_funptr)` for
  interoperable values. Keep C++ `bool`, enums, and `size_t` conversions
  explicit in the shim.
- Treat wxWidgets GUI objects as GUI-thread-bound unless a specific API
  documents otherwise. Keep event-loop entry and callback dispatch semantics
  explicit in the Fortran API.
- Do not allow C++ exceptions to escape exported C functions. Return status
  values and provide a stable way to retrieve a useful error message.
- Design wrapper ownership around wxWidgets parent-child ownership. Test
  destruction of parents, children, and event handlers so Fortran handles
  cannot silently become dangling pointers.
- Keep generated files, if introduced later, clearly marked and reproducible;
  edit their source specifications, not generated output.

## Repository shape

Evolve this layout as implementation experience warrants:

```text
pixi.toml                 # development dependencies and standard tasks
pixi.lock                 # reproducible environment
fpm.toml                  # library metadata, Fortran settings, link configuration
src/
  wx.f90                  # umbrella module
  core/                   # application, base object, strings, errors
  gui/                    # events, colors, fonts, drawing
  widgets/                # windows, controls, layouts, dialogs
  c/                      # private bind(C) interfaces
  shim/                   # C++ C-ABI bridge
test/                     # focused Fortran API and behavior tests
example/                  # small runnable GUI applications
tools/                    # only necessary build, generation, and lint helpers
.github/workflows/        # platform builds, tests, and generation checks
plans/plan.md             # this roadmap
```

Keep the public modules cohesive; avoid one giant module as the implementation
grows. Provide a small umbrella module for convenient consumer imports.

## Development environment and build strategy

Use a pixi environment modeled on qt-fortran, with a pinned/locked compiler,
fpm, C++ toolchain, CMake/Ninja as needed, and documentation/test tools. Add
platform-specific dependencies only when required. Provide tasks such as
`build`, `test`, `example`, `lint`, and (if applicable) `gen`/`gen-check`.

The Phase 0 spike must compare these wxWidgets dependency paths:

1. A compatible conda-forge wxWidgets package, if it supplies the required
   headers, libraries, native-port dependencies, and compatible compiler ABI
   for each target platform.
2. Building wxWidgets from source in a pixi task using its supported CMake
   configuration.
3. System-installed wxWidgets for local development, with a documented
   `pkg-config`/CMake discovery path where available.

Do not assume that one package or compiler combination works across Linux,
macOS, and Windows. In particular, keep the Fortran compiler, C++ shim, and
wxWidgets binary ABI compatible; validate Windows separately before claiming
support. Prefer wxWidgets' supported build/configuration mechanisms over
maintaining a project-specific fork.

For fpm consumers, provide a minimal consumer project in CI to prove that the
published dependency can compile, link the shim and wxWidgets, and run a small
program outside this repository's own build. If direct fpm integration cannot
reliably discover and link wxWidgets, document and implement the smallest
reproducible helper/configuration path rather than making local builds work
only through implicit environment state.

## Delivery phases

### Phase 0 — Build and ABI spike

**Status: done.** conda-forge wxWidgets 3.3 on macOS and Linux; findings,
contracts and commands are in the README. Windows was investigated and
deferred to Phase 4.

- Set up the initial pixi environment and lockfile.
- Compile and link a minimal C++ shim against wxWidgets and call it from a
  minimal Fortran program using `iso_c_binding`.
- Verify compiler/linker ABI and runtime library selection on at least one
  Linux target and macOS; investigate Windows toolchain feasibility.
- Create and show one window, enter/exit the event loop, and verify a Fortran
  callback can be reached from a wxWidgets event.
- Prototype strings, error reporting, parent/child destruction, callback
  context lifetime, and the headless/GUI test strategy.
- Record the selected wxWidgets version/source, build configuration, supported
  target matrix, and exact clean-checkout commands in the README.

**Exit criteria:** a clean pixi environment builds and runs the spike; the
Fortran-to-shim-to-wxWidgets boundary is exercised; the ownership and callback
contracts are written down; at least one CI target can build and run it.

### Phase 1 — Core library and minimal application

**Status: done** (`example/hello.f90`, `test/test_core.f90`; CI on Linux and macOS).

- Add the `wx` umbrella module and private C interfaces.
- Implement application initialization, event-loop start/exit, top-level
  frame/window creation, basic strings, status/error reporting, and explicit
  destruction behavior.
- Establish Fortran conventions: `implicit none`, disabled implicit typing and
  external procedures, free source form, documentation on public APIs, and
  consistent naming/argument intent.
- Add the first runnable example and tests for initialization, object creation,
  method calls, cleanup, and error cases.

**Exit criteria:** the smallest documented Fortran program opens and closes a
native window, and automated checks pass on the initial supported CI target.

### Phase 2 — Common widgets, layout, and events

**Status: done** (`example/form.f90`; `test/test_events.f90`,
`test/test_lifetime.f90`, `test/test_loop.f90`). Also added: check box and
`wxEVT_CHECKBOX`, close/size/destroy events, `wx_call_after`. The form
example was checked interactively on macOS; Linux not yet checked by hand.

- Add a `wxPanel`, static text, button, single-line text control, and common
  sizer/layout support.
- Add a small set of typed events (at minimum a button command event) and
  callback registration/unregistration with context data.
- Specify when callbacks run, how exceptions/errors are reported, how callback
  state is released, and what happens if a parent or handler is destroyed.
- Add a form example that exercises layout and more than one control.

**Exit criteria:** the form works interactively; tests cover event delivery,
callback unbinding, parent destruction, and repeated creation/destruction.

### Phase 3 — Useful application features

- Prioritize menus/actions, standard dialogs, status bars, common controls,
  sizers, and basic drawing based on example applications and user demand.
- Add APIs in small, documented groups with examples and focused tests.
- Keep platform-specific functionality isolated and feature-documented.

**Exit criteria:** each feature group has a working example or test, documented
platform requirements, and no regression in existing examples.

### Phase 4 — Cross-platform hardening and consumer workflow

- Expand CI to Linux/GTK, macOS/Cocoa, and Windows/MSW as each toolchain path is
  validated.
- Test both library builds and a separate downstream fpm consumer.
- Add headless tests where the native port supports them; mark display-dependent
  integration tests clearly and use an appropriate virtual display or skip
  policy rather than treating a skipped GUI test as a pass.
- Document system dependencies, build/run commands, supported compiler and
  wxWidgets combinations, examples, and known limitations.

**Exit criteria:** every advertised platform builds and links from a clean
environment, runs relevant tests, and passes the downstream consumer check.

### Phase 5 — Binding generation (only if justified)

- After several hand-written API groups establish stable patterns, define a
  compact source specification for supported classes, methods, enums, and
  argument conversions.
- Generate only repetitive layers (for example raw `bind(C)` declarations and
  simple shim forwarding functions); retain hand-written implementations for
  ownership, callbacks, conversions, and other complex behavior.
- Add deterministic generation and a CI check that fails when generated output
  is stale.
- Never make generation a prerequisite for understanding or debugging the
  public API.

**Exit criteria:** generated output is reproducible and equivalent to the
hand-written API behavior, and generation reduces rather than adds maintenance.

## Testing and quality gates

- **Fortran unit tests:** public methods, argument conversion, status/errors,
  enum/constants, and null/invalid handle behavior where supported.
- **Shim tests:** ownership and conversion helpers; exception-to-error
  translation; callback registration, dispatch, and unregistration.
- **GUI integration tests:** initialize the app, create controls, dispatch
  representative events, and clean up. Separate tests that require an actual
  display from tests runnable headlessly.
- **Examples:** compile all examples in CI; run at least one small smoke test
  where the platform supports it.
- **Consumer test:** a separate fpm project depends on this library and links
  and runs against wxWidgets.
- **Static checks:** Fortran lint/documentation checks and generation drift
  checks if generators exist.
- **CI matrix:** begin with the simplest validated environment, then add each
  OS/native wxWidgets port and architecture as a complete toolchain becomes
  reproducible. Report unsupported combinations explicitly.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| wxWidgets packaging/build dependencies differ by OS and native port | Resolve in Phase 0; pin a known working dependency path and test clean installs. Keep alternate system builds documented. |
| C++ and Fortran toolchains use incompatible C++ runtimes or ABIs | Validate the complete compile/link/run chain per platform. Never mix incompatible Windows toolchains or ship an untested combination. |
| wxWidgets parent ownership conflicts with Fortran wrapper lifetime | Establish handle invalidation and ownership rules before public wrappers; test parent destruction and avoid automatic destruction in indiscriminate finalizers. |
| Callback pointers or user context outlive their Fortran procedure/state | Define a registration contract, ensure unregistration/cleanup on destruction, and test teardown and repeated event dispatch. |
| GUI tests need a display or native event loop | Separate unit and integration suites; use supported headless/virtual-display setups and make skips visible. |
| Wrapping too much creates an unmaintainable surface | Start with common workflows, prioritize documented APIs, and defer generation until repeated patterns are proven. |
| Text encoding and native string conversions differ | Centralize conversion, use explicit UTF-8 semantics, and test non-ASCII text across platforms. |
| wxWidgets licensing obligations are misunderstood | Review the upstream wxWindows licence and distribution obligations before release; do not assume all dependency licenses are interchangeable. |

## Reference material

- [qt-fortran](https://github.com/jacobwilliams/qt-fortran) — reference for
  modern Fortran API design, `iso_c_binding`, thin C++ shim, pixi/fpm
  development, examples, tests, CI, and staged binding generation.
- [wxWidgets repository](https://github.com/wxWidgets/wxWidgets) — upstream
  source, platform support, CMake configuration, native ports, samples, and
  tests.
- [wxWidgets GTK build instructions](https://github.com/wxWidgets/wxWidgets/blob/master/docs/gtk/install.md),
  [MSW build instructions](https://github.com/wxWidgets/wxWidgets/blob/master/docs/msw/install.md),
  and [macOS build instructions](https://github.com/wxWidgets/wxWidgets/blob/master/docs/osx/install.md)
  — platform-specific build requirements.
- [wxWidgets licence](https://github.com/wxWidgets/wxWidgets/blob/master/docs/licence.txt)
  — review before redistributing binaries or publishing the binding.


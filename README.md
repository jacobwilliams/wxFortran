# wxFortran

Modern Fortran bindings for [wxWidgets](https://github.com/wxWidgets/wxWidgets):
native desktop GUIs from Fortran through an idiomatic API of derived types and
type-bound procedures.

```fortran
program hello
    use wx
    implicit none
    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_button) :: button

    app = wx_app()
    frame = wx_frame("wxFortran", width=320, height=160)
    button = wx_button(frame, "Click me")
    call button%bind(wxEVT_BUTTON, on_click)
    call frame%show()
    stop app%run()
contains
    subroutine on_click(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        print *, 'clicked'
    end subroutine on_click
end program hello
```

**Status:** early development (see [plans/plan.md](plans/plan.md)). Phases 0–2
are in place: application and event loop, frames, panels, static text,
buttons, text controls, check boxes, box sizers, and typed events with a
tested lifetime contract. Phase 3 adds timers, menus, status bars, 2D
drawing (a canvas with mouse/key input and anti-aliased graphics, saved to
PNG), the standard dialogs, list and value controls (choice, list box,
radio box, slider, spin controls, gauge), and containers and layout
(notebook, splitter, grid sizers, group boxes, toolbar, image view). The API
may still change.

## Building

The development environment is managed with [pixi](https://pixi.sh). From a
clean checkout:

```sh
pixi install            # gfortran 15, fpm, C++ compiler, wxWidgets 3.3 (conda-forge)
pixi run build          # library and examples
pixi run test           # tests (Linux without a display: run under xvfb-run)
pixi run example hello  # or: form, showcase (widgets, events, dialogs), layout, plot
pixi run lint           # docstrings and implicit none in interface bodies
pixi run consumer       # build/run ci/consumer, a separate project using wxFortran
```

The C++ shim in `src/shim` is compiled by fpm as part of the library.
[tools/fpm_wx.py](tools/fpm_wx.py) runs fpm with the settings it needs, taken
from `wx-config`: `FPM_CXX`, `FPM_CXXFLAGS` (`wx-config --cxxflags`) and
`FPM_LDFLAGS` (`wx-config --libs core,base`, plus an rpath). To use plain
`fpm` in a shell, run `eval "$(python tools/fpm_wx.py --env)"` first.

To build against a system or custom wxWidgets (3.2 or later), set `WX_CONFIG`
to its `wx-config`, and make sure the Fortran and C++ compilers produce
compatible binaries for that wxWidgets build.

### Using wxFortran from another fpm project

```toml
[dependencies]
wxfortran = { git = "https://github.com/jacobwilliams/wxFortran" }
```

Then build with the helper from the dependency checkout, from your project's
root: `python build/dependencies/wxfortran/tools/fpm_wx.py build`. See
[ci/consumer](ci/consumer) for a complete example, which CI builds and runs.

## Platform support

| Platform | wxWidgets port | Status |
|---|---|---|
| macOS (arm64) | Cocoa | Supported: build, tests and consumer check pass in CI and locally (conda-forge wxWidgets 3.3.4, gfortran 15, clang++). |
| Linux (x86-64) | GTK 3 | Supported: build, tests (under Xvfb) and consumer check pass in CI. |
| Windows | MSW | Not supported yet (see below). |

### Phase 0 findings

* **wxWidgets source:** conda-forge `wxwidgets` 3.3.4, pinned to `3.3.*` in
  `pixi.toml`. It provides `wx-config`, headers and shared libraries for
  osx-arm64, osx-64, linux-64 (GTK 3) and linux-aarch64, using the same C++
  runtime as the conda-forge compilers (libc++ on macOS, libstdc++ 15 on Linux).
  Building wxWidgets from source is not needed for these platforms.
* **Windows:** conda-forge's wxWidgets is built with MSVC and has no
  `wx-config`. gfortran (MinGW) cannot link MSVC C++ objects, so the shim would
  have to be built separately as a DLL with a plain C interface (as qt-fortran
  does for Qt), or wxWidgets built with MinGW (e.g. MSYS2). Not done yet.
* **No `wxIMPLEMENT_APP`:** the shim creates its own `wxApp` subclass and uses
  `wxEntryStart` / `wxApp::OnRun` / `wxEntryCleanup`, so the Fortran program
  keeps its own `program` entry point.
* **Tests:** GUI tests create real native windows but generate events
  programmatically, either synchronously (`button%emit_click()`,
  `text%set_value(...)`) or queued for the event loop like real input
  (`button%post_click()`), and drive the main loop with `wx_call_after`, so
  they need no user interaction. They
  run on a macOS desktop session; on Linux they need an X display (Xvfb in CI).

## Design

```text
Fortran application
    -> public Fortran modules (src/wx.f90, src/core, src/widgets)
    -> private bind(C) interfaces (src/c)
    -> C ABI shim (src/shim, C++)
    -> wxWidgets
```

### Language boundary

* Only `bind(C)` interfaces and interoperable types cross it: 64-bit integer
  handles, `c_int` values (booleans as 0/1), `c_ptr` for strings and events,
  and `c_funptr` for the two Fortran entry points (event dispatch, handler
  release). No C++ class, reference or exception reaches Fortran.
* Every exported shim function catches all C++ exceptions and returns a status
  code; the message is kept for `wx_last_error()`.
* Strings are UTF-8 in both directions, passed as (characters, length) with
  no NUL terminator. Strings returned by the shim are copied into
  `character(len=:), allocatable` results and freed.

### Errors

Procedures that can fail take an optional `integer, intent(out) :: stat`. If
present it receives `WX_OK` or a `WX_ERR_*` code (`WX_ERR_INVALID_HANDLE`,
`WX_ERR_NO_APP`, `WX_ERR_STATE`, `WX_ERR_ARGUMENT`, `WX_ERR_FAILED`,
`WX_ERR_EXCEPTION`) and `wx_last_error()` gives the message. If absent, a
failure prints the message and stops the program (`error stop`).

### Ownership and lifetime

* Wrappers (`type(wx_frame)`, `type(wx_button)`, ...) hold only a handle.
  Copying one makes another reference to the same object. Wrappers have no
  finalizers: a Fortran variable going out of scope never destroys anything.
* wxWidgets owns the objects. A child window is destroyed with its parent. A
  frame is destroyed by `destroy`, by a `close` that is not vetoed, or by the
  user closing it. Destruction of top-level windows completes when pending
  events are processed, but their handles (and their children's) are invalid
  immediately.
* Handles are never reused. The shim tracks every window it creates and drops
  it when wxWidgets deletes it, whoever deleted it. Using a handle to a
  destroyed object (or an object of the wrong type for the call) fails with
  `WX_ERR_INVALID_HANDLE`. It never touches freed memory. `obj%is_valid()`
  tests a handle.
* Sizers: a new sizer is unattached. `window%set_sizer(s)` or
  `parent_sizer%add(s)` transfer it to its new owner. Replacing a window's
  sizer destroys the old one. An unattached sizer must be destroyed with
  `sizer%destroy()`. A sizer handle is valid while its owner chain is alive.
* Timers: `wx_timer(owner=window)` is destroyed with its owner window. A
  timer without an owner lives until `timer%destroy()`.
* Menus: a new menu or menu bar is unattached. `bar%append(menu)` and
  `menu%append_submenu(sub)` transfer the menu, and `frame%set_menu_bar(bar)`
  transfers the bar to the frame, which destroys any previous menu bar (and its
  menus). Destroying an attached menu or menu bar fails with `WX_ERR_STATE`.
  Unattached ones must be destroyed with `destroy`.
* `app%cleanup()` destroys every remaining window, timer, menu and menu bar;
  all handles become invalid.

### Events and callbacks

* `call obj%bind(kind, handler, data=..., id=..., connection=...)` binds a
  handler with the `wx_event_handler` interface to one `wxEVT_*` event kind
  on one window, timer or menu (all extend `wx_evt_handler`). With `id`, the
  handler runs only for events from that window or menu item id. Example:
  `frame%bind(wxEVT_MENU, on_open, id=id_open)`. Available kinds:
  `wxEVT_BUTTON`, `wxEVT_TEXT`, `wxEVT_TEXT_ENTER`, `wxEVT_CHECKBOX`,
  `wxEVT_CLOSE_WINDOW`, `wxEVT_SIZE`, `wxEVT_DESTROY`, `wxEVT_TIMER`,
  `wxEVT_MENU`, `wxEVT_PAINT` (canvases only), the mouse events
  `wxEVT_LEFT_DOWN`, `wxEVT_LEFT_UP`, `wxEVT_LEFT_DCLICK`, `wxEVT_RIGHT_DOWN`,
  `wxEVT_MOTION`, `wxEVT_MOUSEWHEEL` and `wxEVT_LEAVE_WINDOW`, and
  `wxEVT_KEY_DOWN`.
* Menu events go to the menu, then to its frame. Items are identified by
  integer ids: stock ids (`wxID_EXIT`, `wxID_ABOUT`, ...), which get standard
  labels and, on macOS, their place in the application menu, or ids returned
  by `menu%append`.
* Timer events are delivered only while the event loop runs.
* Handlers run synchronously on the GUI thread, during event processing:
  normally inside `app%run()` (or `app%process_pending()`), or inside the call
  that generated the event (e.g. `text%set_value`, `button%emit_click`).
  While the loop runs, `app%run()` and `app%cleanup()` fail with
  `WX_ERR_STATE`.
* `data` is kept **by pointer**: pass a `target` (or pointer) that outlives
  the binding. It is passed back as the handler's `data` argument.
* The `wx_event` passed to a handler is valid only during that call. Using a
  copy afterwards fails with `WX_ERR_STATE`.
* As in wxWidgets, a handled event stops there unless the handler calls
  `event%skip()`. Command events (button, text, check box) then propagate to
  the parent windows. A `wxEVT_CLOSE_WINDOW` handler must call `event%skip()`
  (or destroy the window) to let the window close, or `event%veto()` to keep
  it open.
* A binding ends when `connection%disconnect()` is called (a handler may
  disconnect itself), or when its window is destroyed. After that, its handler
  is never called and wxFortran drops its pointer to `data`. Tests check that
  destroying windows releases every binding.
* A handler may destroy any window, including the one whose event it is
  handling or one of its parents. The window's handle (and its children's)
  is invalid at once. A child window destroyed from a handler is hidden at
  once and deleted from the event loop (wxWidgets may still be using it when
  the handler returns), so a parent's `child_count` drops only after that.
  Events still queued for a destroyed window are dropped. `wxEVT_DESTROY`
  handlers run while the window is being deleted: its handle is already
  invalid, but `event%source()` still identifies it.
* `wx_call_after(callback, data)` runs a `wx_callback` once from the event
  loop.
* All GUI calls must be made on the main thread.
* A failed wxWidgets assertion (a usage error inside wxWidgets) is printed on
  stderr and recorded as the last error. It does not open a dialog.

### Controls

* `wx_choice`, `wx_list_box` (optionally multiple selection) and
  `wx_radio_box` take their items as a character array, with trailing blanks
  ignored: `wx_choice(panel, [character(len=8) :: 'red', 'green'])`. Items
  are numbered from 1, and a selection of 0 means none. Their events
  (`wxEVT_CHOICE`, `wxEVT_LISTBOX`, `wxEVT_LISTBOX_DCLICK`,
  `wxEVT_RADIOBOX`) carry the item in `event%get_selection()` and its text in
  `event%get_string()`.
* `wx_slider`, `wx_spin_ctrl` (integer), `wx_spin_ctrl_double` (real) and
  `wx_gauge` (progress bar). Their events are `wxEVT_SLIDER`,
  `wxEVT_SPINCTRL` and `wxEVT_SPINCTRLDOUBLE`. Read the new value with
  `event%get_int()`, or `get_double()` for the real spin control.
* Setting a value from code (`set_value`, `set_selection`) sends no event.
  `emit_select` and `emit_change` do, for tests.

### Containers and layout

* `wx_notebook` shows tabbed pages, and `wx_splitter_window` shows two panes
  with a draggable sash. Pages and panes are windows created with the
  notebook or splitter as their parent. Add them with `book%add_page(page,
  'Title')` or `split%split_vertically(left, right)`. Notebook events are
  `wxEVT_NOTEBOOK_PAGE_CHANGING`, which can be vetoed, and
  `wxEVT_NOTEBOOK_PAGE_CHANGED`. `event%get_selection()` is the new page.
* `wx_grid_sizer(cols)` lays items out in equal cells.
  `wx_flex_grid_sizer(cols)` sizes its rows and columns to their contents;
  call `add_growable_col` and `add_growable_row` to stretch some of them.
  `wx_static_box_sizer(orient, parent, label)` draws a labeled box around
  its items; create the items with `sizer%get_static_box()` as their parent.
* `wx_tool_bar(frame)` adds a toolbar. `add_tool(label, art='wxART_FILE_OPEN'
  | file='icon.png', kind=, id=)` returns the tool's id. Tool clicks are
  `wxEVT_TOOL` events, which are the same as `wxEVT_MENU`, so bind them on
  the frame with `id=`. A tool with a stock id, such as `wxID_OPEN`, shares
  the handler of the menu item with that id.
* `wx_static_bitmap` shows an image at its natural size, from a file or from
  a Fortran array `rgb(3, width, height)`. On a canvas,
  `g%draw_rgb(rgb, x, y, w, h, smooth=)` draws such an array scaled, for
  heatmaps or computed images, and `g%draw_image_file` draws an image file.

### Dialogs

* `wx_message_box` (returns `wxID_OK`, `wxID_CANCEL`, `wxID_YES` or
  `wxID_NO`), `wx_file_open_dialog`, `wx_file_open_multiple_dialog`,
  `wx_file_save_dialog`, `wx_dir_dialog`, `wx_text_entry_dialog`,
  `wx_choice_dialog`, `wx_color_dialog` and `wx_about_box`. Each dialog
  except the message box and the About box returns `.true.` if the user
  accepted.
* They are modal: they run their own event loop until answered, so timers
  and other windows keep working meanwhile.
* Testing: `wx_queue_dialog_answer(button=, text=, path=, paths=, index=,
  color=)` scripts the next dialog's answer, and that dialog then returns at
  once without appearing. `wx_set_dialog_test_mode(.true.)` makes a dialog
  without a queued answer fail with `WX_ERR_STATE` instead of waiting for a
  user. `wx_last_dialog(kind, caption, message)` reports what the last dialog
  showed.

### Drawing

* A `wx_canvas` is a window drawn by its `wxEVT_PAINT` handlers. In the
  handler, `g = wx_graphics(event)` gives the drawing context.
  `g%width` and `g%height` are the area's size. The context is
  anti-aliased and uses `real(c_double)` pixel coordinates from the top-left,
  with y pointing down. It provides pens (width, dash style), brushes, fonts,
  lines and polylines from Fortran arrays, polygons, rectangles, circles,
  rotated text with measurement, clipping, transforms, and push/pop of the
  state. Call `canvas%refresh()` after changing what it shows.
* The context is borrowed: using it after its handler returns fails with
  `WX_ERR_STATE`.
* The same paint handler draws on screen, into `canvas%save_png(file)`, and
  offscreen with `wx_render_png(file, width, height, handler, data)`, which
  needs no window. `wx_image_read_rgb(file, rgb)` reads an image back, e.g.
  to test pixels.
* Colors are `type(wx_color)` (8-bit RGBA): `wx_color(r, g, b)`,
  `wx_color_hex('#1f77b4')`, or named ones (`wxBLACK`, `wxWHITE`, ...).
* Mouse and key events: `event%get_position`, `get_wheel_rotation`,
  `left_is_down`, `get_key_code` (`WXK_*`, or the upper-case ASCII code),
  `get_unicode_key`, and `get_modifiers` (`WX_MOD_SHIFT`, `WX_MOD_CONTROL`,
  which is Cmd on macOS, and `WX_MOD_ALT`). `window%emit_mouse` and
  `window%emit_key` generate them for tests. Clicking a canvas gives it the
  keyboard focus.
* [example/plot.f90](example/plot.f90) is a live scrolling plot built this
  way: axes with tick choice, a grid, a legend, markers, zoom and pan, pause,
  and PNG export. `plot --screenshot out.png` saves an image and exits.

## Repository layout

```text
src/wx.f90        umbrella module (`use wx`)
src/core/         wx_base (errors, handles, strings), wx_events, wx_app, wx_timer
src/gui/          wx_colors, wx_graphics (drawing context, PNG rendering and reading)
src/widgets/      wx_windows (window base, sizers), wx_menus, wx_controls (frames, basic controls),
                  wx_lists, wx_values (more controls), wx_layout (containers, sizers,
                  toolbar, image view), wx_dialogs, wx_canvas
src/c/            private bind(C) interfaces to the shim
src/shim/         C++ C-ABI shim over wxWidgets
test/             tests (fpm test): core, events, lifetime, loop, timer, menus, canvas, dialogs,
                  controls, layout
example/          hello, form (menus, status bar, timer), showcase (widgets, events, dialogs),
                  layout (toolbar, notebook, splitter, sizers, images), plot (drawing)
ci/consumer/      downstream fpm project used as a CI check
tools/            fpm_wx.py (build helper), check_fortran.py (lint)
plans/plan.md     roadmap
```

## License

wxFortran is MIT licensed (see [LICENSE](LICENSE)). wxWidgets is distributed
under the [wxWindows Library Licence](https://github.com/wxWidgets/wxWidgets/blob/master/docs/licence.txt).
Review its terms before redistributing binaries that include wxWidgets.

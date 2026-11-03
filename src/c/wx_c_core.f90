!> Private `bind(C)` interfaces to the core of the C++ shim
!> (src/shim/wxf_core.cpp), and the constants shared with it.
!>
!> Handles are `integer(c_int64_t)` (0 is "no object"). Unless noted, every
!> function returns a status: `WX_OK` (0) or one of the `WX_ERR_*` codes.
!> Strings are passed as (characters, byte length) of UTF-8; strings returned
!> by the shim are malloc'd and must be released with [[wxf_free]].
module wx_c_core

    use iso_c_binding
    implicit none
    private

    ! status codes: must match `enum wxf_status` in src/shim/wxf_common.h
    integer(c_int), parameter, public :: WX_OK = 0                   !! success
    integer(c_int), parameter, public :: WX_ERR_INVALID_HANDLE = 1   !! null, unknown or destroyed object
    integer(c_int), parameter, public :: WX_ERR_NO_APP = 2           !! the application is not initialized
    integer(c_int), parameter, public :: WX_ERR_STATE = 3            !! call not allowed in the current state
    integer(c_int), parameter, public :: WX_ERR_ARGUMENT = 4         !! invalid argument value
    integer(c_int), parameter, public :: WX_ERR_FAILED = 5           !! wxWidgets reported failure
    integer(c_int), parameter, public :: WX_ERR_EXCEPTION = 6        !! C++ exception caught in the shim

    ! event kinds: must match `enum wxf_event_kind` in src/shim/wxf_common.h
    integer(c_int), parameter, public :: wxEVT_BUTTON = 1        !! a button was clicked
    integer(c_int), parameter, public :: wxEVT_TEXT = 2          !! the text of a text control changed
    integer(c_int), parameter, public :: wxEVT_TEXT_ENTER = 3    !! Enter pressed in a text control (`wxTE_PROCESS_ENTER`)
    integer(c_int), parameter, public :: wxEVT_CLOSE_WINDOW = 4  !! a window is asked to close
    integer(c_int), parameter, public :: wxEVT_SIZE = 5          !! a window was resized
    integer(c_int), parameter, public :: wxEVT_DESTROY = 6       !! a window is being destroyed
    integer(c_int), parameter, public :: wxEVT_CHECKBOX = 7      !! a check box was toggled
    integer(c_int), parameter, public :: wxEVT_TIMER = 8         !! a timer fired
    integer(c_int), parameter, public :: wxEVT_MENU = 9          !! a menu item was selected

    integer(c_int), parameter, public :: wxEVT_PAINT = 10        !! a wx_canvas needs drawing
    integer(c_int), parameter, public :: wxEVT_LEFT_DOWN = 11    !! left mouse button pressed
    integer(c_int), parameter, public :: wxEVT_LEFT_UP = 12      !! left mouse button released
    integer(c_int), parameter, public :: wxEVT_RIGHT_DOWN = 13   !! right mouse button pressed
    integer(c_int), parameter, public :: wxEVT_MOTION = 14       !! mouse moved
    integer(c_int), parameter, public :: wxEVT_MOUSEWHEEL = 15   !! mouse wheel turned
    integer(c_int), parameter, public :: wxEVT_KEY_DOWN = 16     !! key pressed (in the focused window)
    integer(c_int), parameter, public :: wxEVT_LEFT_DCLICK = 17  !! left button double-clicked
    integer(c_int), parameter, public :: wxEVT_LEAVE_WINDOW = 18 !! mouse left the window
    integer(c_int), parameter, public :: wxEVT_CHOICE = 19       !! an item of a wx_choice was chosen
    integer(c_int), parameter, public :: wxEVT_LISTBOX = 20      !! an item of a wx_list_box was selected
    integer(c_int), parameter, public :: wxEVT_LISTBOX_DCLICK = 21 !! an item of a wx_list_box was double-clicked
    integer(c_int), parameter, public :: wxEVT_SLIDER = 22       !! a wx_slider moved
    integer(c_int), parameter, public :: wxEVT_SPINCTRL = 23     !! a wx_spin_ctrl value changed
    integer(c_int), parameter, public :: wxEVT_RADIOBOX = 24     !! a wx_radio_box selection changed
    integer(c_int), parameter, public :: wxEVT_SPINCTRLDOUBLE = 25 !! a wx_spin_ctrl_double value changed
    integer(c_int), parameter, public :: wxEVT_NOTEBOOK_PAGE_CHANGED = 26  !! a notebook page was selected
    integer(c_int), parameter, public :: wxEVT_NOTEBOOK_PAGE_CHANGING = 27 !! a notebook page is about to change (can be vetoed)
    integer(c_int), parameter, public :: wxEVT_TOOL = 9          !! a toolbar tool was clicked (the same event as wxEVT_MENU)
    integer(c_int), parameter, public :: wxEVT_RIGHT_UP = 28     !! right mouse button released
    integer(c_int), parameter, public :: wxEVT_MOUSE_CAPTURE_LOST = 29 !! the mouse capture was taken away

    ! cursors: must match wxf_window_set_cursor in src/shim/wxf_core.cpp
    integer(c_int), parameter, public :: WX_CURSOR_ARROW = 0      !! the normal arrow
    integer(c_int), parameter, public :: WX_CURSOR_CROSS = 1      !! a crosshair
    integer(c_int), parameter, public :: WX_CURSOR_HAND = 2       !! a pointing hand
    integer(c_int), parameter, public :: WX_CURSOR_WAIT = 3       !! busy
    integer(c_int), parameter, public :: WX_CURSOR_SIZING = 4     !! move/resize arrows
    integer(c_int), parameter, public :: WX_CURSOR_IBEAM = 5      !! text insertion
    integer(c_int), parameter, public :: WX_CURSOR_MAGNIFIER = 6  !! a magnifying glass

    integer(c_int), parameter, public :: wxID_ANY = -1           !! any id (wxWidgets' own value)

    ! modifier key bits: must match WXF_MOD_* in src/shim/wxf_common.h
    integer(c_int), parameter, public :: WX_MOD_SHIFT = 1    !! Shift held
    integer(c_int), parameter, public :: WX_MOD_CONTROL = 2  !! Control held (Cmd on macOS)
    integer(c_int), parameter, public :: WX_MOD_ALT = 4      !! Alt (Option) held

    ! key codes (wxWidgets' own values); letters and digits are their upper-case ASCII codes
    integer(c_int), parameter, public :: WXK_BACK = 8        !! Backspace
    integer(c_int), parameter, public :: WXK_TAB = 9         !! Tab
    integer(c_int), parameter, public :: WXK_RETURN = 13     !! Return / Enter
    integer(c_int), parameter, public :: WXK_ESCAPE = 27     !! Escape
    integer(c_int), parameter, public :: WXK_SPACE = 32      !! space bar
    integer(c_int), parameter, public :: WXK_DELETE = 127    !! Delete
    integer(c_int), parameter, public :: WXK_END = 312       !! End
    integer(c_int), parameter, public :: WXK_HOME = 313      !! Home
    integer(c_int), parameter, public :: WXK_LEFT = 314      !! left arrow
    integer(c_int), parameter, public :: WXK_UP = 315        !! up arrow
    integer(c_int), parameter, public :: WXK_RIGHT = 316     !! right arrow
    integer(c_int), parameter, public :: WXK_DOWN = 317      !! down arrow
    integer(c_int), parameter, public :: WXK_F1 = 340        !! F1 (F2... follow)
    integer(c_int), parameter, public :: WXK_PAGEUP = 366    !! Page Up
    integer(c_int), parameter, public :: WXK_PAGEDOWN = 367  !! Page Down

    public :: wxf_set_error
    public :: wxf_window_capture_mouse, wxf_window_release_mouse, wxf_window_has_capture
    public :: wxf_window_set_cursor, wxf_begin_busy_cursor, wxf_end_busy_cursor
    public :: wxf_window_get_content_scale_factor
    public :: wxf_event_get_selection, wxf_event_get_double
    public :: wxf_last_error, wxf_clear_error, wxf_free, wxf_is_valid, wxf_live_count
    public :: wxf_app_init, wxf_app_run, wxf_app_exit_main_loop, wxf_app_is_main_loop_running
    public :: wxf_app_process_pending, wxf_app_set_exit_on_frame_delete, wxf_app_cleanup
    public :: wxf_set_dispatcher, wxf_bind, wxf_unbind, wxf_call_after
    public :: wxf_event_skip, wxf_event_get_skipped, wxf_event_get_source, wxf_event_get_id
    public :: wxf_event_get_int, wxf_event_get_string, wxf_event_can_veto, wxf_event_veto
    public :: wxf_event_get_size
    public :: wxf_window_destroy, wxf_window_close, wxf_window_show, wxf_window_is_shown
    public :: wxf_window_enable, wxf_window_is_enabled, wxf_window_set_label, wxf_window_get_label
    public :: wxf_window_set_size, wxf_window_get_size, wxf_window_set_min_size
    public :: wxf_window_set_position, wxf_window_get_position, wxf_window_get_parent
    public :: wxf_window_get_id, wxf_window_set_focus, wxf_window_layout, wxf_window_fit
    public :: wxf_window_center, wxf_window_set_tooltip, wxf_window_child_count
    public :: wxf_window_set_sizer
    public :: wxf_event_get_position, wxf_event_get_wheel, wxf_event_left_is_down
    public :: wxf_event_get_key, wxf_event_get_modifiers, wxf_event_get_graphics
    public :: wxf_window_refresh, wxf_window_set_background_color, wxf_window_get_client_size
    public :: wxf_window_emit_mouse, wxf_window_emit_key

    interface

        !> The message of the last failed call on this thread (borrowed).
        function wxf_last_error(len) bind(C, name='wxf_last_error') result(p)
            import :: c_int, c_ptr
            implicit none
            integer(c_int), intent(out) :: len
            type(c_ptr) :: p
        end function wxf_last_error

        !> Record an error message; returns `status`.
        function wxf_set_error(status, msg, len_msg) &
                bind(C, name='wxf_set_error') result(r)
            import :: c_char, c_int
            implicit none
            integer(c_int), value :: status
            character(kind=c_char), intent(in) :: msg(*)
            integer(c_int), value :: len_msg
            integer(c_int) :: r
        end function wxf_set_error

        !> Clear the last error message.
        subroutine wxf_clear_error() bind(C, name='wxf_clear_error')
            implicit none
        end subroutine wxf_clear_error

        !> Release a buffer returned by the shim.
        subroutine wxf_free(p) bind(C, name='wxf_free')
            import :: c_ptr
            implicit none
            type(c_ptr), value :: p
        end subroutine wxf_free

        !> 1 if `h` is a live object, else 0 (never fails).
        function wxf_is_valid(h) bind(C, name='wxf_is_valid') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_is_valid

        !> Number of live objects created through the shim.
        function wxf_live_count() bind(C, name='wxf_live_count') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_live_count

        !> Initialize wxWidgets and the application.
        function wxf_app_init(name, len) bind(C, name='wxf_app_init') result(r)
            import :: c_int, c_char
            implicit none
            character(kind=c_char), intent(in) :: name(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function wxf_app_init

        !> Run the main event loop until it exits.
        function wxf_app_run(code) bind(C, name='wxf_app_run') result(r)
            import :: c_int
            implicit none
            integer(c_int), intent(out) :: code
            integer(c_int) :: r
        end function wxf_app_run

        !> Make the main loop exit.
        function wxf_app_exit_main_loop() bind(C, name='wxf_app_exit_main_loop') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_app_exit_main_loop

        !> 1 while the main loop runs, else 0.
        function wxf_app_is_main_loop_running() bind(C, name='wxf_app_is_main_loop_running') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_app_is_main_loop_running

        !> Process pending events and delayed window deletions.
        function wxf_app_process_pending() bind(C, name='wxf_app_process_pending') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_app_process_pending

        !> Whether the main loop exits when the last top-level window is deleted.
        function wxf_app_set_exit_on_frame_delete(flag) bind(C, name='wxf_app_set_exit_on_frame_delete') result(r)
            import :: c_int
            implicit none
            integer(c_int), value :: flag
            integer(c_int) :: r
        end function wxf_app_set_exit_on_frame_delete

        !> Shut wxWidgets down.
        function wxf_app_cleanup() bind(C, name='wxf_app_cleanup') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_app_cleanup

        !> Set the Fortran dispatch and slot-release procedures.
        subroutine wxf_set_dispatcher(dispatch, release) bind(C, name='wxf_set_dispatcher')
            import :: c_funptr
            implicit none
            type(c_funptr), value :: dispatch, release
        end subroutine wxf_set_dispatcher

        !> Bind slot `slot` to events of `kind` on handler `h`, from `id` only
        !> (`wxID_ANY`: from any id).
        function wxf_bind(h, kind, slot, id) bind(C, name='wxf_bind') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: kind, slot, id
            integer(c_int) :: r
        end function wxf_bind

        !> Unbind the handler owning `slot`; `found` is 1 if it was bound.
        function wxf_unbind(slot, found) bind(C, name='wxf_unbind') result(r)
            import :: c_int
            implicit none
            integer(c_int), value :: slot
            integer(c_int), intent(out) :: found
            integer(c_int) :: r
        end function wxf_unbind

        !> Call slot `slot` once from the event loop.
        function wxf_call_after(slot) bind(C, name='wxf_call_after') result(r)
            import :: c_int
            implicit none
            integer(c_int), value :: slot
            integer(c_int) :: r
        end function wxf_call_after

        !> Set whether the event continues to other handlers.
        function wxf_event_skip(e, skip) bind(C, name='wxf_event_skip') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), value :: skip
            integer(c_int) :: r
        end function wxf_event_skip

        !> Whether the event was skipped.
        function wxf_event_get_skipped(e, skipped) bind(C, name='wxf_event_get_skipped') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: skipped
            integer(c_int) :: r
        end function wxf_event_get_skipped

        !> Handle of the window that generated the event.
        function wxf_event_get_source(e, h) bind(C, name='wxf_event_get_source') result(r)
            import :: c_int, c_ptr, c_int64_t
            implicit none
            type(c_ptr), value :: e
            integer(c_int64_t), intent(out) :: h
            integer(c_int) :: r
        end function wxf_event_get_source

        !> wxWidgets id of the window that generated the event.
        function wxf_event_get_id(e, id) bind(C, name='wxf_event_get_id') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: id
            integer(c_int) :: r
        end function wxf_event_get_id

        !> Integer value of a command event.
        function wxf_event_get_int(e, value) bind(C, name='wxf_event_get_int') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: value
            integer(c_int) :: r
        end function wxf_event_get_int

        !> String value of a command event (malloc'd).
        function wxf_event_get_string(e, s, len) bind(C, name='wxf_event_get_string') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_event_get_string

        !> Whether a close event can be vetoed.
        function wxf_event_can_veto(e, can) bind(C, name='wxf_event_can_veto') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: can
            integer(c_int) :: r
        end function wxf_event_can_veto

        !> Veto a close event.
        function wxf_event_veto(e) bind(C, name='wxf_event_veto') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int) :: r
        end function wxf_event_veto

        !> New size from a size event.
        function wxf_event_get_size(e, width, height) bind(C, name='wxf_event_get_size') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: width, height
            integer(c_int) :: r
        end function wxf_event_get_size

        !> Destroy a window and its children.
        function wxf_window_destroy(h) bind(C, name='wxf_window_destroy') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_destroy

        !> Ask a window to close; `closed` is 0 if vetoed.
        function wxf_window_close(h, force, closed) bind(C, name='wxf_window_close') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: force
            integer(c_int), intent(out) :: closed
            integer(c_int) :: r
        end function wxf_window_close

        !> Show (1) or hide (0) a window.
        function wxf_window_show(h, show) bind(C, name='wxf_window_show') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: show
            integer(c_int) :: r
        end function wxf_window_show

        !> Whether a window is shown.
        function wxf_window_is_shown(h, shown) bind(C, name='wxf_window_is_shown') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: shown
            integer(c_int) :: r
        end function wxf_window_is_shown

        !> Enable (1) or disable (0) a window.
        function wxf_window_enable(h, enable) bind(C, name='wxf_window_enable') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: enable
            integer(c_int) :: r
        end function wxf_window_enable

        !> Whether a window is enabled.
        function wxf_window_is_enabled(h, enabled) bind(C, name='wxf_window_is_enabled') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: enabled
            integer(c_int) :: r
        end function wxf_window_is_enabled

        !> Set a window's label.
        function wxf_window_set_label(h, s, len) bind(C, name='wxf_window_set_label') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function wxf_window_set_label

        !> A window's label (malloc'd).
        function wxf_window_get_label(h, s, len) bind(C, name='wxf_window_get_label') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_window_get_label

        !> Set a window's size in pixels.
        function wxf_window_set_size(h, width, height) bind(C, name='wxf_window_set_size') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: width, height
            integer(c_int) :: r
        end function wxf_window_set_size

        !> A window's size in pixels.
        function wxf_window_get_size(h, width, height) bind(C, name='wxf_window_get_size') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: width, height
            integer(c_int) :: r
        end function wxf_window_get_size

        !> Set a window's minimum size.
        function wxf_window_set_min_size(h, width, height) bind(C, name='wxf_window_set_min_size') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: width, height
            integer(c_int) :: r
        end function wxf_window_set_min_size

        !> Move a window.
        function wxf_window_set_position(h, x, y) bind(C, name='wxf_window_set_position') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: x, y
            integer(c_int) :: r
        end function wxf_window_set_position

        !> A window's position.
        function wxf_window_get_position(h, x, y) bind(C, name='wxf_window_get_position') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: x, y
            integer(c_int) :: r
        end function wxf_window_get_position

        !> Handle of a window's parent (0 if none).
        function wxf_window_get_parent(h, parent) bind(C, name='wxf_window_get_parent') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), intent(out) :: parent
            integer(c_int) :: r
        end function wxf_window_get_parent

        !> A window's wxWidgets id.
        function wxf_window_get_id(h, id) bind(C, name='wxf_window_get_id') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: id
            integer(c_int) :: r
        end function wxf_window_get_id

        !> Give a window the keyboard focus.
        function wxf_window_set_focus(h) bind(C, name='wxf_window_set_focus') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_set_focus

        !> Lay out a window's children with its sizer.
        function wxf_window_layout(h) bind(C, name='wxf_window_layout') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_layout

        !> Size a window to fit its children.
        function wxf_window_fit(h) bind(C, name='wxf_window_fit') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_fit

        !> Center a window on its parent or the screen.
        function wxf_window_center(h) bind(C, name='wxf_window_center') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_center

        !> Set a window's tooltip.
        function wxf_window_set_tooltip(h, s, len) bind(C, name='wxf_window_set_tooltip') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function wxf_window_set_tooltip

        !> Number of direct children of a window.
        function wxf_window_child_count(h, n) bind(C, name='wxf_window_child_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_window_child_count

        !> Set sizer `s` on window `h` (which then owns it).
        function wxf_window_set_sizer(h, s, fit) bind(C, name='wxf_window_set_sizer') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h, s
            integer(c_int), value :: fit
            integer(c_int) :: r
        end function wxf_window_set_sizer


        !> Mouse position of a mouse event.
        function wxf_event_get_position(e, x, y) &
                bind(C, name='wxf_event_get_position') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: x
            integer(c_int), intent(out) :: y
            integer(c_int) :: r
        end function wxf_event_get_position

        !> Wheel rotation of a mouse event, in notches.
        function wxf_event_get_wheel(e, steps) &
                bind(C, name='wxf_event_get_wheel') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            real(c_double), intent(out) :: steps
            integer(c_int) :: r
        end function wxf_event_get_wheel

        !> Whether the left button is down (mouse events).
        function wxf_event_left_is_down(e, down) &
                bind(C, name='wxf_event_left_is_down') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: down
            integer(c_int) :: r
        end function wxf_event_left_is_down

        !> Key code and Unicode character of a key event.
        function wxf_event_get_key(e, code, unicode) &
                bind(C, name='wxf_event_get_key') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: code
            integer(c_int), intent(out) :: unicode
            integer(c_int) :: r
        end function wxf_event_get_key

        !> Modifier keys of a mouse or key event.
        function wxf_event_get_modifiers(e, mods) &
                bind(C, name='wxf_event_get_modifiers') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: mods
            integer(c_int) :: r
        end function wxf_event_get_modifiers

        !> Graphics context and size of a paint event.
        function wxf_event_get_graphics(e, gc, width, height) &
                bind(C, name='wxf_event_get_graphics') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            type(c_ptr), intent(out) :: gc
            real(c_double), intent(out) :: width
            real(c_double), intent(out) :: height
            integer(c_int) :: r
        end function wxf_event_get_graphics

        !> Repaint a window soon.
        function wxf_window_refresh(h) &
                bind(C, name='wxf_window_refresh') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_refresh

        !> Set a window's background color.
        function wxf_window_set_background_color(h, red, green, blue, alpha) &
                bind(C, name='wxf_window_set_background_color') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            integer(c_int) :: r
        end function wxf_window_set_background_color

        !> Size of a window's client area.
        function wxf_window_get_client_size(h, width, height) &
                bind(C, name='wxf_window_get_client_size') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: width
            integer(c_int), intent(out) :: height
            integer(c_int) :: r
        end function wxf_window_get_client_size

        !> Send a synthetic mouse event.
        function wxf_window_emit_mouse(h, kind, x, y, wheel, mods) &
                bind(C, name='wxf_window_emit_mouse') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: kind
            integer(c_int), value :: x
            integer(c_int), value :: y
            real(c_double), value :: wheel
            integer(c_int), value :: mods
            integer(c_int) :: r
        end function wxf_window_emit_mouse

        !> Send a synthetic key-down event.
        function wxf_window_emit_key(h, code, unicode, mods) &
                bind(C, name='wxf_window_emit_key') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: code
            integer(c_int), value :: unicode
            integer(c_int), value :: mods
            integer(c_int) :: r
        end function wxf_window_emit_key


        !> Selected item (1-based) of a list control event.
        function wxf_event_get_selection(e, index) &
                bind(C, name='wxf_event_get_selection') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: index
            integer(c_int) :: r
        end function wxf_event_get_selection

        !> Value of a real-valued spin control event.
        function wxf_event_get_double(e, value) &
                bind(C, name='wxf_event_get_double') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: e
            real(c_double), intent(out) :: value
            integer(c_int) :: r
        end function wxf_event_get_double


        !> Capture the mouse.
        function wxf_window_capture_mouse(h) &
                bind(C, name='wxf_window_capture_mouse') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_capture_mouse

        !> Release the mouse.
        function wxf_window_release_mouse(h) &
                bind(C, name='wxf_window_release_mouse') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_window_release_mouse

        !> Whether the window has the mouse.
        function wxf_window_has_capture(h, has) &
                bind(C, name='wxf_window_has_capture') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: has
            integer(c_int) :: r
        end function wxf_window_has_capture

        !> Set the cursor over a window.
        function wxf_window_set_cursor(h, kind) &
                bind(C, name='wxf_window_set_cursor') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: kind
            integer(c_int) :: r
        end function wxf_window_set_cursor

        !> Show the busy cursor.
        function wxf_begin_busy_cursor() &
                bind(C, name='wxf_begin_busy_cursor') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_begin_busy_cursor

        !> Stop showing the busy cursor.
        function wxf_end_busy_cursor() &
                bind(C, name='wxf_end_busy_cursor') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_end_busy_cursor

        !> Physical pixels per logical pixel.
        function wxf_window_get_content_scale_factor(h, scale) &
                bind(C, name='wxf_window_get_content_scale_factor') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            real(c_double), intent(out) :: scale
            integer(c_int) :: r
        end function wxf_window_get_content_scale_factor

    end interface

end module wx_c_core

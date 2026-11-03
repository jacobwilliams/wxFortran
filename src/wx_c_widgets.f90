!> Private `bind(C)` interfaces to the widgets part of the C++ shim
!> (src/cpp/wxf_widgets.cpp), and the style/flag constants shared with it.
!>
!> The flag values are wxFortran's own (combine them with `ior` or `+`); the
!> shim translates them to the wxWidgets values.
module wx_c_widgets

    use iso_c_binding
    implicit none
    private

    ! sizer orientation
    integer(c_int), parameter, public :: wxHORIZONTAL = 0   !! lay out items left to right
    integer(c_int), parameter, public :: wxVERTICAL = 1     !! lay out items top to bottom

    ! sizer item flags: must match the enum in src/cpp/wxf_widgets.cpp
    integer(c_int), parameter, public :: wxEXPAND = 1          !! fill the space across the sizer direction
    integer(c_int), parameter, public :: wxALL = 2             !! border on all sides
    integer(c_int), parameter, public :: wxLEFT = 4            !! border on the left
    integer(c_int), parameter, public :: wxRIGHT = 8           !! border on the right
    integer(c_int), parameter, public :: wxTOP = 16            !! border on the top
    integer(c_int), parameter, public :: wxBOTTOM = 32         !! border on the bottom
    integer(c_int), parameter, public :: wxALIGN_CENTER = 64   !! center the item
    integer(c_int), parameter, public :: wxALIGN_RIGHT = 128   !! align the item to the right
    integer(c_int), parameter, public :: wxALIGN_BOTTOM = 256  !! align the item to the bottom

    ! text control styles: must match the enum in src/cpp/wxf_widgets.cpp
    integer(c_int), parameter, public :: wxTE_MULTILINE = 1       !! multi-line text
    integer(c_int), parameter, public :: wxTE_PROCESS_ENTER = 2   !! generate `wxEVT_TEXT_ENTER`
    integer(c_int), parameter, public :: wxTE_READONLY = 4        !! not editable by the user
    integer(c_int), parameter, public :: wxTE_PASSWORD = 8        !! hide the typed text

    public :: wxf_frame_create, wxf_frame_set_title, wxf_frame_get_title
    public :: wxf_panel_create, wxf_static_text_create
    public :: wxf_button_create, wxf_button_emit_click, wxf_button_post_click
    public :: wxf_text_ctrl_create, wxf_text_ctrl_set_value, wxf_text_ctrl_get_value
    public :: wxf_text_ctrl_append, wxf_text_ctrl_clear, wxf_text_ctrl_set_editable
    public :: wxf_check_box_create, wxf_check_box_set_value, wxf_check_box_get_value
    public :: wxf_check_box_emit_click
    public :: wxf_box_sizer_create, wxf_sizer_add_window, wxf_sizer_add_sizer
    public :: wxf_sizer_add_spacer, wxf_sizer_add_stretch, wxf_sizer_item_count, wxf_sizer_destroy

    interface

        !> Create a frame (`parent` 0 for none; size <= 0 for the default).
        function wxf_frame_create(parent, title, len, width, height, out) bind(C, name='wxf_frame_create') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: title(*)
            integer(c_int), value :: len, width, height
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_frame_create

        !> Set a top-level window's title.
        function wxf_frame_set_title(h, s, len) bind(C, name='wxf_frame_set_title') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function wxf_frame_set_title

        !> A top-level window's title (malloc'd).
        function wxf_frame_get_title(h, s, len) bind(C, name='wxf_frame_get_title') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_frame_get_title

        !> Create a panel.
        function wxf_panel_create(parent, out) bind(C, name='wxf_panel_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_panel_create

        !> Create a static text label.
        function wxf_static_text_create(parent, label, len, out) bind(C, name='wxf_static_text_create') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_static_text_create

        !> Create a push button.
        function wxf_button_create(parent, label, len, out) bind(C, name='wxf_button_create') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_button_create

        !> Send a click event to a button's handlers.
        function wxf_button_emit_click(h) bind(C, name='wxf_button_emit_click') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_button_emit_click

        !> Queue a click event for the event loop.
        function wxf_button_post_click(h) bind(C, name='wxf_button_post_click') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_button_post_click

        !> Create a text control.
        function wxf_text_ctrl_create(parent, value, len, style, out) bind(C, name='wxf_text_ctrl_create') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: value(*)
            integer(c_int), value :: len, style
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_text_ctrl_create

        !> Set the text of a text control (`notify` 1 sends `wxEVT_TEXT`).
        function wxf_text_ctrl_set_value(h, s, len, notify) bind(C, name='wxf_text_ctrl_set_value') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len, notify
            integer(c_int) :: r
        end function wxf_text_ctrl_set_value

        !> The text of a text control (malloc'd).
        function wxf_text_ctrl_get_value(h, s, len) bind(C, name='wxf_text_ctrl_get_value') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_text_ctrl_get_value

        !> Append text to a text control.
        function wxf_text_ctrl_append(h, s, len) bind(C, name='wxf_text_ctrl_append') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len
            integer(c_int) :: r
        end function wxf_text_ctrl_append

        !> Clear a text control.
        function wxf_text_ctrl_clear(h) bind(C, name='wxf_text_ctrl_clear') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_text_ctrl_clear

        !> Make a text control editable (1) or read-only (0).
        function wxf_text_ctrl_set_editable(h, editable) bind(C, name='wxf_text_ctrl_set_editable') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: editable
            integer(c_int) :: r
        end function wxf_text_ctrl_set_editable

        !> Create a check box.
        function wxf_check_box_create(parent, label, len, out) bind(C, name='wxf_check_box_create') result(r)
            import :: c_int, c_int64_t, c_char
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_check_box_create

        !> Check (1) or uncheck (0) a check box (no event).
        function wxf_check_box_set_value(h, value) bind(C, name='wxf_check_box_set_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: value
            integer(c_int) :: r
        end function wxf_check_box_set_value

        !> Whether a check box is checked.
        function wxf_check_box_get_value(h, value) bind(C, name='wxf_check_box_get_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: value
            integer(c_int) :: r
        end function wxf_check_box_get_value

        !> Toggle a check box and send its event.
        function wxf_check_box_emit_click(h) bind(C, name='wxf_check_box_emit_click') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_check_box_emit_click

        !> Create a box sizer (`orient` 0 horizontal, 1 vertical).
        function wxf_box_sizer_create(orient, out) bind(C, name='wxf_box_sizer_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int), value :: orient
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_box_sizer_create

        !> Add a window to a sizer.
        function wxf_sizer_add_window(s, h, proportion, flags, border) bind(C, name='wxf_sizer_add_window') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: s, h
            integer(c_int), value :: proportion, flags, border
            integer(c_int) :: r
        end function wxf_sizer_add_window

        !> Add a sizer to a sizer (which then owns it).
        function wxf_sizer_add_sizer(s, child, proportion, flags, border) bind(C, name='wxf_sizer_add_sizer') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: s, child
            integer(c_int), value :: proportion, flags, border
            integer(c_int) :: r
        end function wxf_sizer_add_sizer

        !> Add fixed empty space to a sizer.
        function wxf_sizer_add_spacer(s, size) bind(C, name='wxf_sizer_add_spacer') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: s
            integer(c_int), value :: size
            integer(c_int) :: r
        end function wxf_sizer_add_spacer

        !> Add stretchable empty space to a sizer.
        function wxf_sizer_add_stretch(s, proportion) bind(C, name='wxf_sizer_add_stretch') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: s
            integer(c_int), value :: proportion
            integer(c_int) :: r
        end function wxf_sizer_add_stretch

        !> Number of items in a sizer.
        function wxf_sizer_item_count(s, n) bind(C, name='wxf_sizer_item_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: s
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_sizer_item_count

        !> Delete an unattached sizer.
        function wxf_sizer_destroy(s) bind(C, name='wxf_sizer_destroy') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: s
            integer(c_int) :: r
        end function wxf_sizer_destroy

    end interface

end module wx_c_widgets

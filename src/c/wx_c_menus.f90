!> Private `bind(C)` interfaces to the timer and menu parts of the C++ shim
!> (src/shim/wxf_timer.cpp, src/shim/wxf_menus.cpp), and their constants.
module wx_c_menus

    use iso_c_binding
    implicit none
    private

    ! menu item kinds (wxWidgets' own values)
    integer(c_int), parameter, public :: wxITEM_NORMAL = 0   !! a plain menu item
    integer(c_int), parameter, public :: wxITEM_CHECK = 1    !! a check item (toggles)
    integer(c_int), parameter, public :: wxITEM_RADIO = 2    !! a radio item (one of a group)

    ! stock ids (wxWidgets' own values, checked in src/shim/wxf_menus.cpp): a
    ! stock menu item gets the standard label, accelerator and, on macOS, its
    ! place in the application menu (wxID_EXIT, wxID_ABOUT, wxID_PREFERENCES)
    integer(c_int), parameter, public :: wxID_OPEN = 5000         !! Open
    integer(c_int), parameter, public :: wxID_CLOSE = 5001        !! Close
    integer(c_int), parameter, public :: wxID_NEW = 5002          !! New
    integer(c_int), parameter, public :: wxID_SAVE = 5003         !! Save
    integer(c_int), parameter, public :: wxID_SAVEAS = 5004       !! Save As
    integer(c_int), parameter, public :: wxID_EXIT = 5006         !! Quit / Exit
    integer(c_int), parameter, public :: wxID_UNDO = 5007         !! Undo
    integer(c_int), parameter, public :: wxID_REDO = 5008         !! Redo
    integer(c_int), parameter, public :: wxID_HELP = 5009         !! Help
    integer(c_int), parameter, public :: wxID_ABOUT = 5014        !! About
    integer(c_int), parameter, public :: wxID_PREFERENCES = 5022  !! Preferences
    integer(c_int), parameter, public :: wxID_CUT = 5031          !! Cut
    integer(c_int), parameter, public :: wxID_COPY = 5032         !! Copy
    integer(c_int), parameter, public :: wxID_PASTE = 5033        !! Paste

    public :: wxf_timer_create, wxf_timer_start, wxf_timer_stop, wxf_timer_is_running
    public :: wxf_timer_get_interval, wxf_timer_destroy, wxf_menu_bar_create
    public :: wxf_menu_bar_append, wxf_menu_bar_menu_count, wxf_frame_set_menu_bar
    public :: wxf_menu_create, wxf_menu_append, wxf_menu_append_separator
    public :: wxf_menu_append_submenu, wxf_menu_item_count, wxf_menu_enable
    public :: wxf_menu_is_enabled, wxf_menu_check, wxf_menu_is_checked, wxf_menu_set_label
    public :: wxf_menu_get_label, wxf_menu_emit_select, wxf_menu_destroy
    public :: wxf_frame_create_status_bar, wxf_frame_set_status_text
    public :: wxf_frame_get_status_text, wxf_frame_status_field_count

    interface

        !> Create a timer (`owner` 0 for none).
        function wxf_timer_create(owner, out) bind(C, name='wxf_timer_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: owner
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_timer_create

        !> Start a timer.
        function wxf_timer_start(h, ms, one_shot) bind(C, name='wxf_timer_start') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: ms
            integer(c_int), value :: one_shot
            integer(c_int) :: r
        end function wxf_timer_start

        !> Stop a timer.
        function wxf_timer_stop(h) bind(C, name='wxf_timer_stop') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_timer_stop

        !> Whether a timer runs.
        function wxf_timer_is_running(h, running) bind(C, name='wxf_timer_is_running') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: running
            integer(c_int) :: r
        end function wxf_timer_is_running

        !> A timer's interval in milliseconds.
        function wxf_timer_get_interval(h, ms) bind(C, name='wxf_timer_get_interval') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: ms
            integer(c_int) :: r
        end function wxf_timer_get_interval

        !> Stop and delete a timer.
        function wxf_timer_destroy(h) bind(C, name='wxf_timer_destroy') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_timer_destroy

        !> Create a menu bar.
        function wxf_menu_bar_create(out) bind(C, name='wxf_menu_bar_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_menu_bar_create

        !> Append a menu to a menu bar.
        function wxf_menu_bar_append(h, menu, title, len_title) bind(C, name='wxf_menu_bar_append') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: menu
            character(kind=c_char), intent(in) :: title(*)
            integer(c_int), value :: len_title
            integer(c_int) :: r
        end function wxf_menu_bar_append

        !> Number of menus in a menu bar.
        function wxf_menu_bar_menu_count(h, n) bind(C, name='wxf_menu_bar_menu_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_menu_bar_menu_count

        !> Set a frame's menu bar.
        function wxf_frame_set_menu_bar(h, bar) bind(C, name='wxf_frame_set_menu_bar') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: bar
            integer(c_int) :: r
        end function wxf_frame_set_menu_bar

        !> Create a menu.
        function wxf_menu_create(title, len_title, out) bind(C, name='wxf_menu_create') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            character(kind=c_char), intent(in) :: title(*)
            integer(c_int), value :: len_title
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_menu_create

        !> Append a menu item; `out_id` gets its id.
        function wxf_menu_append(h, id, text, len_text, help, len_help, kind, out_id) bind(C, name='wxf_menu_append') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            character(kind=c_char), intent(in) :: text(*)
            integer(c_int), value :: len_text
            character(kind=c_char), intent(in) :: help(*)
            integer(c_int), value :: len_help
            integer(c_int), value :: kind
            integer(c_int), intent(out) :: out_id
            integer(c_int) :: r
        end function wxf_menu_append

        !> Append a separator.
        function wxf_menu_append_separator(h) bind(C, name='wxf_menu_append_separator') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_menu_append_separator

        !> Append a submenu.
        function wxf_menu_append_submenu(h, sub, text, len_text) bind(C, name='wxf_menu_append_submenu') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: sub
            character(kind=c_char), intent(in) :: text(*)
            integer(c_int), value :: len_text
            integer(c_int) :: r
        end function wxf_menu_append_submenu

        !> Number of items in a menu.
        function wxf_menu_item_count(h, n) bind(C, name='wxf_menu_item_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_menu_item_count

        !> Enable or disable a menu item.
        function wxf_menu_enable(h, id, enable) bind(C, name='wxf_menu_enable') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), value :: enable
            integer(c_int) :: r
        end function wxf_menu_enable

        !> Whether a menu item is enabled.
        function wxf_menu_is_enabled(h, id, enabled) bind(C, name='wxf_menu_is_enabled') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), intent(out) :: enabled
            integer(c_int) :: r
        end function wxf_menu_is_enabled

        !> Check or uncheck a menu item.
        function wxf_menu_check(h, id, check) bind(C, name='wxf_menu_check') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), value :: check
            integer(c_int) :: r
        end function wxf_menu_check

        !> Whether a menu item is checked.
        function wxf_menu_is_checked(h, id, checked) bind(C, name='wxf_menu_is_checked') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), intent(out) :: checked
            integer(c_int) :: r
        end function wxf_menu_is_checked

        !> Set a menu item's label.
        function wxf_menu_set_label(h, id, s, len_s) bind(C, name='wxf_menu_set_label') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            integer(c_int) :: r
        end function wxf_menu_set_label

        !> A menu item's label (malloc'd).
        function wxf_menu_get_label(h, id, s, len) bind(C, name='wxf_menu_get_label') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_menu_get_label

        !> Select a menu item as the user would.
        function wxf_menu_emit_select(h, id) bind(C, name='wxf_menu_emit_select') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int) :: r
        end function wxf_menu_emit_select

        !> Delete an unattached menu.
        function wxf_menu_destroy(h) bind(C, name='wxf_menu_destroy') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_menu_destroy

        !> Give a frame a status bar.
        function wxf_frame_create_status_bar(h, fields) bind(C, name='wxf_frame_create_status_bar') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: fields
            integer(c_int) :: r
        end function wxf_frame_create_status_bar

        !> Set a status bar field's text.
        function wxf_frame_set_status_text(h, s, len_s, field) bind(C, name='wxf_frame_set_status_text') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            integer(c_int), value :: field
            integer(c_int) :: r
        end function wxf_frame_set_status_text

        !> A status bar field's text (malloc'd).
        function wxf_frame_get_status_text(h, field, s, len) bind(C, name='wxf_frame_get_status_text') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: field
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_frame_get_status_text

        !> Number of status bar fields (0: none).
        function wxf_frame_status_field_count(h, n) bind(C, name='wxf_frame_status_field_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_frame_status_field_count

    end interface

end module wx_c_menus

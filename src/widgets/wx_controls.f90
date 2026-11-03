!> Top-level windows, containers and common controls.
!>
!> Each type has a constructor of the same name that creates the native
!> window: `frame = wx_frame("Title")`, `button = wx_button(panel, "OK")`.
!> Child windows take their parent as the first argument and are owned by it
!> (see [[wx_windows]]). If creation fails the wrapper is invalid.
module wx_controls

    use iso_c_binding
    use wx_c_core
    use wx_c_widgets
    use wx_base
    use wx_windows
    implicit none
    private

    public :: wxTE_MULTILINE, wxTE_PROCESS_ENTER, wxTE_READONLY, wxTE_PASSWORD

    !> A top-level window with a title bar.
    type, extends(wx_window), public :: wx_frame
    contains
        procedure :: set_title => wx_frame_set_title
        procedure :: get_title => wx_frame_get_title
    end type wx_frame

    !> Create a frame (initially hidden: call `show`).
    interface wx_frame
        module procedure wx_frame_new
    end interface wx_frame

    !> A container for controls (gives the standard dialog background and
    !> keyboard navigation between its children).
    type, extends(wx_window), public :: wx_panel
    end type wx_panel

    !> Create a panel.
    interface wx_panel
        module procedure wx_panel_new
    end interface wx_panel

    !> A read-only text label.
    type, extends(wx_window), public :: wx_static_text
    end type wx_static_text

    !> Create a static text label.
    interface wx_static_text
        module procedure wx_static_text_new
    end interface wx_static_text

    !> A push button: generates `wxEVT_BUTTON` when clicked.
    type, extends(wx_window), public :: wx_button
    contains
        procedure :: emit_click => wx_button_emit_click
        procedure :: post_click => wx_button_post_click
    end type wx_button

    !> Create a push button.
    interface wx_button
        module procedure wx_button_new
    end interface wx_button

    !> An editable text field: generates `wxEVT_TEXT` when its text changes,
    !> and `wxEVT_TEXT_ENTER` on Enter if created with `wxTE_PROCESS_ENTER`.
    type, extends(wx_window), public :: wx_text_ctrl
    contains
        procedure :: set_value => wx_text_ctrl_set_value
        procedure :: change_value => wx_text_ctrl_change_value
        procedure :: get_value => wx_text_ctrl_get_value
        procedure :: append_text => wx_text_ctrl_append_text
        procedure :: clear => wx_text_ctrl_clear
        procedure :: set_editable => wx_text_ctrl_set_editable
    end type wx_text_ctrl

    !> Create a text control.
    interface wx_text_ctrl
        module procedure wx_text_ctrl_new
    end interface wx_text_ctrl

    !> A check box with a label: generates `wxEVT_CHECKBOX` when toggled.
    type, extends(wx_window), public :: wx_check_box
    contains
        procedure :: set_value => wx_check_box_set_value
        procedure :: get_value => wx_check_box_get_value
        procedure :: emit_click => wx_check_box_emit_click
    end type wx_check_box

    !> Create a check box.
    interface wx_check_box
        module procedure wx_check_box_new
    end interface wx_check_box

contains

    !> Report a creation status; on failure the new handle is cleared.
    subroutine created(status, h, stat)
        integer(c_int), intent(in) :: status
        integer(c_int64_t), intent(inout) :: h
        integer, intent(out), optional :: stat
        if (status /= WX_OK) h = 0
        call wx_check(status, stat)
    end subroutine created

    ! -------------------------------------------------------------------------
    ! wx_frame

    !> Create a frame with `title`, optional size in pixels, and optional
    !> `parent` (a frame with a parent stays on top of it and is destroyed with it).
    type(wx_frame) function wx_frame_new(title, width, height, parent, stat)
        character(len=*), intent(in) :: title
        integer, intent(in), optional :: width, height
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        integer(c_int64_t) :: p
        integer(c_int) :: w, h
        p = 0
        if (present(parent)) p = parent%h
        w = -1
        h = -1
        if (present(width)) w = int(width, c_int)
        if (present(height)) h = int(height, c_int)
        call created(wxf_frame_create(p, title, len(title, c_int), w, h, wx_frame_new%h), &
                     wx_frame_new%h, stat)
    end function wx_frame_new

    !> Set the title bar text.
    subroutine wx_frame_set_title(self, title, stat)
        class(wx_frame), intent(inout) :: self
        character(len=*), intent(in) :: title
        integer, intent(out), optional :: stat
        call wx_check(wxf_frame_set_title(self%h, title, len(title, c_int)), stat)
    end subroutine wx_frame_set_title

    !> The title bar text.
    function wx_frame_get_title(self, stat) result(s)
        class(wx_frame), intent(in) :: self
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        type(c_ptr) :: p
        integer(c_int) :: len, status
        status = wxf_frame_get_title(self%h, p, len)
        s = wx_take_string(status, p, len, stat)
    end function wx_frame_get_title

    ! -------------------------------------------------------------------------
    ! wx_panel, wx_static_text

    !> Create a panel inside `parent`.
    type(wx_panel) function wx_panel_new(parent, stat)
        class(wx_window), intent(in) :: parent
        integer, intent(out), optional :: stat
        call created(wxf_panel_create(parent%h, wx_panel_new%h), wx_panel_new%h, stat)
    end function wx_panel_new

    !> Create a label showing `label` inside `parent`.
    type(wx_static_text) function wx_static_text_new(parent, label, stat)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in) :: label
        integer, intent(out), optional :: stat
        call created(wxf_static_text_create(parent%h, label, len(label, c_int), wx_static_text_new%h), &
                     wx_static_text_new%h, stat)
    end function wx_static_text_new

    ! -------------------------------------------------------------------------
    ! wx_button

    !> Create a button labelled `label` inside `parent`.
    type(wx_button) function wx_button_new(parent, label, stat)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in) :: label
        integer, intent(out), optional :: stat
        call created(wxf_button_create(parent%h, label, len(label, c_int), wx_button_new%h), &
                     wx_button_new%h, stat)
    end function wx_button_new

    !> Send a `wxEVT_BUTTON` event to the button's handlers, as a click would
    !> (for tests and automation). Handlers run before this returns.
    subroutine wx_button_emit_click(self, stat)
        class(wx_button), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_button_emit_click(self%h), stat)
    end subroutine wx_button_emit_click

    !> Queue a `wxEVT_BUTTON` event, as a click would: the event loop
    !> delivers it later (in `app%run()` or `app%process_pending()`), not
    !> before this returns.
    subroutine wx_button_post_click(self, stat)
        class(wx_button), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_button_post_click(self%h), stat)
    end subroutine wx_button_post_click

    ! -------------------------------------------------------------------------
    ! wx_text_ctrl

    !> Create a text control inside `parent` with initial text `value` and
    !> `style` (a combination of `wxTE_*`, default single-line).
    type(wx_text_ctrl) function wx_text_ctrl_new(parent, value, style, stat)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in), optional :: value
        integer, intent(in), optional :: style
        integer, intent(out), optional :: stat
        integer(c_int) :: st
        st = 0
        if (present(style)) st = int(style, c_int)
        if (present(value)) then
            call created(wxf_text_ctrl_create(parent%h, value, len(value, c_int), st, wx_text_ctrl_new%h), &
                         wx_text_ctrl_new%h, stat)
        else
            call created(wxf_text_ctrl_create(parent%h, '', 0_c_int, st, wx_text_ctrl_new%h), &
                         wx_text_ctrl_new%h, stat)
        end if
    end function wx_text_ctrl_new

    !> Replace the text; sends `wxEVT_TEXT` (handlers run before this returns).
    subroutine wx_text_ctrl_set_value(self, value, stat)
        class(wx_text_ctrl), intent(inout) :: self
        character(len=*), intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_text_ctrl_set_value(self%h, value, len(value, c_int), 1_c_int), stat)
    end subroutine wx_text_ctrl_set_value

    !> Replace the text without sending `wxEVT_TEXT`.
    subroutine wx_text_ctrl_change_value(self, value, stat)
        class(wx_text_ctrl), intent(inout) :: self
        character(len=*), intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_text_ctrl_set_value(self%h, value, len(value, c_int), 0_c_int), stat)
    end subroutine wx_text_ctrl_change_value

    !> The current text.
    function wx_text_ctrl_get_value(self, stat) result(s)
        class(wx_text_ctrl), intent(in) :: self
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        type(c_ptr) :: p
        integer(c_int) :: len, status
        status = wxf_text_ctrl_get_value(self%h, p, len)
        s = wx_take_string(status, p, len, stat)
    end function wx_text_ctrl_get_value

    !> Append `text` at the end (sends `wxEVT_TEXT`).
    subroutine wx_text_ctrl_append_text(self, text, stat)
        class(wx_text_ctrl), intent(inout) :: self
        character(len=*), intent(in) :: text
        integer, intent(out), optional :: stat
        call wx_check(wxf_text_ctrl_append(self%h, text, len(text, c_int)), stat)
    end subroutine wx_text_ctrl_append_text

    !> Remove all text (sends `wxEVT_TEXT`).
    subroutine wx_text_ctrl_clear(self, stat)
        class(wx_text_ctrl), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_text_ctrl_clear(self%h), stat)
    end subroutine wx_text_ctrl_clear

    !> Allow (or with `.false.` prevent) editing by the user.
    subroutine wx_text_ctrl_set_editable(self, editable, stat)
        class(wx_text_ctrl), intent(inout) :: self
        logical, intent(in) :: editable
        integer, intent(out), optional :: stat
        call wx_check(wxf_text_ctrl_set_editable(self%h, wx_int(editable)), stat)
    end subroutine wx_text_ctrl_set_editable

    ! -------------------------------------------------------------------------
    ! wx_check_box

    !> Create a check box labelled `label` inside `parent`.
    type(wx_check_box) function wx_check_box_new(parent, label, checked, stat)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in) :: label
        logical, intent(in), optional :: checked
        integer, intent(out), optional :: stat
        integer(c_int) :: status
        status = wxf_check_box_create(parent%h, label, len(label, c_int), wx_check_box_new%h)
        if (status == WX_OK .and. present(checked)) &
            status = wxf_check_box_set_value(wx_check_box_new%h, wx_int(checked))
        call created(status, wx_check_box_new%h, stat)
    end function wx_check_box_new

    !> Check (or uncheck) the box, without sending `wxEVT_CHECKBOX`.
    subroutine wx_check_box_set_value(self, checked, stat)
        class(wx_check_box), intent(inout) :: self
        logical, intent(in) :: checked
        integer, intent(out), optional :: stat
        call wx_check(wxf_check_box_set_value(self%h, wx_int(checked)), stat)
    end subroutine wx_check_box_set_value

    !> True if the box is checked.
    logical function wx_check_box_get_value(self, stat)
        class(wx_check_box), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_check_box_get_value(self%h, v), stat)
        wx_check_box_get_value = wx_logical(v)
    end function wx_check_box_get_value

    !> Toggle the box and send `wxEVT_CHECKBOX`, as a click would (for tests
    !> and automation).
    subroutine wx_check_box_emit_click(self, stat)
        class(wx_check_box), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_check_box_emit_click(self%h), stat)
    end subroutine wx_check_box_emit_click

end module wx_controls

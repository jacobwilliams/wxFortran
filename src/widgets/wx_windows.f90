!> Windows and sizers: [[wx_window]], the base of every widget, and the
!> layout sizers ([[wx_sizer]], [[wx_box_sizer]]).
!>
!> ### Ownership
!>
!> * A child window belongs to its parent and is destroyed with it.
!> * A top-level window (frame) is destroyed by `destroy`, by a `close` that
!>   is not vetoed, or by the user closing it. Its deletion happens when
!>   pending events are next processed, but its handle (and those of its
!>   children) is invalid immediately.
!> * A new sizer is unattached. `window%set_sizer(sizer)` or
!>   `parent_sizer%add(sizer)` transfer it to its new owner, which destroys
!>   it; an unattached sizer must be destroyed with `sizer%destroy()`.
!>   Replacing a window's sizer destroys the old one.
module wx_windows

    use iso_c_binding
    use wx_c_core
    use wx_c_widgets
    use wx_base
    use wx_events
    implicit none
    private

    public :: wxHORIZONTAL, wxVERTICAL
    public :: wxEXPAND, wxALL, wxLEFT, wxRIGHT, wxTOP, wxBOTTOM
    public :: wxALIGN_CENTER, wxALIGN_RIGHT, wxALIGN_BOTTOM

    !> Any window or control.
    type, extends(wx_evt_handler), public :: wx_window
    contains
        procedure :: destroy => wx_window_destroy
        procedure :: close => wx_window_close
        procedure :: show => wx_window_show
        procedure :: hide => wx_window_hide
        procedure :: is_shown => wx_window_is_shown
        procedure :: enable => wx_window_enable
        procedure :: disable => wx_window_disable
        procedure :: is_enabled => wx_window_is_enabled
        procedure :: set_label => wx_window_set_label
        procedure :: get_label => wx_window_get_label
        procedure :: set_size => wx_window_set_size
        procedure :: get_size => wx_window_get_size
        procedure :: set_min_size => wx_window_set_min_size
        procedure :: set_position => wx_window_set_position
        procedure :: get_position => wx_window_get_position
        procedure :: get_parent => wx_window_get_parent
        procedure :: get_id => wx_window_get_id
        procedure :: set_focus => wx_window_set_focus
        procedure :: set_tooltip => wx_window_set_tooltip
        procedure :: layout => wx_window_layout
        procedure :: fit => wx_window_fit
        procedure :: center => wx_window_center
        procedure :: child_count => wx_window_child_count
        procedure :: set_sizer => wx_window_set_sizer
    end type wx_window

    !> A generic window reference to an existing object (e.g. `event%source()`).
    interface wx_window
        module procedure wx_window_from
    end interface wx_window

    !> A layout manager that sizes and positions the children of a window.
    type, extends(wx_object), public :: wx_sizer
    contains
        procedure, private :: wx_sizer_add_window
        procedure, private :: wx_sizer_add_sizer
        generic :: add => wx_sizer_add_window, wx_sizer_add_sizer
        procedure :: add_spacer => wx_sizer_add_spacer
        procedure :: add_stretch => wx_sizer_add_stretch
        procedure :: item_count => wx_sizer_item_count
        procedure :: destroy => wx_sizer_destroy
    end type wx_sizer

    !> A sizer that lays out its items in a row or a column.
    type, extends(wx_sizer), public :: wx_box_sizer
    end type wx_box_sizer

    !> Create a box sizer: `wx_box_sizer(wxVERTICAL)` or `wx_box_sizer(wxHORIZONTAL)`.
    interface wx_box_sizer
        module procedure wx_box_sizer_new
    end interface wx_box_sizer

contains

    ! -------------------------------------------------------------------------
    ! wx_window

    !> A window reference to the object `obj` (no new window is created).
    type(wx_window) function wx_window_from(obj)
        class(wx_object), intent(in) :: obj
        wx_window_from%h = obj%h
    end function wx_window_from

    !> Destroy the window and its children. Its handle (and theirs) is invalid
    !> immediately. Top-level windows are deleted when pending events are next
    !> processed. A child window destroyed from an event handler is hidden
    !> now and deleted the same way, since wxWidgets may still be using it
    !> (e.g. a button destroyed by its own click handler).
    subroutine wx_window_destroy(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_destroy(self%h), stat)
    end subroutine wx_window_destroy

    !> Ask the window to close, as if the user did: sends `wxEVT_CLOSE_WINDOW`
    !> (handlers may veto it unless `force` is true). By default, a closed
    !> frame is destroyed. Returns false if the close was vetoed.
    logical function wx_window_close(self, force, stat)
        class(wx_window), intent(inout) :: self
        logical, intent(in), optional :: force
        integer, intent(out), optional :: stat
        integer(c_int) :: closed
        logical :: f
        f = .false.
        if (present(force)) f = force
        closed = 0
        call wx_check(wxf_window_close(self%h, wx_int(f), closed), stat)
        wx_window_close = wx_logical(closed)
    end function wx_window_close

    !> Show the window (or hide it with `show=.false.`).
    subroutine wx_window_show(self, show, stat)
        class(wx_window), intent(inout) :: self
        logical, intent(in), optional :: show
        integer, intent(out), optional :: stat
        logical :: s
        s = .true.
        if (present(show)) s = show
        call wx_check(wxf_window_show(self%h, wx_int(s)), stat)
    end subroutine wx_window_show

    !> Hide the window.
    subroutine wx_window_hide(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_show(self%h, 0_c_int), stat)
    end subroutine wx_window_hide

    !> True if the window is shown.
    logical function wx_window_is_shown(self, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_window_is_shown(self%h, v), stat)
        wx_window_is_shown = wx_logical(v)
    end function wx_window_is_shown

    !> Enable the window (or disable it with `enable=.false.`).
    subroutine wx_window_enable(self, enable, stat)
        class(wx_window), intent(inout) :: self
        logical, intent(in), optional :: enable
        integer, intent(out), optional :: stat
        logical :: e
        e = .true.
        if (present(enable)) e = enable
        call wx_check(wxf_window_enable(self%h, wx_int(e)), stat)
    end subroutine wx_window_enable

    !> Disable the window (it ignores user input).
    subroutine wx_window_disable(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_enable(self%h, 0_c_int), stat)
    end subroutine wx_window_disable

    !> True if the window is enabled.
    logical function wx_window_is_enabled(self, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_window_is_enabled(self%h, v), stat)
        wx_window_is_enabled = wx_logical(v)
    end function wx_window_is_enabled

    !> Set the window's label (e.g. the text of a button or static text).
    subroutine wx_window_set_label(self, label, stat)
        class(wx_window), intent(inout) :: self
        character(len=*), intent(in) :: label
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_set_label(self%h, label, len(label, c_int)), stat)
    end subroutine wx_window_set_label

    !> The window's label.
    function wx_window_get_label(self, stat) result(s)
        class(wx_window), intent(in) :: self
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        type(c_ptr) :: p
        integer(c_int) :: len, status
        status = wxf_window_get_label(self%h, p, len)
        s = wx_take_string(status, p, len, stat)
    end function wx_window_get_label

    !> Set the window's size in pixels.
    subroutine wx_window_set_size(self, width, height, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(in) :: width, height
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_set_size(self%h, int(width, c_int), int(height, c_int)), stat)
    end subroutine wx_window_set_size

    !> The window's size in pixels.
    subroutine wx_window_get_size(self, width, height, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out) :: width, height
        integer, intent(out), optional :: stat
        integer(c_int) :: w, h
        w = 0
        h = 0
        call wx_check(wxf_window_get_size(self%h, w, h), stat)
        width = w
        height = h
    end subroutine wx_window_get_size

    !> Set the smallest size the window may be given by layout or the user.
    subroutine wx_window_set_min_size(self, width, height, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(in) :: width, height
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_set_min_size(self%h, int(width, c_int), int(height, c_int)), stat)
    end subroutine wx_window_set_min_size

    !> Move the window (relative to its parent; on screen for top-level windows).
    subroutine wx_window_set_position(self, x, y, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(in) :: x, y
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_set_position(self%h, int(x, c_int), int(y, c_int)), stat)
    end subroutine wx_window_set_position

    !> The window's position.
    subroutine wx_window_get_position(self, x, y, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out) :: x, y
        integer, intent(out), optional :: stat
        integer(c_int) :: cx, cy
        cx = 0
        cy = 0
        call wx_check(wxf_window_get_position(self%h, cx, cy), stat)
        x = cx
        y = cy
    end subroutine wx_window_get_position

    !> The window's parent (invalid if it has none).
    type(wx_window) function wx_window_get_parent(self, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_get_parent(self%h, wx_window_get_parent%h), stat)
    end function wx_window_get_parent

    !> The window's wxWidgets id.
    integer function wx_window_get_id(self, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_window_get_id(self%h, v), stat)
        wx_window_get_id = v
    end function wx_window_get_id

    !> Give the window the keyboard focus.
    subroutine wx_window_set_focus(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_set_focus(self%h), stat)
    end subroutine wx_window_set_focus

    !> Set the tooltip shown when the mouse rests over the window.
    subroutine wx_window_set_tooltip(self, tip, stat)
        class(wx_window), intent(inout) :: self
        character(len=*), intent(in) :: tip
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_set_tooltip(self%h, tip, len(tip, c_int)), stat)
    end subroutine wx_window_set_tooltip

    !> Lay out the children with the window's sizer.
    subroutine wx_window_layout(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_layout(self%h), stat)
    end subroutine wx_window_layout

    !> Resize the window to fit its children (its sizer's minimum size).
    subroutine wx_window_fit(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_fit(self%h), stat)
    end subroutine wx_window_fit

    !> Center the window on its parent (top-level windows: on the screen).
    subroutine wx_window_center(self, stat)
        class(wx_window), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_window_center(self%h), stat)
    end subroutine wx_window_center

    !> Number of direct child windows.
    integer function wx_window_child_count(self, stat)
        class(wx_window), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: n
        n = 0
        call wx_check(wxf_window_child_count(self%h, n), stat)
        wx_window_child_count = n
    end function wx_window_child_count

    !> Use `sizer` to lay out the window's children; the window takes
    !> ownership of it (and destroys any previous sizer). With `fit=.true.`,
    !> also resize the window to fit the sizer.
    subroutine wx_window_set_sizer(self, sizer, fit, stat)
        class(wx_window), intent(inout) :: self
        class(wx_sizer), intent(in) :: sizer
        logical, intent(in), optional :: fit
        integer, intent(out), optional :: stat
        logical :: f
        f = .false.
        if (present(fit)) f = fit
        call wx_check(wxf_window_set_sizer(self%h, sizer%h, wx_int(f)), stat)
    end subroutine wx_window_set_sizer

    ! -------------------------------------------------------------------------
    ! sizers

    !> Create a box sizer laying out items along `orient`
    !> (`wxHORIZONTAL` or `wxVERTICAL`).
    type(wx_box_sizer) function wx_box_sizer_new(orient, stat)
        integer, intent(in) :: orient
        integer, intent(out), optional :: stat
        integer(c_int) :: status
        status = wxf_box_sizer_create(int(orient, c_int), wx_box_sizer_new%h)
        if (status /= WX_OK) wx_box_sizer_new%h = 0
        call wx_check(status, stat)
    end function wx_box_sizer_new

    !> Add a window. `proportion` (default 0) is its share of extra space along
    !> the sizer direction; `flags` combine `wxEXPAND`, border sides (`wxALL`,
    !> `wxLEFT`, ...) and alignment; `border` is the border width in pixels.
    subroutine wx_sizer_add_window(self, window, proportion, flags, border, stat)
        class(wx_sizer), intent(inout) :: self
        class(wx_window), intent(in) :: window
        integer, intent(in), optional :: proportion, flags, border
        integer, intent(out), optional :: stat
        call wx_check(wxf_sizer_add_window(self%h, window%h, opt(proportion), opt(flags), opt(border)), stat)
    end subroutine wx_sizer_add_window

    !> Add a nested sizer, which this sizer then owns (arguments as for windows).
    subroutine wx_sizer_add_sizer(self, sizer, proportion, flags, border, stat)
        class(wx_sizer), intent(inout) :: self
        class(wx_sizer), intent(in) :: sizer
        integer, intent(in), optional :: proportion, flags, border
        integer, intent(out), optional :: stat
        call wx_check(wxf_sizer_add_sizer(self%h, sizer%h, opt(proportion), opt(flags), opt(border)), stat)
    end subroutine wx_sizer_add_sizer

    !> Add `size` pixels of fixed empty space.
    subroutine wx_sizer_add_spacer(self, size, stat)
        class(wx_sizer), intent(inout) :: self
        integer, intent(in) :: size
        integer, intent(out), optional :: stat
        call wx_check(wxf_sizer_add_spacer(self%h, int(size, c_int)), stat)
    end subroutine wx_sizer_add_spacer

    !> Add stretchable empty space (default `proportion` 1).
    subroutine wx_sizer_add_stretch(self, proportion, stat)
        class(wx_sizer), intent(inout) :: self
        integer, intent(in), optional :: proportion
        integer, intent(out), optional :: stat
        integer(c_int) :: p
        p = 1
        if (present(proportion)) p = int(proportion, c_int)
        call wx_check(wxf_sizer_add_stretch(self%h, p), stat)
    end subroutine wx_sizer_add_stretch

    !> Number of items (windows, sizers and spacers).
    integer function wx_sizer_item_count(self, stat)
        class(wx_sizer), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: n
        n = 0
        call wx_check(wxf_sizer_item_count(self%h, n), stat)
        wx_sizer_item_count = n
    end function wx_sizer_item_count

    !> Destroy an unattached sizer (owned sizers are destroyed by their owner).
    subroutine wx_sizer_destroy(self, stat)
        class(wx_sizer), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_sizer_destroy(self%h), stat)
    end subroutine wx_sizer_destroy

    !> An optional integer argument as a C int (default 0).
    pure integer(c_int) function opt(x)
        integer, intent(in), optional :: x
        opt = 0
        if (present(x)) opt = int(x, c_int)
    end function opt

end module wx_windows

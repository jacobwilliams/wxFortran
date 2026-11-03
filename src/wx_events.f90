!> Events: Fortran handlers for wxWidgets events, and deferred calls.
!>
!> ### Contract
!>
!> * A handler is a procedure with the [[wx_event_handler]] interface, bound
!>   to one kind of event on one window with `window%bind`. Handlers run
!>   synchronously on the GUI thread, while wxWidgets processes the event
!>   (normally inside `app%run()`, or during a call that generates the event,
!>   such as `text%set_value` or `button%emit_click`).
!> * The optional `data` given to `bind` is passed back to the handler on every
!>   call. wxFortran keeps a *pointer* to it: the actual argument must have
!>   the `target` attribute (or be a pointer) and must outlive the binding.
!> * The [[wx_event]] passed to a handler is valid only during that call.
!> * As in wxWidgets, an event handled by a handler is not passed on to other
!>   handlers or default processing unless the handler calls `event%skip()`.
!>   For example, a `wxEVT_CLOSE_WINDOW` handler that neither skips nor
!>   destroys the window keeps it open.
!> * A binding ends when it is disconnected (`connection%disconnect()`), or
!>   when its window is destroyed. Its handler is then never called again and
!>   wxFortran drops its pointer to `data`.
!> * wxFortran has no exceptions: a handler reports problems through its
!>   `data` or program state. A failing wxFortran call inside a handler with
!>   no `stat` argument stops the program, as elsewhere.
module wx_events

    use iso_c_binding
    use wx_c_core
    use wx_base
    implicit none
    private

    public :: wxEVT_BUTTON, wxEVT_TEXT, wxEVT_TEXT_ENTER, wxEVT_CLOSE_WINDOW
    public :: wxEVT_SIZE, wxEVT_DESTROY, wxEVT_CHECKBOX, wxEVT_TIMER, wxEVT_MENU, wxID_ANY
    public :: wxEVT_PAINT, wxEVT_LEFT_DOWN, wxEVT_LEFT_UP, wxEVT_RIGHT_DOWN, wxEVT_MOTION
    public :: wxEVT_MOUSEWHEEL, wxEVT_KEY_DOWN, wxEVT_LEFT_DCLICK, wxEVT_LEAVE_WINDOW
    public :: WX_MOD_SHIFT, WX_MOD_CONTROL, WX_MOD_ALT
    public :: WXK_BACK, WXK_TAB, WXK_RETURN, WXK_ESCAPE, WXK_SPACE, WXK_DELETE, WXK_END
    public :: WXK_HOME, WXK_LEFT, WXK_UP, WXK_RIGHT, WXK_DOWN, WXK_F1, WXK_PAGEUP, WXK_PAGEDOWN
    public :: wxEVT_CHOICE, wxEVT_LISTBOX, wxEVT_LISTBOX_DCLICK, wxEVT_SLIDER, wxEVT_SPINCTRL
    public :: wxEVT_RADIOBOX, wxEVT_SPINCTRLDOUBLE, wxEVT_NOTEBOOK_PAGE_CHANGED
    public :: wxEVT_NOTEBOOK_PAGE_CHANGING, wxEVT_TOOL, wxEVT_RIGHT_UP, wxEVT_MOUSE_CAPTURE_LOST
    public :: wx_events_slot_new, wx_events_slot_free
    public :: wx_event_handler, wx_callback
    public :: wx_call_after, wx_active_handlers
    public :: wx_events_install

    !> An event being handled (valid only during the handler call).
    type, public :: wx_event
        type(c_ptr), private :: p = c_null_ptr
        integer, private :: k = 0
    contains
        procedure :: kind => wx_event_kind
        procedure :: skip => wx_event_skip
        procedure :: get_skipped => wx_event_get_skipped
        procedure :: source => wx_event_source
        procedure :: get_id => wx_event_get_id
        procedure :: get_int => wx_event_get_int
        procedure :: get_string => wx_event_get_string
        procedure :: is_checked => wx_event_is_checked
        procedure :: can_veto => wx_event_can_veto
        procedure :: veto => wx_event_veto
        procedure :: get_size => wx_event_get_size
        procedure :: get_position => wx_event_get_position
        procedure :: get_wheel_rotation => wx_event_get_wheel_rotation
        procedure :: left_is_down => wx_event_left_is_down
        procedure :: get_key_code => wx_event_get_key_code
        procedure :: get_unicode_key => wx_event_get_unicode_key
        procedure :: get_modifiers => wx_event_get_modifiers
        procedure :: get_selection => wx_event_get_selection
        procedure :: get_double => wx_event_get_double
        procedure :: c_event => wx_event_c_event
    end type wx_event

    !> Anything that receives events: windows, timers and menus.
    type, extends(wx_object), public :: wx_evt_handler
    contains
        procedure :: bind => wx_evt_handler_bind
    end type wx_evt_handler

    !> A binding of a handler to an object's events (see `bind`).
    type, public :: wx_connection
        integer, private :: slot = 0
        integer, private :: serial = 0
    contains
        procedure :: disconnect => wx_connection_disconnect
        procedure :: is_connected => wx_connection_is_connected
    end type wx_connection

    abstract interface
        !> An event handler. `data` is the optional data given to `bind`.
        subroutine wx_event_handler(event, data)
            import :: wx_event
            implicit none
            type(wx_event), intent(inout) :: event
            class(*), intent(inout), optional :: data
        end subroutine wx_event_handler

        !> A deferred call (see [[wx_call_after]]).
        subroutine wx_callback(data)
            implicit none
            class(*), intent(inout), optional :: data
        end subroutine wx_callback
    end interface

    !> One registered handler or deferred call.
    type :: slot_t
        logical :: used = .false.
        integer :: serial = 0
        procedure(wx_event_handler), pointer, nopass :: on_event => null()
        procedure(wx_callback), pointer, nopass :: on_call => null()
        class(*), pointer :: data => null()
    end type slot_t

    type(slot_t), allocatable, save :: slots(:)
    integer, save :: n_serial = 0
    logical, save :: installed = .false.

contains

    ! -------------------------------------------------------------------------
    ! slot table

    !> Install the dispatcher in the shim (called by `wx_app` initialization).
    subroutine wx_events_install()
        if (installed) return
        call wxf_set_dispatcher(c_funloc(dispatch), c_funloc(release))
        installed = .true.
    end subroutine wx_events_install

    !> A free slot id, growing the table if needed.
    integer function new_slot()
        type(slot_t), allocatable :: tmp(:)
        integer :: i, n
        if (.not. allocated(slots)) allocate(slots(64))
        new_slot = 0
        do i = 1, size(slots)
            if (.not. slots(i)%used) then
                new_slot = i
                exit
            end if
        end do
        if (new_slot == 0) then
            n = size(slots)
            allocate(tmp(2*n))
            tmp(1:n) = slots
            call move_alloc(tmp, slots)
            new_slot = n + 1
        end if
        n_serial = n_serial + 1
        slots(new_slot)%used = .true.
        slots(new_slot)%serial = n_serial
        slots(new_slot)%on_event => null()
        slots(new_slot)%on_call => null()
        slots(new_slot)%data => null()
    end function new_slot

    !> Called by the shim for every event (or deferred call) of a slot.
    subroutine dispatch(slot, event, kind) bind(C)
        integer(c_int), value :: slot
        type(c_ptr), value :: event
        integer(c_int), value :: kind
        procedure(wx_event_handler), pointer :: on_event
        procedure(wx_callback), pointer :: on_call
        class(*), pointer :: data
        type(wx_event) :: ev
        if (.not. allocated(slots)) return
        if (slot < 1 .or. slot > size(slots)) return
        if (.not. slots(slot)%used) return
        ! copy: a handler may bind more (reallocating the table)
        on_event => slots(slot)%on_event
        on_call => slots(slot)%on_call
        data => slots(slot)%data
        if (associated(on_event)) then
            ev%p = event
            ev%k = kind
            if (associated(data)) then
                call on_event(ev, data)
            else
                call on_event(ev)
            end if
        else if (associated(on_call)) then
            if (associated(data)) then
                call on_call(data)
            else
                call on_call()
            end if
        end if
    end subroutine dispatch

    !> Called by the shim when a binding or deferred call is gone.
    subroutine release(slot) bind(C)
        integer(c_int), value :: slot
        if (.not. allocated(slots)) return
        if (slot < 1 .or. slot > size(slots)) return
        slots(slot)%used = .false.
        slots(slot)%on_event => null()
        slots(slot)%on_call => null()
        slots(slot)%data => null()
    end subroutine release

    !> Register `handler` (and `data`) in a temporary slot, for a shim call
    !> that dispatches to it directly; release it with [[wx_events_slot_free]].
    integer function wx_events_slot_new(handler, data) result(slot)
        procedure(wx_event_handler) :: handler
        class(*), intent(inout), target, optional :: data
        slot = new_slot()
        slots(slot)%on_event => handler
        if (present(data)) slots(slot)%data => data
    end function wx_events_slot_new

    !> Release a slot from [[wx_events_slot_new]].
    subroutine wx_events_slot_free(slot)
        integer, intent(in) :: slot
        call release(int(slot, c_int))
    end subroutine wx_events_slot_free

    !> Number of live bindings and pending deferred calls (for leak tests).
    integer function wx_active_handlers()
        integer :: i
        wx_active_handlers = 0
        if (.not. allocated(slots)) return
        do i = 1, size(slots)
            if (slots(i)%used) wx_active_handlers = wx_active_handlers + 1
        end do
    end function wx_active_handlers

    !> Call `handler` for each event of `kind` (`wxEVT_*`) on this object.
    !> With `id`, only for events from the window or menu item with that id
    !> (e.g. one item of a frame's menus: `frame%bind(wxEVT_MENU, on_open, id=id_open)`).
    !> `data` (kept by pointer: give a `target` that outlives the binding) is
    !> passed to the handler. `connection` can be used to remove the binding.
    !> See [[wx_events]] for the full contract.
    subroutine wx_evt_handler_bind(self, kind, handler, data, id, connection, stat)
        class(wx_evt_handler), intent(inout) :: self
        integer, intent(in) :: kind
        procedure(wx_event_handler) :: handler
        class(*), intent(inout), target, optional :: data
        integer, intent(in), optional :: id
        type(wx_connection), intent(out), optional :: connection
        integer, intent(out), optional :: stat
        call wx_events_bind(self%h, kind, handler, data, id, connection, stat)
    end subroutine wx_evt_handler_bind

    !> Bind `handler` to events of `kind` (from `id`, default any) on the
    !> object with handle `h`.
    subroutine wx_events_bind(h, kind, handler, data, id, connection, stat)
        integer(c_int64_t), intent(in) :: h
        integer, intent(in) :: kind
        procedure(wx_event_handler) :: handler
        class(*), intent(inout), target, optional :: data
        integer, intent(in), optional :: id
        type(wx_connection), intent(out), optional :: connection
        integer, intent(out), optional :: stat
        integer :: slot
        integer(c_int) :: status, from
        from = wxID_ANY
        if (present(id)) from = int(id, c_int)
        slot = new_slot()
        slots(slot)%on_event => handler
        if (present(data)) slots(slot)%data => data
        status = wxf_bind(h, int(kind, c_int), int(slot, c_int), from)
        if (status /= WX_OK) then
            call release(int(slot, c_int))
        else if (present(connection)) then
            connection%slot = slot
            connection%serial = slots(slot)%serial
        end if
        call wx_check(status, stat)
    end subroutine wx_events_bind

    !> Call `callback` (with optional `data`, kept by pointer like for `bind`)
    !> once from the event loop, after the events being processed now.
    subroutine wx_call_after(callback, data, stat)
        procedure(wx_callback) :: callback
        class(*), intent(inout), target, optional :: data
        integer, intent(out), optional :: stat
        integer :: id
        integer(c_int) :: status
        id = new_slot()
        slots(id)%on_call => callback
        if (present(data)) slots(id)%data => data
        status = wxf_call_after(int(id, c_int))
        if (status /= WX_OK) call release(int(id, c_int))
        call wx_check(status, stat)
    end subroutine wx_call_after

    ! -------------------------------------------------------------------------
    ! wx_connection

    !> True while the binding exists.
    logical function wx_connection_is_connected(self)
        class(wx_connection), intent(in) :: self
        wx_connection_is_connected = .false.
        if (.not. allocated(slots)) return
        if (self%slot < 1 .or. self%slot > size(slots)) return
        wx_connection_is_connected = slots(self%slot)%used .and. &
                                     slots(self%slot)%serial == self%serial
    end function wx_connection_is_connected

    !> Remove the binding (no effect if it no longer exists).
    subroutine wx_connection_disconnect(self, stat)
        class(wx_connection), intent(inout) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: found
        if (.not. self%is_connected()) then
            if (present(stat)) stat = WX_OK
            return
        end if
        call wx_check(wxf_unbind(int(self%slot, c_int), found), stat)
        self%slot = 0
        self%serial = 0
    end subroutine wx_connection_disconnect

    ! -------------------------------------------------------------------------
    ! wx_event

    !> The event kind (`wxEVT_*`).
    integer function wx_event_kind(self)
        class(wx_event), intent(in) :: self
        wx_event_kind = self%k
    end function wx_event_kind

    !> Let the event continue to other handlers and default processing
    !> (`skip=.false.` undoes this).
    subroutine wx_event_skip(self, skip, stat)
        class(wx_event), intent(inout) :: self
        logical, intent(in), optional :: skip
        integer, intent(out), optional :: stat
        logical :: s
        s = .true.
        if (present(skip)) s = skip
        call wx_check(wxf_event_skip(self%p, wx_int(s)), stat)
    end subroutine wx_event_skip

    !> True if `skip` was called.
    logical function wx_event_get_skipped(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_get_skipped(self%p, v), stat)
        wx_event_get_skipped = wx_logical(v)
    end function wx_event_get_skipped

    !> The window, timer or menu that generated the event (compare it with
    !> `==`, or convert it with e.g. `wx_window(event%source())`).
    type(wx_object) function wx_event_source(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_event_get_source(self%p, wx_event_source%h), stat)
    end function wx_event_source

    !> The wxWidgets id of the window or menu item that generated the event.
    integer function wx_event_get_id(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_get_id(self%p, v), stat)
        wx_event_get_id = v
    end function wx_event_get_id

    !> Command events: the integer value (e.g. 1 if a check box or check menu
    !> item was checked).
    integer function wx_event_get_int(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_get_int(self%p, v), stat)
        wx_event_get_int = v
    end function wx_event_get_int

    !> Command events: the string value (e.g. the new text of a text control).
    function wx_event_get_string(self, stat) result(s)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        type(c_ptr) :: p
        integer(c_int) :: len, status
        status = wxf_event_get_string(self%p, p, len)
        s = wx_take_string(status, p, len, stat)
    end function wx_event_get_string

    !> Check box and check/radio menu item events: true if now checked.
    logical function wx_event_is_checked(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        wx_event_is_checked = self%get_int(stat) /= 0
    end function wx_event_is_checked

    !> Close and notebook page-changing events: true if the change can be
    !> refused with `veto`.
    logical function wx_event_can_veto(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_can_veto(self%p, v), stat)
        wx_event_can_veto = wx_logical(v)
    end function wx_event_can_veto

    !> Close events: refuse to close the window. Notebook page-changing
    !> events: stay on the current page.
    subroutine wx_event_veto(self, stat)
        class(wx_event), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_event_veto(self%p), stat)
    end subroutine wx_event_veto

    !> Mouse events: the position in the window, in pixels from its top-left.
    subroutine wx_event_get_position(self, x, y, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out) :: x, y
        integer, intent(out), optional :: stat
        integer(c_int) :: cx, cy
        cx = 0
        cy = 0
        call wx_check(wxf_event_get_position(self%p, cx, cy), stat)
        x = cx
        y = cy
    end subroutine wx_event_get_position

    !> Mouse wheel events: rotation in notches (positive: away from the
    !> user; fractional for smooth-scrolling devices).
    real(c_double) function wx_event_get_wheel_rotation(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        real(c_double) :: steps
        steps = 0
        call wx_check(wxf_event_get_wheel(self%p, steps), stat)
        wx_event_get_wheel_rotation = steps
    end function wx_event_get_wheel_rotation

    !> Mouse events: true if the left button is down (e.g. while dragging).
    logical function wx_event_left_is_down(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_left_is_down(self%p, v), stat)
        wx_event_left_is_down = wx_logical(v)
    end function wx_event_left_is_down

    !> Key events: the key code: `WXK_*` for special keys, the upper-case
    !> ASCII code for letters and digits (`iachar('A')`).
    integer function wx_event_get_key_code(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: code, uni
        code = 0
        uni = 0
        call wx_check(wxf_event_get_key(self%p, code, uni), stat)
        wx_event_get_key_code = code
    end function wx_event_get_key_code

    !> Key events: the Unicode code point of the key's character (0 if none).
    integer function wx_event_get_unicode_key(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: code, uni
        code = 0
        uni = 0
        call wx_check(wxf_event_get_key(self%p, code, uni), stat)
        wx_event_get_unicode_key = uni
    end function wx_event_get_unicode_key

    !> Mouse and key events: the modifier keys held, as `WX_MOD_*` bits (test
    !> with `iand(event%get_modifiers(), WX_MOD_SHIFT) /= 0`).
    integer function wx_event_get_modifiers(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_get_modifiers(self%p, v), stat)
        wx_event_get_modifiers = v
    end function wx_event_get_modifiers

    !> Choice, list box and radio box events: the item chosen (1-based; 0:
    !> none; `event%get_string()` gives its text). Notebook events: the new page.
    integer function wx_event_get_selection(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_event_get_selection(self%p, v), stat)
        wx_event_get_selection = v
    end function wx_event_get_selection

    !> `wx_spin_ctrl_double` events: the new value. (Integer controls: use
    !> `get_int`.)
    real(c_double) function wx_event_get_double(self, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out), optional :: stat
        real(c_double) :: v
        v = 0
        call wx_check(wxf_event_get_double(self%p, v), stat)
        wx_event_get_double = v
    end function wx_event_get_double

    !> The shim's event pointer (for wxFortran's own modules, e.g. `wx_graphics(event)`).
    type(c_ptr) function wx_event_c_event(self)
        class(wx_event), intent(in) :: self
        wx_event_c_event = self%p
    end function wx_event_c_event

    !> Size events: the new window size in pixels.
    subroutine wx_event_get_size(self, width, height, stat)
        class(wx_event), intent(in) :: self
        integer, intent(out) :: width, height
        integer, intent(out), optional :: stat
        integer(c_int) :: w, h
        w = 0
        h = 0
        call wx_check(wxf_event_get_size(self%p, w, h), stat)
        width = w
        height = h
    end subroutine wx_event_get_size

end module wx_events

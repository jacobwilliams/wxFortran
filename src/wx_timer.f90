!> Timers, which call a handler periodically, or once after a delay, from the
!> event loop.
!>
!> ```fortran
!> timer = wx_timer(owner=frame)
!> call timer%bind(wxEVT_TIMER, on_tick, data=state)
!> call timer%start(500)            ! every 500 ms (one_shot=.true.: once)
!> ```
!>
!> Timer events are delivered only while the event loop runs (`app%run()`),
!> on the GUI thread; intervals are approximate. A timer with an `owner`
!> window is destroyed with it. One without an owner lives until
!> `timer%destroy()` (or `app%cleanup()`). Destroying a timer stops it, and
!> can be done from its own handler.
module wx_timers

    use iso_c_binding
    use wx_c_core
    use wx_c_menus
    use wx_base
    use wx_events
    implicit none
    private

    !> A timer (bind `wxEVT_TIMER` to it).
    type, extends(wx_evt_handler), public :: wx_timer
    contains
        procedure :: start => wx_timer_start
        procedure :: stop => wx_timer_stop
        procedure :: is_running => wx_timer_is_running
        procedure :: get_interval => wx_timer_get_interval
        procedure :: destroy => wx_timer_destroy
    end type wx_timer

    !> Create a (stopped) timer, optionally owned by a window.
    interface wx_timer
        module procedure wx_timer_new
    end interface wx_timer

contains

    !> Create a stopped timer. With `owner` (any window), it is destroyed
    !> with that window.
    type(wx_timer) function wx_timer_new(owner, stat)
        class(wx_object), intent(in), optional :: owner
        integer, intent(out), optional :: stat
        integer(c_int64_t) :: o
        integer(c_int) :: status
        o = 0
        if (present(owner)) o = owner%h
        status = wxf_timer_create(o, wx_timer_new%h)
        if (status /= WX_OK) wx_timer_new%h = 0
        call wx_check(status, stat)
    end function wx_timer_new

    !> Start (or restart) the timer: fire every `milliseconds`, or only once
    !> if `one_shot` is true.
    subroutine wx_timer_start(self, milliseconds, one_shot, stat)
        class(wx_timer), intent(inout) :: self
        integer, intent(in) :: milliseconds
        logical, intent(in), optional :: one_shot
        integer, intent(out), optional :: stat
        logical :: once
        once = .false.
        if (present(one_shot)) once = one_shot
        call wx_check(wxf_timer_start(self%h, int(milliseconds, c_int), wx_int(once)), stat)
    end subroutine wx_timer_start

    !> Stop the timer (no effect if it is not running).
    subroutine wx_timer_stop(self, stat)
        class(wx_timer), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_timer_stop(self%h), stat)
    end subroutine wx_timer_stop

    !> True while the timer runs (a one-shot timer stops once it fired).
    logical function wx_timer_is_running(self, stat)
        class(wx_timer), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_timer_is_running(self%h, v), stat)
        wx_timer_is_running = wx_logical(v)
    end function wx_timer_is_running

    !> The interval in milliseconds (of the last `start`).
    integer function wx_timer_get_interval(self, stat)
        class(wx_timer), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_timer_get_interval(self%h, v), stat)
        wx_timer_get_interval = v
    end function wx_timer_get_interval

    !> Stop and destroy the timer; its bindings are released.
    subroutine wx_timer_destroy(self, stat)
        class(wx_timer), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_timer_destroy(self%h), stat)
    end subroutine wx_timer_destroy

end module wx_timers

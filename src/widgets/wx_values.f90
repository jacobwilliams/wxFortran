!> Controls for numbers: [[wx_slider]], [[wx_spin_ctrl]] (integer),
!> [[wx_spin_ctrl_double]] (real) and [[wx_gauge]] (progress bar).
!>
!> Changing the value from code (`set_value`) sends no event; the user's
!> changes send `wxEVT_SLIDER`, `wxEVT_SPINCTRL` or `wxEVT_SPINCTRLDOUBLE`
!> (`event%get_int()` / `event%get_double()` give the new value).
module wx_values

    use iso_c_binding
    use wx_c_controls
    use wx_base
    use wx_windows
    implicit none
    private

    !> A slider for an integer in a range (`wxEVT_SLIDER`).
    type, extends(wx_window), public :: wx_slider
    contains
        procedure :: set_value => wx_slider_set_value
        procedure :: get_value => wx_slider_get_value
        procedure :: set_range => wx_slider_set_range
        procedure :: get_range => wx_slider_get_range
        procedure :: emit_change => wx_slider_emit_change
    end type wx_slider

    !> Create a slider.
    interface wx_slider
        module procedure wx_slider_new
    end interface wx_slider

    !> A text field with up/down arrows for an integer (`wxEVT_SPINCTRL`).
    type, extends(wx_window), public :: wx_spin_ctrl
    contains
        procedure :: set_value => wx_spin_ctrl_set_value
        procedure :: get_value => wx_spin_ctrl_get_value
        procedure :: set_range => wx_spin_ctrl_set_range
        procedure :: emit_change => wx_spin_ctrl_emit_change
    end type wx_spin_ctrl

    !> Create an integer spin control.
    interface wx_spin_ctrl
        module procedure wx_spin_ctrl_new
    end interface wx_spin_ctrl

    !> A text field with up/down arrows for a real number (`wxEVT_SPINCTRLDOUBLE`).
    type, extends(wx_window), public :: wx_spin_ctrl_double
    contains
        procedure :: set_value => wx_spin_double_set_value
        procedure :: get_value => wx_spin_double_get_value
        procedure :: set_range => wx_spin_double_set_range
        procedure :: emit_change => wx_spin_double_emit_change
    end type wx_spin_ctrl_double

    !> Create a real-valued spin control.
    interface wx_spin_ctrl_double
        module procedure wx_spin_double_new
    end interface wx_spin_ctrl_double

    !> A progress bar showing a value in 0..range (no events).
    type, extends(wx_window), public :: wx_gauge
    contains
        procedure :: set_value => wx_gauge_set_value
        procedure :: get_value => wx_gauge_get_value
        procedure :: set_range => wx_gauge_set_range
        procedure :: get_range => wx_gauge_get_range
        procedure :: pulse => wx_gauge_pulse
    end type wx_gauge

    !> Create a gauge.
    interface wx_gauge
        module procedure wx_gauge_new
    end interface wx_gauge

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
    ! wx_slider

    !> Create a slider inside `parent` for `min`..`max` (default 0..100),
    !> starting at `value` (default `min`); `vertical`, and `labels` to show
    !> the min, max and current value.
    type(wx_slider) function wx_slider_new(parent, value, min, max, vertical, labels, stat) result(s)
        class(wx_window), intent(in) :: parent
        integer, intent(in), optional :: value, min, max
        logical, intent(in), optional :: vertical, labels
        integer, intent(out), optional :: stat
        integer(c_int) :: lo, hi, v, vert, lab
        lo = 0
        if (present(min)) lo = int(min, c_int)
        hi = 100
        if (present(max)) hi = int(max, c_int)
        v = lo
        if (present(value)) v = int(value, c_int)
        vert = 0
        if (present(vertical)) vert = wx_int(vertical)
        lab = 0
        if (present(labels)) lab = wx_int(labels)
        call created(wxf_slider_create(parent%h, v, lo, hi, vert, lab, s%h), s%h, stat)
    end function wx_slider_new

    !> Move the slider (clamped to its range), without an event.
    subroutine wx_slider_set_value(self, value, stat)
        class(wx_slider), intent(inout) :: self
        integer, intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_slider_set_value(self%h, int(value, c_int)), stat)
    end subroutine wx_slider_set_value

    !> The slider's value.
    integer function wx_slider_get_value(self, stat)
        class(wx_slider), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_slider_get_value(self%h, v), stat)
        wx_slider_get_value = v
    end function wx_slider_get_value

    !> Set the range `min`..`max`.
    subroutine wx_slider_set_range(self, min, max, stat)
        class(wx_slider), intent(inout) :: self
        integer, intent(in) :: min, max
        integer, intent(out), optional :: stat
        call wx_check(wxf_slider_set_range(self%h, int(min, c_int), int(max, c_int)), stat)
    end subroutine wx_slider_set_range

    !> The range `min`..`max`.
    subroutine wx_slider_get_range(self, min, max, stat)
        class(wx_slider), intent(in) :: self
        integer, intent(out) :: min, max
        integer, intent(out), optional :: stat
        integer(c_int) :: lo, hi
        lo = 0
        hi = 0
        call wx_check(wxf_slider_get_range(self%h, lo, hi), stat)
        min = lo
        max = hi
    end subroutine wx_slider_get_range

    !> Move the slider and send `wxEVT_SLIDER`, as dragging it would (for
    !> tests and automation).
    subroutine wx_slider_emit_change(self, value, stat)
        class(wx_slider), intent(inout) :: self
        integer, intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_slider_emit_change(self%h, int(value, c_int)), stat)
    end subroutine wx_slider_emit_change

    ! -------------------------------------------------------------------------
    ! wx_spin_ctrl

    !> Create an integer spin control inside `parent` for `min`..`max`
    !> (default 0..100), starting at `value` (default `min`).
    type(wx_spin_ctrl) function wx_spin_ctrl_new(parent, value, min, max, stat) result(s)
        class(wx_window), intent(in) :: parent
        integer, intent(in), optional :: value, min, max
        integer, intent(out), optional :: stat
        integer(c_int) :: lo, hi, v
        lo = 0
        if (present(min)) lo = int(min, c_int)
        hi = 100
        if (present(max)) hi = int(max, c_int)
        v = lo
        if (present(value)) v = int(value, c_int)
        call created(wxf_spin_ctrl_create(parent%h, v, lo, hi, s%h), s%h, stat)
    end function wx_spin_ctrl_new

    !> Set the value (clamped to the range), without an event.
    subroutine wx_spin_ctrl_set_value(self, value, stat)
        class(wx_spin_ctrl), intent(inout) :: self
        integer, intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_spin_ctrl_set_value(self%h, int(value, c_int)), stat)
    end subroutine wx_spin_ctrl_set_value

    !> The value.
    integer function wx_spin_ctrl_get_value(self, stat)
        class(wx_spin_ctrl), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_spin_ctrl_get_value(self%h, v), stat)
        wx_spin_ctrl_get_value = v
    end function wx_spin_ctrl_get_value

    !> Set the range `min`..`max`.
    subroutine wx_spin_ctrl_set_range(self, min, max, stat)
        class(wx_spin_ctrl), intent(inout) :: self
        integer, intent(in) :: min, max
        integer, intent(out), optional :: stat
        call wx_check(wxf_spin_ctrl_set_range(self%h, int(min, c_int), int(max, c_int)), stat)
    end subroutine wx_spin_ctrl_set_range

    !> Set the value and send `wxEVT_SPINCTRL`, as the arrows would.
    subroutine wx_spin_ctrl_emit_change(self, value, stat)
        class(wx_spin_ctrl), intent(inout) :: self
        integer, intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_spin_ctrl_emit_change(self%h, int(value, c_int)), stat)
    end subroutine wx_spin_ctrl_emit_change

    ! -------------------------------------------------------------------------
    ! wx_spin_ctrl_double

    !> Create a real spin control inside `parent` for `min`..`max` (default
    !> 0..1), starting at `value` (default `min`), changing by `increment`
    !> (default 0.1) per click and showing `digits` decimals (default 2).
    type(wx_spin_ctrl_double) function wx_spin_double_new(parent, value, min, max, increment, digits, stat) &
            result(s)
        class(wx_window), intent(in) :: parent
        real(c_double), intent(in), optional :: value, min, max, increment
        integer, intent(in), optional :: digits
        integer, intent(out), optional :: stat
        real(c_double) :: lo, hi, v, inc
        integer(c_int) :: d
        lo = 0
        if (present(min)) lo = min
        hi = 1
        if (present(max)) hi = max
        v = lo
        if (present(value)) v = value
        inc = 0.1_c_double
        if (present(increment)) inc = increment
        d = 2
        if (present(digits)) d = int(digits, c_int)
        call created(wxf_spin_double_create(parent%h, v, lo, hi, inc, d, s%h), s%h, stat)
    end function wx_spin_double_new

    !> Set the value (clamped to the range), without an event.
    subroutine wx_spin_double_set_value(self, value, stat)
        class(wx_spin_ctrl_double), intent(inout) :: self
        real(c_double), intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_spin_double_set_value(self%h, value), stat)
    end subroutine wx_spin_double_set_value

    !> The value.
    real(c_double) function wx_spin_double_get_value(self, stat)
        class(wx_spin_ctrl_double), intent(in) :: self
        integer, intent(out), optional :: stat
        real(c_double) :: v
        v = 0
        call wx_check(wxf_spin_double_get_value(self%h, v), stat)
        wx_spin_double_get_value = v
    end function wx_spin_double_get_value

    !> Set the range `min`..`max`.
    subroutine wx_spin_double_set_range(self, min, max, stat)
        class(wx_spin_ctrl_double), intent(inout) :: self
        real(c_double), intent(in) :: min, max
        integer, intent(out), optional :: stat
        call wx_check(wxf_spin_double_set_range(self%h, min, max), stat)
    end subroutine wx_spin_double_set_range

    !> Set the value and send `wxEVT_SPINCTRLDOUBLE`, as the arrows would.
    subroutine wx_spin_double_emit_change(self, value, stat)
        class(wx_spin_ctrl_double), intent(inout) :: self
        real(c_double), intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_spin_double_emit_change(self%h, value), stat)
    end subroutine wx_spin_double_emit_change

    ! -------------------------------------------------------------------------
    ! wx_gauge

    !> Create a progress bar inside `parent` for values 0..`range` (default 100).
    type(wx_gauge) function wx_gauge_new(parent, range, vertical, stat) result(g)
        class(wx_window), intent(in) :: parent
        integer, intent(in), optional :: range
        logical, intent(in), optional :: vertical
        integer, intent(out), optional :: stat
        integer(c_int) :: r, v
        r = 100
        if (present(range)) r = int(range, c_int)
        v = 0
        if (present(vertical)) v = wx_int(vertical)
        call created(wxf_gauge_create(parent%h, r, v, g%h), g%h, stat)
    end function wx_gauge_new

    !> Show `value` (0..range).
    subroutine wx_gauge_set_value(self, value, stat)
        class(wx_gauge), intent(inout) :: self
        integer, intent(in) :: value
        integer, intent(out), optional :: stat
        call wx_check(wxf_gauge_set_value(self%h, int(value, c_int)), stat)
    end subroutine wx_gauge_set_value

    !> The value shown.
    integer function wx_gauge_get_value(self, stat)
        class(wx_gauge), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_gauge_get_value(self%h, v), stat)
        wx_gauge_get_value = v
    end function wx_gauge_get_value

    !> Set the maximum value.
    subroutine wx_gauge_set_range(self, range, stat)
        class(wx_gauge), intent(inout) :: self
        integer, intent(in) :: range
        integer, intent(out), optional :: stat
        call wx_check(wxf_gauge_set_range(self%h, int(range, c_int)), stat)
    end subroutine wx_gauge_set_range

    !> The maximum value.
    integer function wx_gauge_get_range(self, stat)
        class(wx_gauge), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_gauge_get_range(self%h, v), stat)
        wx_gauge_get_range = v
    end function wx_gauge_get_range

    !> Switch to indeterminate mode and move the bar (call repeatedly, e.g.
    !> from a timer, while the length of the work is unknown).
    subroutine wx_gauge_pulse(self, stat)
        class(wx_gauge), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_gauge_pulse(self%h), stat)
    end subroutine wx_gauge_pulse

end module wx_values

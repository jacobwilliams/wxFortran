!> [[wx_canvas]]: a window drawn by Fortran.
!>
!> Bind `wxEVT_PAINT` to draw it (see [[wx_graphics_mod]]), mouse events
!> (`wxEVT_LEFT_DOWN`, `wxEVT_MOTION`, `wxEVT_MOUSEWHEEL`, ...) and
!> `wxEVT_KEY_DOWN` to interact. Call `refresh` to have it redrawn after your
!> data changes. Clicking a canvas gives it the keyboard focus.
module wx_canvas_mod

    use iso_c_binding
    use wx_c_graphics
    use wx_base
    use wx_windows
    implicit none
    private

    !> A window painted by its `wxEVT_PAINT` handlers (white background by default).
    type, extends(wx_window), public :: wx_canvas
    contains
        procedure :: save_png => wx_canvas_save_png
    end type wx_canvas

    !> Create a canvas.
    interface wx_canvas
        module procedure wx_canvas_new
    end interface wx_canvas

contains

    !> Create a canvas inside `parent`.
    type(wx_canvas) function wx_canvas_new(parent, stat) result(c)
        class(wx_window), intent(in) :: parent
        integer, intent(out), optional :: stat
        integer(c_int) :: status
        status = wxf_canvas_create(parent%h, c%h)
        if (status /= WX_OK) c%h = 0
        call wx_check(status, stat)
    end function wx_canvas_new

    !> Draw the canvas with its paint handlers into a PNG file of its current
    !> size (the window need not be shown).
    subroutine wx_canvas_save_png(self, filename, stat)
        class(wx_canvas), intent(inout) :: self
        character(len=*), intent(in) :: filename
        integer, intent(out), optional :: stat
        call wx_check(wxf_canvas_save_png(self%h, filename, len(filename, c_int)), stat)
    end subroutine wx_canvas_save_png

end module wx_canvas_mod

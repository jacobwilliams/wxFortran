!> Drawing tests: colors, offscreen PNG rendering read back pixel by pixel,
!> a canvas saved to PNG with its own paint handler, synthetic mouse and key
!> events, and the graphics context's lifetime. No user interaction needed.
module test_canvas_handlers

    use wx
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: wp = c_double

    !> What the drawing handlers record.
    type :: draw_state
        integer :: calls = 0
        real(wp) :: width = 0, height = 0
        real(wp) :: text_w = 0, text_h = 0
        type(wx_graphics) :: kept      !! copied out of a handler
        type(wx_color) :: fill = wx_color(255, 0, 0, 255)
    end type draw_state

    !> What the input handlers record.
    type :: input_state
        integer :: x = -1, y = -1, mods = -1, kind = 0
        real(wp) :: wheel = 0
        integer :: key = 0, unicode = 0
        integer :: stat_position = -1
        logical :: left_down = .false.
    end type input_state

contains

    !> Draw a filled rectangle, a polyline, a circle and text.
    subroutine draw_scene(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        select type (s => data)
        type is (draw_state)
            g = wx_graphics(event)
            s%calls = s%calls + 1
            s%width = g%width
            s%height = g%height
            call g%push_state()
            call g%set_no_pen()
            call g%set_brush(s%fill)
            call g%draw_rectangle(10.0_wp, 10.0_wp, 30.0_wp, 20.0_wp)
            call g%pop_state()
            call g%set_pen(wx_color(0, 128, 0), width=3.0_wp, style=wxPENSTYLE_SOLID)
            call g%stroke_lines([50.0_wp, 60.0_wp, 70.0_wp], [10.0_wp, 30.0_wp, 10.0_wp])
            call g%set_no_brush()
            call g%draw_circle(80.0_wp, 30.0_wp, 5.0_wp)
            call g%set_font(10.0_wp, wxBLACK, family=wxFONTFAMILY_SWISS, bold=.true.)
            call g%get_text_extent('Hello', s%text_w, s%text_h)
            call g%draw_text('Hello', 5.0_wp, 35.0_wp)
            s%kept = g
        end select
    end subroutine draw_scene

    !> Record a mouse or key event.
    subroutine on_input(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: x, y
        select type (s => data)
        type is (input_state)
            s%kind = event%kind()
            s%mods = event%get_modifiers()
            if (event%kind() == wxEVT_KEY_DOWN) then
                s%key = event%get_key_code()
                s%unicode = event%get_unicode_key()
                call event%get_position(x, y, stat=s%stat_position)
            else
                call event%get_position(s%x, s%y)
                s%left_down = event%left_is_down()
                if (event%kind() == wxEVT_MOUSEWHEEL) s%wheel = event%get_wheel_rotation()
            end if
        end select
    end subroutine on_input

    !> A button handler that tries to get a drawing context.
    subroutine not_paint(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        select type (s => data)
        type is (integer)
            g = wx_graphics(event, stat=s)
        end select
    end subroutine not_paint

    !> True if pixel (x, y) of `rgb` is within `tol` of color `c`.
    logical function near(rgb, x, y, c, tol)
        integer, intent(in) :: rgb(:,:,:), x, y
        type(wx_color), intent(in) :: c
        integer, intent(in) :: tol
        near = all(abs(rgb(:, x, y) - [c%r, c%g, c%b]) <= tol)
    end function near

end module test_canvas_handlers


!> Runs the drawing tests.
program test_canvas

    use wx
    use testing
    use test_canvas_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_canvas) :: canvas
    type(wx_button) :: button
    type(wx_color) :: c
    type(draw_state), target :: ds
    type(input_state), target :: is
    integer, target :: stat_paint
    integer, allocatable :: rgb(:,:,:)
    integer :: stat, w, h, base_handlers, base_objects, unit
    character(len=*), parameter :: png = 'test_canvas_offscreen.png', png2 = 'test_canvas_window.png'
    type(wx_color), parameter :: sky = wx_color(30, 60, 200, 255)

    app = wx_app()
    base_handlers = wx_active_handlers()
    base_objects = wx_live_objects()

    ! --- colors
    c = wx_color_hex('#1f77b4')
    call check(c%r == 31 .and. c%g == 119 .and. c%b == 180 .and. c%a == 255, 'hex color #rrggbb')
    c = wx_color_hex('FF000080')
    call check(c%r == 255 .and. c%g == 0 .and. c%a == 128, 'hex color rrggbbaa without #')
    c = wx_color_hex('#12345', stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'bad hex color fails with WX_ERR_ARGUMENT')
    call check(index(wx_last_error(), '#12345') > 0, 'error names the bad color')

    ! --- offscreen rendering, read back
    call wx_render_png(png, 100, 50, draw_scene, data=ds, background=sky)
    call check(ds%calls == 1, 'offscreen draw handler called once')
    call check(ds%width == 100 .and. ds%height == 50, 'drawing area size passed to the handler')
    call check(ds%text_w > 10 .and. ds%text_h > 5, 'text extent measured')
    call wx_image_read_rgb(png, rgb)
    call check(size(rgb, 2) == 100 .and. size(rgb, 3) == 50, 'PNG has the requested size')
    call check(near(rgb, 25, 20, wxRED, 0), 'filled rectangle is red inside')
    call check(near(rgb, 3, 3, sky, 0), 'background color outside the shapes')
    call check(near(rgb, 60, 29, wx_color(0, 128, 0), 40), 'polyline drawn in green')
    call check(near(rgb, 80, 30, sky, 0), 'circle not filled (no brush)')
    call check(count(rgb(1, 1:40, 36:49) < 80 .and. rgb(3, 1:40, 36:49) < 80) > 5, 'text drawn in black')

    ! --- the context is borrowed: unusable after its handler
    call ds%kept%stroke_line(0.0_wp, 0.0_wp, 1.0_wp, 1.0_wp, stat=stat)
    call check(stat == WX_ERR_STATE, 'graphics used after its handler fails with WX_ERR_STATE')

    ! --- errors
    call wx_render_png(png, 0, 10, draw_scene, data=ds, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'zero-size image rejected')
    call wx_render_png('/nonexistent-dir/x.png', 10, 10, draw_scene, data=ds, stat=stat)
    call check(stat == WX_ERR_FAILED, 'unwritable PNG path fails with WX_ERR_FAILED')
    call wx_image_read_rgb('/nonexistent-dir/x.png', rgb, stat=stat)
    call check(stat == WX_ERR_FAILED .and. size(rgb) == 0, 'reading a missing image fails cleanly')

    ! --- a canvas in a frame, saved with its own paint handler
    frame = wx_frame('canvas', width=300, height=200)
    canvas = wx_canvas(frame)
    call canvas%set_size(120, 80)
    call canvas%set_background_color(wx_color(240, 240, 240))
    ds = draw_state(fill=wx_color(0, 0, 255, 255))
    call canvas%bind(wxEVT_PAINT, draw_scene, data=ds)
    call canvas%save_png(png2)
    call canvas%get_client_size(w, h)
    call wx_image_read_rgb(png2, rgb)
    call check(ds%calls == 1, 'canvas paint handler used for save_png')
    call check(size(rgb, 2) == w .and. size(rgb, 3) == h, 'saved canvas has its client size')
    call check(near(rgb, 25, 20, wxBLUE, 0), 'canvas drawing saved')
    call check(near(rgb, 110, 70, wx_color(240, 240, 240), 0), 'canvas background color saved')
    call canvas%refresh()

    ! paint events only make sense for canvases
    button = wx_button(frame, 'b')
    call button%bind(wxEVT_PAINT, draw_scene, data=ds, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'paint handlers only on a wx_canvas')
    stat_paint = -1
    call button%bind(wxEVT_BUTTON, not_paint, data=stat_paint)
    call button%emit_click()
    call check(stat_paint == WX_ERR_ARGUMENT, 'wx_graphics(event) of a non-paint event fails')

    ! --- synthetic mouse and key input
    call canvas%bind(wxEVT_LEFT_DOWN, on_input, data=is)
    call canvas%bind(wxEVT_MOTION, on_input, data=is)
    call canvas%bind(wxEVT_MOUSEWHEEL, on_input, data=is)
    call canvas%bind(wxEVT_KEY_DOWN, on_input, data=is)
    call canvas%emit_mouse(wxEVT_LEFT_DOWN, 12, 34, modifiers=WX_MOD_SHIFT)
    call check(is%kind == wxEVT_LEFT_DOWN .and. is%x == 12 .and. is%y == 34, 'left-down position')
    call check(is%mods == WX_MOD_SHIFT .and. is%left_down, 'left-down modifiers and button state')
    call canvas%emit_mouse(wxEVT_MOTION, 50, 60)
    call check(is%kind == wxEVT_MOTION .and. is%x == 50 .and. is%mods == 0, 'motion')
    call canvas%emit_mouse(wxEVT_MOUSEWHEEL, 5, 5, wheel=-2.0_wp)
    call check(is%kind == wxEVT_MOUSEWHEEL .and. abs(is%wheel + 2) < 1e-9_wp, 'wheel rotation in notches')
    call canvas%emit_key(iachar('A'), modifiers=ior(WX_MOD_CONTROL, WX_MOD_ALT))
    call check(is%key == iachar('A') .and. is%unicode == iachar('A'), 'key code and character')
    call check(is%mods == ior(WX_MOD_CONTROL, WX_MOD_ALT), 'key modifiers')
    call check(is%stat_position == WX_ERR_ARGUMENT, 'mouse accessor on a key event fails')
    call canvas%emit_key(WXK_LEFT)
    call check(is%key == WXK_LEFT .and. is%unicode == 0, 'special key code')
    call canvas%emit_mouse(wxEVT_KEY_DOWN, 0, 0, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'emit_mouse rejects non-mouse kinds')

    ! --- teardown
    call frame%destroy()
    call app%process_pending()
    call check(.not. canvas%is_valid(), 'canvas destroyed with its frame')
    call check(wx_active_handlers() == base_handlers, 'canvas handlers released')
    call check(wx_live_objects() == base_objects, 'no live objects left')

    open(newunit=unit, file=png, status='old')
    close(unit, status='delete')
    open(newunit=unit, file=png2, status='old')
    close(unit, status='delete')

end program test_canvas

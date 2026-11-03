!> A live, scrolling plot of two signals drawn with wx_graphics on a wx_canvas.
!>
!> * Left click: drop a marker (it stays at its data point as time scrolls).
!> * Left drag: pan vertically. Double-click or R: reset the view.
!> * Wheel: zoom the value axis around the cursor; Shift+wheel: zoom time.
!> * Space (or View > Pause): pause. C: clear markers.
!> * File > Save image (Ctrl+S): choose a PNG file to save. The status bar shows the
!>   data coordinates under the cursor.
!>
!> `plot --screenshot out.png` fills the plot, saves it to out.png and exits.
module plot_ui

    use wx
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: wp = c_double
    real(wp), parameter :: pi = acos(-1.0_wp)
    real(wp), parameter :: dt = 0.03_wp            !! simulation step and timer period, s
    integer, parameter :: n_max = 4000             !! samples kept (2 minutes)
    integer, parameter :: max_markers = 50
    ! plot area margins, pixels
    real(wp), parameter :: m_left = 64, m_right = 20, m_top = 36, m_bottom = 48

    type(wx_color), parameter :: c_series1 = wx_color(31, 119, 180, 255)    ! blue
    type(wx_color), parameter :: c_series2 = wx_color(255, 127, 14, 255)    ! orange
    type(wx_color), parameter :: c_marker = wx_color(214, 39, 40, 255)      ! red
    type(wx_color), parameter :: c_grid = wx_color(220, 220, 220, 255)
    type(wx_color), parameter :: c_axis = wx_color(90, 90, 90, 255)
    type(wx_color), parameter :: c_area = wx_color(252, 252, 252, 255)

    !> The plot: data, view and widgets.
    type :: plot_t
        type(wx_frame) :: frame
        type(wx_canvas) :: canvas
        type(wx_timer) :: timer
        type(wx_menu) :: view_menu
        integer :: id_pause = 0, id_reset = 0, id_clear = 0
        ! data
        integer :: n = 0
        real(wp) :: t(n_max) = 0, y1(n_max) = 0, y2(n_max) = 0
        real(wp) :: now = 0
        ! view
        real(wp) :: window = 10        !! visible time span, s
        real(wp) :: ymin = -2.5, ymax = 2.5
        logical :: paused = .false.
        ! markers, in data coordinates
        integer :: n_markers = 0
        real(wp) :: mt(max_markers) = 0, my(max_markers) = 0
        ! canvas size at the last paint, and drag state
        real(wp) :: width = 1, height = 1
        integer :: down_x = 0, down_y = 0, last_y = 0
        logical :: dragged = .false.
        character(len=:), allocatable :: screenshot
    end type plot_t

contains

    ! ------------------------------------------------------------ data

    !> Advance the simulation by one step and record the sample.
    subroutine step(p)
        type(plot_t), intent(inout) :: p
        real(wp) :: noise(2)
        call random_number(noise)
        noise = noise - 0.5_wp
        p%now = p%now + dt
        if (p%n == n_max) then
            p%t(1:n_max-1) = p%t(2:n_max)
            p%y1(1:n_max-1) = p%y1(2:n_max)
            p%y2(1:n_max-1) = p%y2(2:n_max)
        else
            p%n = p%n + 1
        end if
        p%t(p%n) = p%now
        p%y1(p%n) = sin(2*pi*0.5_wp*p%now) + 0.3_wp*sin(2*pi*2.1_wp*p%now) + 0.15_wp*noise(1)
        p%y2(p%n) = 1.3_wp*sin(2*pi*0.11_wp*p%now + 1) * cos(2*pi*0.04_wp*p%now) + 0.1_wp*noise(2)
    end subroutine step

    !> Visible time range.
    pure subroutine time_range(p, t0, t1)
        type(plot_t), intent(in) :: p
        real(wp), intent(out) :: t0, t1
        t1 = max(p%now, p%window)
        t0 = t1 - p%window
    end subroutine time_range

    !> Data to pixel coordinates.
    pure subroutine to_pixel(p, t0, t1, t, y, px, py)
        type(plot_t), intent(in) :: p
        real(wp), intent(in) :: t0, t1, t, y
        real(wp), intent(out) :: px, py
        px = m_left + (t - t0) / (t1 - t0) * plot_w(p)
        py = m_top + (1 - (y - p%ymin) / (p%ymax - p%ymin)) * plot_h(p)
    end subroutine to_pixel

    !> Pixel to data coordinates.
    pure subroutine to_data(p, px, py, t, y)
        type(plot_t), intent(in) :: p
        real(wp), intent(in) :: px, py
        real(wp), intent(out) :: t, y
        real(wp) :: t0, t1
        call time_range(p, t0, t1)
        t = t0 + (px - m_left) / plot_w(p) * (t1 - t0)
        y = p%ymin + (1 - (py - m_top) / plot_h(p)) * (p%ymax - p%ymin)
    end subroutine to_data

    !> Width of the plot area.
    pure real(wp) function plot_w(p)
        type(plot_t), intent(in) :: p
        plot_w = max(p%width - m_left - m_right, 10.0_wp)
    end function plot_w

    !> Height of the plot area.
    pure real(wp) function plot_h(p)
        type(plot_t), intent(in) :: p
        plot_h = max(p%height - m_top - m_bottom, 10.0_wp)
    end function plot_h

    !> True if pixel (x, y) is inside the plot area.
    pure logical function in_plot(p, x, y)
        type(plot_t), intent(in) :: p
        integer, intent(in) :: x, y
        in_plot = x >= m_left .and. x <= m_left + plot_w(p) .and. y >= m_top .and. y <= m_top + plot_h(p)
    end function in_plot

    !> A "nice" tick spacing (1, 2 or 5 times a power of ten) giving about
    !> `target` intervals over `span`.
    pure real(wp) function nice_step(span, target)
        real(wp), intent(in) :: span
        integer, intent(in) :: target
        real(wp) :: raw, mag, f
        raw = span / target
        mag = 10.0_wp**floor(log10(raw))
        f = raw / mag
        if (f < 1.5_wp) then
            nice_step = mag
        else if (f < 3.5_wp) then
            nice_step = 2*mag
        else if (f < 7.5_wp) then
            nice_step = 5*mag
        else
            nice_step = 10*mag
        end if
    end function nice_step

    !> `x` formatted with enough decimals for tick spacing `step`.
    function fmt(x, step) result(s)
        real(wp), intent(in) :: x, step
        character(len=:), allocatable :: s
        character(len=32) :: buf, f
        integer :: d
        d = max(0, -floor(log10(step) + 1.0e-9_wp))
        write(f, '(A,I0,A)') '(F0.', d, ')'
        write(buf, f) x
        s = trim(adjustl(buf))
        if (s(1:1) == '.') s = '0'//s
        if (len(s) > 1) then
            if (s(1:2) == '-.') s = '-0'//s(2:)
        end if
        if (s == '-0' .or. s == '-0.0' .or. s == '-0.00') s = s(2:)
        if (s(len(s):len(s)) == '.') s = s(1:len(s)-1)
    end function fmt

    ! ------------------------------------------------------------ drawing

    !> Paint the whole plot.
    subroutine on_paint(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        real(wp) :: t0, t1, step_t, step_y, v, px, py, w, h, x0, y0, pw, ph
        real(wp), allocatable :: xs(:), ys(:)
        integer :: i, first
        select type (p => data)
        type is (plot_t)
            g = wx_graphics(event)
            p%width = g%width
            p%height = g%height
            call time_range(p, t0, t1)
            x0 = m_left
            y0 = m_top
            pw = plot_w(p)
            ph = plot_h(p)

            ! title
            call g%set_font(13.0_wp, wx_color(40, 40, 40), bold=.true.)
            call g%draw_text('Live signals', x0, 8.0_wp)

            ! plot area
            call g%set_pen(c_grid)
            call g%set_brush(c_area)
            call g%draw_rectangle(x0, y0, pw, ph)

            ! grid and tick labels
            call g%set_font(9.0_wp, c_axis)
            step_t = nice_step(t1 - t0, 8)
            v = ceiling(t0 / step_t) * step_t
            do while (v <= t1 + 1.0e-9_wp)
                call to_pixel(p, t0, t1, v, p%ymin, px, py)
                call g%set_pen(c_grid, style=wxPENSTYLE_SHORT_DASH)
                call g%stroke_line(px, y0, px, y0 + ph)
                call g%set_pen(c_axis)
                call g%stroke_line(px, y0 + ph, px, y0 + ph + 4)
                call g%get_text_extent(fmt(v, step_t), w, h)
                call g%draw_text(fmt(v, step_t), px - w/2, y0 + ph + 6)
                v = v + step_t
            end do
            step_y = nice_step(p%ymax - p%ymin, 6)
            v = ceiling(p%ymin / step_y) * step_y
            do while (v <= p%ymax + 1.0e-9_wp)
                call to_pixel(p, t0, t1, t0, v, px, py)
                call g%set_pen(c_grid, style=wxPENSTYLE_SHORT_DASH)
                call g%stroke_line(x0, py, x0 + pw, py)
                call g%set_pen(c_axis)
                call g%stroke_line(x0 - 4, py, x0, py)
                call g%get_text_extent(fmt(v, step_y), w, h)
                call g%draw_text(fmt(v, step_y), x0 - 7 - w, py - h/2)
                v = v + step_y
            end do

            ! axes box and titles
            call g%set_pen(c_axis)
            call g%set_no_brush()
            call g%draw_rectangle(x0, y0, pw, ph)
            call g%set_font(10.0_wp, c_axis)
            call g%get_text_extent('time (s)', w, h)
            call g%draw_text('time (s)', x0 + pw/2 - w/2, y0 + ph + 26)
            call g%get_text_extent('signal', w, h)
            call g%draw_text('signal', 12.0_wp, y0 + ph/2 + w/2, angle=pi/2)

            ! series and markers, clipped to the plot area
            call g%push_state()
            call g%clip(x0, y0, pw, ph)
            first = 1
            do while (first < p%n)
                if (p%t(first + 1) >= t0) exit
                first = first + 1
            end do
            if (p%n - first >= 1) then
                allocate(xs(p%n - first + 1), ys(p%n - first + 1))
                xs = m_left + (p%t(first:p%n) - t0) / (t1 - t0) * pw
                ys = m_top + (1 - (p%y1(first:p%n) - p%ymin) / (p%ymax - p%ymin)) * ph
                call g%set_pen(c_series1, width=2.0_wp)
                call g%stroke_lines(xs, ys)
                ys = m_top + (1 - (p%y2(first:p%n) - p%ymin) / (p%ymax - p%ymin)) * ph
                call g%set_pen(c_series2, width=2.0_wp)
                call g%stroke_lines(xs, ys)
            end if
            call g%set_font(8.0_wp, c_marker)
            do i = 1, p%n_markers
                call to_pixel(p, t0, t1, p%mt(i), p%my(i), px, py)
                call g%set_pen(wxWHITE, width=1.5_wp)
                call g%set_brush(c_marker)
                call g%draw_circle(px, py, 4.5_wp)
                call g%draw_text('('//fmt(p%mt(i), 0.01_wp)//', '//fmt(p%my(i), 0.01_wp)//')', px + 7, py - 14)
            end do
            if (p%paused) then
                call g%set_font(11.0_wp, wx_color(150, 150, 150), bold=.true.)
                call g%draw_text('PAUSED', x0 + 8, y0 + 6)
            end if
            call g%pop_state()

            call draw_legend(g, x0 + pw - 120, y0 + 8)
        end select
    end subroutine on_paint

    !> The legend box at (x, y).
    subroutine draw_legend(g, x, y)
        type(wx_graphics), intent(inout) :: g
        real(wp), intent(in) :: x, y
        call g%set_pen(c_grid)
        call g%set_brush(wx_color(255, 255, 255, 220))
        call g%draw_rectangle(x, y, 112.0_wp, 46.0_wp, radius=4.0_wp)
        call g%set_font(9.0_wp, c_axis)
        call g%set_pen(c_series1, width=2.0_wp)
        call g%stroke_line(x + 8, y + 14, x + 30, y + 14)
        call g%draw_text('fast wave', x + 36, y + 7)
        call g%set_pen(c_series2, width=2.0_wp)
        call g%stroke_line(x + 8, y + 32, x + 30, y + 32)
        call g%draw_text('slow beat', x + 36, y + 25)
    end subroutine draw_legend

    ! ------------------------------------------------------------ input

    !> Timer: add a sample and redraw (unless paused).
    subroutine on_tick(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (p => data)
        type is (plot_t)
            if (.not. p%paused) then
                call step(p)
                call p%canvas%refresh()
            end if
        end select
    end subroutine on_tick

    !> Pause or resume (keeps the menu check item in sync).
    subroutine toggle_pause(p)
        type(plot_t), intent(inout) :: p
        p%paused = .not. p%paused
        call p%view_menu%check(p%id_pause, p%paused)
        call p%frame%set_status_text(merge('Paused ', 'Running', p%paused))
        call p%canvas%refresh()
    end subroutine toggle_pause

    !> Reset zoom and pan.
    subroutine reset_view(p)
        type(plot_t), intent(inout) :: p
        p%ymin = -2.5_wp
        p%ymax = 2.5_wp
        p%window = 10
        call p%frame%set_status_text('View reset')
        call p%canvas%refresh()
    end subroutine reset_view

    !> Remove all markers.
    subroutine clear_markers(p)
        type(plot_t), intent(inout) :: p
        p%n_markers = 0
        call p%frame%set_status_text('Markers cleared')
        call p%canvas%refresh()
    end subroutine clear_markers

    !> Save the plot as a PNG file.
    subroutine save_image(p, filename)
        type(plot_t), intent(inout) :: p
        character(len=*), intent(in) :: filename
        integer :: stat
        call p%canvas%save_png(filename, stat=stat)
        if (stat == WX_OK) then
            call p%frame%set_status_text('Saved '//filename)
        else
            call p%frame%set_status_text('Could not save: '//wx_last_error())
        end if
    end subroutine save_image

    !> Mouse: markers, panning, zooming and the cursor readout.
    subroutine on_mouse(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: x, y
        real(wp) :: t, v, f, yc, span
        select type (p => data)
        type is (plot_t)
            select case (event%kind())
            case (wxEVT_LEAVE_WINDOW)
                call p%frame%set_status_text('', field=1)
                return
            case (wxEVT_LEFT_DCLICK)
                call reset_view(p)
                return
            end select
            call event%get_position(x, y)
            call to_data(p, real(x, wp), real(y, wp), t, v)
            select case (event%kind())
            case (wxEVT_LEFT_DOWN)
                p%down_x = x
                p%down_y = y
                p%last_y = y
                p%dragged = .false.
            case (wxEVT_LEFT_UP)
                if (.not. p%dragged .and. in_plot(p, x, y) .and. p%n_markers < max_markers) then
                    p%n_markers = p%n_markers + 1
                    p%mt(p%n_markers) = t
                    p%my(p%n_markers) = v
                    call p%frame%set_status_text('Marker at t = '//fmt(t, 0.01_wp)//', y = '//fmt(v, 0.01_wp))
                    call p%canvas%refresh()
                end if
            case (wxEVT_MOTION)
                if (in_plot(p, x, y)) then
                    call p%frame%set_status_text('t = '//fmt(t, 0.01_wp)//'   y = '//fmt(v, 0.01_wp), field=1)
                else
                    call p%frame%set_status_text('', field=1)
                end if
                if (event%left_is_down()) then
                    if (abs(y - p%down_y) + abs(x - p%down_x) > 3) p%dragged = .true.
                    if (p%dragged) then
                        span = (p%ymax - p%ymin) * (y - p%last_y) / plot_h(p)
                        p%ymin = p%ymin + span
                        p%ymax = p%ymax + span
                        p%last_y = y
                        call p%canvas%refresh()
                    end if
                end if
            case (wxEVT_MOUSEWHEEL)
                f = 1.15_wp**(-event%get_wheel_rotation())
                if (iand(event%get_modifiers(), WX_MOD_SHIFT) /= 0) then
                    p%window = min(max(p%window * f, 1.0_wp), 120.0_wp)
                    call p%frame%set_status_text('Time window: '//fmt(p%window, 0.1_wp)//' s')
                else
                    yc = v
                    p%ymin = yc + (p%ymin - yc) * f
                    p%ymax = yc + (p%ymax - yc) * f
                end if
                call p%canvas%refresh()
            end select
        end select
    end subroutine on_mouse

    !> Keys: Space pauses, C clears markers, R resets the view.
    subroutine on_key(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (p => data)
        type is (plot_t)
            select case (event%get_key_code())
            case (WXK_SPACE)
                call toggle_pause(p)
            case (iachar('C'))
                call clear_markers(p)
            case (iachar('R'))
                call reset_view(p)
            case default
                call event%skip()   ! not ours: let it through (e.g. menu shortcuts)
            end select
        end select
    end subroutine on_key

    !> View > Pause.
    subroutine on_menu_pause(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (p => data)
        type is (plot_t)
            call toggle_pause(p)
        end select
    end subroutine on_menu_pause

    !> Other menu items, by id.
    subroutine on_menu(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        logical :: closed
        character(len=:), allocatable :: path
        select type (p => data)
        type is (plot_t)
            select case (event%get_id())
            case (wxID_SAVE)
                if (wx_file_save_dialog(path, message='Save the plot', default_file='plot.png', &
                                        wildcard='PNG images (*.png)|*.png', parent=p%frame)) then
                    if (len(path) < 4) then
                        path = path//'.png'
                    else if (path(len(path)-3:) /= '.png' .and. path(len(path)-3:) /= '.PNG') then
                        path = path//'.png'
                    end if
                    call save_image(p, path)
                end if
            case (wxID_EXIT)
                closed = p%frame%close()
            case default
                if (event%get_id() == p%id_reset) call reset_view(p)
                if (event%get_id() == p%id_clear) call clear_markers(p)
            end select
        end select
    end subroutine on_menu

    !> --screenshot: save the plot and quit (runs from the event loop).
    subroutine take_screenshot(data)
        class(*), intent(inout), optional :: data
        logical :: closed
        select type (p => data)
        type is (plot_t)
            call save_image(p, p%screenshot)
            write(*, '(A)') 'plot: saved '//p%screenshot
            closed = p%frame%close()
        end select
    end subroutine take_screenshot

end module plot_ui


!> Builds the plot window and runs it.
program plot

    use wx
    use plot_ui
    implicit none

    type(wx_app) :: app
    type(plot_t), target :: p
    type(wx_menu_bar) :: bar
    type(wx_menu) :: file_menu
    type(wx_box_sizer) :: sizer
    integer :: id, i, n
    character(len=512) :: arg

    app = wx_app()

    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg, n)
        p%screenshot = 'plot.png'
        if (n > 0) p%screenshot = trim(arg)
    end if

    p%frame = wx_frame('wxFortran plot', width=900, height=560)
    p%canvas = wx_canvas(p%frame)
    sizer = wx_box_sizer(wxVERTICAL)
    call sizer%add(p%canvas, proportion=1, flags=wxEXPAND)
    call p%frame%set_sizer(sizer)

    ! menus
    bar = wx_menu_bar()
    file_menu = wx_menu()
    id = file_menu%append(id=wxID_SAVE, text='&Save image'//achar(9)//'Ctrl+S', help='Save the plot as a PNG image')
    call file_menu%append_separator()
    id = file_menu%append(id=wxID_EXIT)
    p%view_menu = wx_menu()
    p%id_pause = p%view_menu%append('Pause (Space)', kind=wxITEM_CHECK, help='Stop or resume the signals')
    p%id_reset = p%view_menu%append('Reset view (R)', help='Default zoom and pan (also: double-click)')
    p%id_clear = p%view_menu%append('Clear markers (C)', help='Remove all markers')
    call bar%append(file_menu, '&File')
    call bar%append(p%view_menu, '&View')
    call p%frame%set_menu_bar(bar)
    call p%frame%bind(wxEVT_MENU, on_menu_pause, data=p, id=p%id_pause)
    call p%frame%bind(wxEVT_MENU, on_menu, data=p)
    call p%frame%create_status_bar(2)
    call p%frame%set_status_text('Click: marker   drag: pan   wheel: zoom (Shift: time)   Space: pause')

    ! drawing and input
    call p%canvas%bind(wxEVT_PAINT, on_paint, data=p)
    call p%canvas%bind(wxEVT_LEFT_DOWN, on_mouse, data=p)
    call p%canvas%bind(wxEVT_LEFT_UP, on_mouse, data=p)
    call p%canvas%bind(wxEVT_LEFT_DCLICK, on_mouse, data=p)
    call p%canvas%bind(wxEVT_MOTION, on_mouse, data=p)
    call p%canvas%bind(wxEVT_MOUSEWHEEL, on_mouse, data=p)
    call p%canvas%bind(wxEVT_LEAVE_WINDOW, on_mouse, data=p)
    call p%canvas%bind(wxEVT_KEY_DOWN, on_key, data=p)

    p%timer = wx_timer(owner=p%frame)
    call p%timer%bind(wxEVT_TIMER, on_tick, data=p)

    if (allocated(p%screenshot)) then
        ! a deterministic-looking picture: 12 s of data and two markers
        do i = 1, 400
            call step(p)
        end do
        p%n_markers = 2
        p%mt(1:2) = [p%t(200), p%t(330)]
        p%my(1:2) = [p%y1(200), p%y2(330)]
        call wx_call_after(take_screenshot, p)
    else
        call p%timer%start(nint(dt * 1000))
    end if

    call p%frame%center()
    call p%frame%show()
    call p%canvas%set_focus()

    stop app%run()

end program plot

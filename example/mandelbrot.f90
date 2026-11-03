!> An interactive Mandelbrot set explorer, computed in Fortran with OpenMP.
!>
!> * Drag a box over the image to zoom into it (the box keeps the window's
!>   proportions); click to zoom in 2x around a point; right-click to zoom
!>   out; the wheel zooms around the cursor. Escape cancels a drag.
!> * Back (Backspace), Zoom out (-) and Reset (R) are in the View menu and
!>   on the toolbar; File > Save image writes the full-resolution PNG.
!> * Settings: colormap, smooth coloring, inverted colors, iterations, color
!>   density, 2x2 supersampling, OpenMP threads, and preset locations.
!>
!> The image is computed at the screen's full resolution (2x on high-DPI
!> screens). While a new one is computed, the old image is shown stretched
!> to the new view.
!>
!> Build with OpenMP (wxFortran's fpm.toml depends on the `openmp`
!> metapackage); without it the same code runs on one thread.
!>
!> `mandelbrot --screenshot out.png [--preset k]` renders the default view
!> (or preset location k) and exits. `--preset k` also works interactively.
module mandelbrot_ui

    use wx
    use iso_c_binding, only: c_double
    use iso_fortran_env, only: int64
!$  use omp_lib
    implicit none

    integer, parameter :: wp = c_double
    integer, parameter :: max_history = 200
    real(wp), parameter :: min_width = 1.0e-13_wp     !! double precision limit
    real(wp), parameter :: escape_radius = 256         !! large: smooth coloring is accurate

    integer, parameter :: n_maps = 6
    character(len=10), parameter :: map_names(n_maps) = &
        [character(len=10) :: 'Classic', 'Fire', 'Ocean', 'Grayscale', 'Rainbow', 'Twilight']

    !> A preset location.
    type :: preset_t
        character(len=24) :: name
        real(wp) :: cx, cy, width
        integer :: iterations
    end type preset_t

    type(preset_t), parameter :: presets(6) = [ &
        preset_t('Full set',          -0.65_wp,               0.0_wp,               3.2_wp,     500), &
        preset_t('Seahorse valley',   -0.7453_wp,             0.1127_wp,            0.012_wp,   800), &
        preset_t('Elephant valley',    0.2925_wp,             0.0155_wp,            0.02_wp,    800), &
        preset_t('Spirals',           -0.0880_wp,             0.6540_wp,            0.02_wp,    1000), &
        preset_t('Mini Mandelbrot',   -1.7549_wp,             0.0_wp,               0.04_wp,    800), &
        preset_t('Deep zoom',         -0.743643887037151_wp,  0.131825904205330_wp, 2.0e-9_wp,  4000)]

    !> A view: the center of the image and the width of the real axis shown.
    type :: view_t
        real(wp) :: cx = -0.65_wp, cy = 0, width = 3.2_wp
    end type view_t

    !> The explorer's widgets and state.
    type :: app_t
        type(wx_app) :: app
        type(wx_frame) :: frame
        type(wx_canvas) :: canvas
        type(wx_tool_bar) :: tools
        type(wx_choice) :: colormap, preset
        type(wx_check_box) :: smooth, invert, supersample
        type(wx_spin_ctrl) :: iterations, threads
        type(wx_spin_ctrl_double) :: density
        type(wx_static_text) :: info
        type(wx_timer) :: redraw          !! one-shot: coalesces recompute requests
        type(wx_bitmap) :: image          !! the last computed image
        type(view_t) :: view              !! what the user asked to see
        type(view_t) :: image_view        !! what `image` shows
        integer :: image_w = 0, image_h = 0   !! logical size the image was computed for
        type(view_t) :: history(max_history)
        integer :: n_history = 0
        ! drag state (canvas pixels)
        logical :: dragging = .false.
        integer :: x0 = 0, y0 = 0, x1 = 0, y1 = 0
        integer :: id_back = 0, id_zoom_out = 0, id_reset = 0
        character(len=:), allocatable :: screenshot
        character(len=:), allocatable :: timing   !! of the last image
    end type app_t

contains

    ! ------------------------------------------------------------------ math

    !> Smooth escape count of c (`< 0`: inside the set), or the plain count
    !> if not `smooth`.
    pure real(wp) function escape(cr, ci, max_iter, smooth) result(mu)
        real(wp), intent(in) :: cr, ci
        integer, intent(in) :: max_iter
        logical, intent(in) :: smooth
        real(wp) :: zr, zi, zr2, zi2, q
        integer :: k
        ! inside the main cardioid or the period-2 bulb: no need to iterate
        q = (cr - 0.25_wp)**2 + ci**2
        if (q*(q + (cr - 0.25_wp)) <= 0.25_wp*ci**2 .or. (cr + 1)**2 + ci**2 <= 0.0625_wp) then
            mu = -1
            return
        end if
        zr = 0
        zi = 0
        zr2 = 0
        zi2 = 0
        do k = 1, max_iter
            zi = 2*zr*zi + ci
            zr = zr2 - zi2 + cr
            zr2 = zr*zr
            zi2 = zi*zi
            if (zr2 + zi2 > escape_radius**2) then
                if (smooth) then
                    mu = k + 1 - log(log(sqrt(zr2 + zi2))) / log(2.0_wp)
                else
                    mu = k
                end if
                return
            end if
        end do
        mu = -1
    end function escape

    !> Color (0-255) of the colormap `map` at t in [0, 1).
    pure function colormap(map, t) result(rgb)
        integer, intent(in) :: map
        real(wp), intent(in) :: t
        integer :: rgb(3)
        select case (map)
        case (1)   ! classic: blue, white, gold
            rgb = gradient(t, [0.0_wp, 0.16_wp, 0.42_wp, 0.6425_wp, 0.8575_wp, 1.0_wp], &
                           reshape([0, 7, 100,  32, 107, 203,  237, 255, 255,  255, 170, 0,  0, 2, 0,  0, 7, 100], [3, 6]))
        case (2)   ! fire
            rgb = gradient(t, [0.0_wp, 0.25_wp, 0.5_wp, 0.75_wp, 0.9_wp, 1.0_wp], &
                           reshape([0, 0, 0,  128, 0, 0,  255, 80, 0,  255, 220, 60,  255, 255, 220,  0, 0, 0], [3, 6]))
        case (3)   ! ocean
            rgb = gradient(t, [0.0_wp, 0.3_wp, 0.6_wp, 0.8_wp, 1.0_wp], &
                           reshape([0, 0, 30,  0, 60, 130,  0, 170, 200,  200, 255, 255,  0, 0, 30], [3, 5]))
        case (4)   ! grayscale
            rgb = gradient(t, [0.0_wp, 0.5_wp, 1.0_wp], reshape([0, 0, 0,  255, 255, 255,  0, 0, 0], [3, 3]))
        case (5)   ! rainbow (hue)
            rgb = hue(t)
        case default   ! twilight
            rgb = gradient(t, [0.0_wp, 0.25_wp, 0.5_wp, 0.75_wp, 1.0_wp], &
                           reshape([30, 20, 60,  120, 60, 160,  240, 200, 220,  200, 120, 60,  30, 20, 60], [3, 5]))
        end select
    end function colormap

    !> Piecewise-linear color gradient through `colors(:, k)` at `stops(k)`.
    pure function gradient(t, stops, colors) result(rgb)
        real(wp), intent(in) :: t, stops(:)
        integer, intent(in) :: colors(:,:)
        integer :: rgb(3)
        integer :: k
        real(wp) :: f
        do k = 1, size(stops) - 1
            if (t <= stops(k + 1)) exit
        end do
        k = min(k, size(stops) - 1)
        f = (t - stops(k)) / (stops(k + 1) - stops(k))
        rgb = nint((1 - f)*colors(:, k) + f*colors(:, k + 1))
    end function gradient

    !> Fully saturated color of hue t (0..1).
    pure function hue(t) result(rgb)
        real(wp), intent(in) :: t
        integer :: rgb(3)
        real(wp) :: h, x
        integer :: sector
        h = 6*t
        sector = min(int(h), 5)
        x = h - sector
        select case (sector)
        case (0)
            rgb = nint(255*[1.0_wp, x, 0.0_wp])
        case (1)
            rgb = nint(255*[1 - x, 1.0_wp, 0.0_wp])
        case (2)
            rgb = nint(255*[0.0_wp, 1.0_wp, x])
        case (3)
            rgb = nint(255*[0.0_wp, 1 - x, 1.0_wp])
        case (4)
            rgb = nint(255*[x, 0.0_wp, 1.0_wp])
        case default
            rgb = nint(255*[1.0_wp, 0.0_wp, 1 - x])
        end select
    end function hue

    !> Color of escape count `mu` (inside the set: black, or white if inverted).
    pure function shade(mu, map, density, invert) result(rgb)
        real(wp), intent(in) :: mu, density
        integer, intent(in) :: map
        logical, intent(in) :: invert
        integer :: rgb(3)
        real(wp) :: t
        if (mu < 0) then
            rgb = 0
        else
            t = modulo(sqrt(mu) * density / 6, 1.0_wp)   ! sqrt: even bands at all zoom depths
            rgb = colormap(map, t)
        end if
        if (invert) rgb = 255 - rgb
    end function shade

    !> Compute the image of view `v`, nx x ny pixels, in parallel.
    subroutine compute(v, nx, ny, max_iter, map, density, smooth, invert, supersample, nthreads, rgb)
        type(view_t), intent(in) :: v
        integer, intent(in) :: nx, ny, max_iter, map, nthreads
        real(wp), intent(in) :: density
        logical, intent(in) :: smooth, invert, supersample
        integer, allocatable, intent(out) :: rgb(:,:,:)
        real(wp) :: dx, height, x0, y0
        integer :: i, j, si, sj, ns, acc(3)
        allocate(rgb(3, nx, ny))
        dx = v%width / nx
        height = dx * ny
        x0 = v%cx - v%width/2
        y0 = v%cy + height/2
        ns = merge(2, 1, supersample)
        !$omp parallel do schedule(dynamic, 2) num_threads(nthreads) default(shared) &
        !$omp private(i, j, si, sj, acc)
        do j = 1, ny
            do i = 1, nx
                acc = 0
                do sj = 1, ns
                    do si = 1, ns
                        acc = acc + shade(escape(x0 + (i - 1 + (si - 0.5_wp)/ns)*dx, &
                                                 y0 - (j - 1 + (sj - 0.5_wp)/ns)*dx, max_iter, smooth), &
                                          map, density, invert)
                    end do
                end do
                rgb(:, i, j) = acc / (ns*ns)
            end do
        end do
        !$omp end parallel do
    end subroutine compute

    ! ------------------------------------------------------------------ views

    !> Height of the imaginary axis shown by `v` in a w x h canvas.
    pure real(wp) function view_height(v, w, h)
        type(view_t), intent(in) :: v
        integer, intent(in) :: w, h
        view_height = v%width * real(max(h, 1), wp) / max(w, 1)
    end function view_height

    !> The point of `v` under canvas pixel (x, y).
    pure subroutine pixel_to_point(v, w, h, x, y, cr, ci)
        type(view_t), intent(in) :: v
        integer, intent(in) :: w, h
        real(wp), intent(in) :: x, y
        real(wp), intent(out) :: cr, ci
        cr = v%cx + (x / max(w, 1) - 0.5_wp) * v%width
        ci = v%cy - (y / max(h, 1) - 0.5_wp) * view_height(v, w, h)
    end subroutine pixel_to_point

    !> Show view `v` (saving the current one for Back) and recompute.
    subroutine go_to(s, v)
        type(app_t), intent(inout) :: s
        type(view_t), intent(in) :: v
        if (s%n_history == max_history) then
            s%history(1:max_history-1) = s%history(2:max_history)
            s%n_history = max_history - 1
        end if
        s%n_history = s%n_history + 1
        s%history(s%n_history) = s%view
        s%view = v
        if (s%view%width < min_width) then
            s%view%width = min_width
            call s%frame%set_status_text('Zoom limit of double precision reached')
        end if
        call request_redraw(s, 1)
    end subroutine go_to

    !> Zoom by `factor` (> 1: in) keeping canvas pixel (x, y) where it is.
    subroutine zoom_at(s, x, y, factor)
        type(app_t), intent(inout) :: s
        real(wp), intent(in) :: x, y, factor
        type(view_t) :: v
        real(wp) :: cr, ci, w, h
        integer :: cw, ch
        call s%canvas%get_client_size(cw, ch)
        call pixel_to_point(s%view, cw, ch, x, y, cr, ci)
        w = s%view%width
        h = view_height(s%view, cw, ch)
        v%width = w / factor
        v%cx = cr - (x / cw - 0.5_wp) * v%width
        v%cy = ci + (y / ch - 0.5_wp) * (h / factor)
        call go_to(s, v)
    end subroutine zoom_at

    !> Recompute after `ms` milliseconds (coalescing requests, e.g. while
    !> typing a number or resizing); repaint the preview now.
    subroutine request_redraw(s, ms)
        type(app_t), intent(inout) :: s
        integer, intent(in) :: ms
        call s%redraw%start(max(ms, 1), one_shot=.true.)
        call update_info(s)
        call s%canvas%refresh()
    end subroutine request_redraw

    !> The view readout in the settings panel.
    subroutine update_info(s)
        type(app_t), intent(inout) :: s
        character(len=200) :: buf
        write(buf, '(A,ES22.15,A,ES22.15,A,ES10.3,A,ES10.3,A)') 'Center x: ', s%view%cx, new_line('a')// &
            'Center y: ', s%view%cy, new_line('a')//'Width: ', s%view%width, new_line('a')// &
            'Zoom: ', presets(1)%width / s%view%width, ' x'
        call s%info%set_label(trim(buf))
        call s%tools%enable_tool(s%id_back, s%n_history > 0)
    end subroutine update_info

    ! ------------------------------------------------------------------ handlers

    !> The redraw timer: compute the image for the current view and size.
    subroutine on_redraw(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer, allocatable :: rgb(:,:,:)
        integer :: cw, ch, nx, ny, nthreads
        integer(int64) :: t0, t1, rate
        real(wp) :: scale
        character(len=200) :: msg
        select type (s => data)
        type is (app_t)
            call s%canvas%get_client_size(cw, ch)
            if (cw < 2 .or. ch < 2) return
            scale = s%canvas%get_content_scale_factor()
            nx = nint(cw * scale)
            ny = nint(ch * scale)
            nthreads = s%threads%get_value()
            call wx_begin_busy_cursor()
            call system_clock(t0, rate)
            call compute(s%view, nx, ny, s%iterations%get_value(), s%colormap%get_selection(), &
                         s%density%get_value(), s%smooth%get_value(), s%invert%get_value(), &
                         s%supersample%get_value(), nthreads, rgb)
            call system_clock(t1)
            call wx_end_busy_cursor()
            if (s%image%is_valid()) call s%image%destroy()
            s%image = wx_bitmap(rgb, scale=scale)
            s%image_view = s%view
            s%image_w = cw
            s%image_h = ch
            write(msg, '(I0,A,I0,A,I0,A,I0,A,F7.3,A)') nx, ' x ', ny, ' px, ', s%iterations%get_value(), &
                ' iterations, ', nthreads, ' thread(s):', real(t1 - t0, wp) / rate, ' s'
            s%timing = trim(msg)
            call s%frame%set_status_text(s%timing, field=2)
            call s%canvas%refresh()
            if (allocated(s%screenshot)) call wx_call_after(take_screenshot, s)
        end select
    end subroutine on_redraw

    !> Paint: the image (stretched to the current view while the new one is
    !> computed) and the selection box.
    subroutine on_paint(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        real(wp) :: px0, py0, px1, py1, iw, ih, cw, ch, bw, bh
        integer :: x0, y0, x1, y1
        select type (s => data)
        type is (app_t)
            g = wx_graphics(event)
            cw = g%width
            ch = g%height
            call g%fill(wxBLACK)
            if (s%image%is_valid()) then
                ! where the image's region falls in the current view
                iw = s%image_view%width / s%view%width * s%image_w * cw / s%image_w
                ih = iw * real(s%image_h, wp) / s%image_w
                px0 = cw/2 + (s%image_view%cx - s%view%cx) / s%view%width * cw - iw/2
                py0 = ch/2 - (s%image_view%cy - s%view%cy) / s%view%width * cw - ih/2
                call g%draw_bitmap(s%image, px0, py0, iw, ih, smooth=.true.)
            end if
            if (s%dragging) then
                call selection_box(s, x0, y0, x1, y1)
                px1 = real(x1, wp)
                py1 = real(y1, wp)
                bw = px1 - x0
                bh = py1 - y0
                call g%set_brush(wx_color(255, 255, 255, 45))
                call g%set_pen(wxWHITE, width=1.5_wp, style=wxPENSTYLE_SHORT_DASH)
                call g%draw_rectangle(real(x0, wp), real(y0, wp), bw, bh)
                if (bw > 30) then
                    call g%set_font(9.0_wp, wxWHITE, bold=.true.)
                    call g%draw_text(zoom_label(cw / max(bw, 1.0_wp)), real(x0, wp) + 4, real(y0, wp) + 3)
                end if
            end if
        end select
    end subroutine on_paint

    !> "zoom 12.5x".
    function zoom_label(f) result(s)
        real(wp), intent(in) :: f
        character(len=:), allocatable :: s
        character(len=32) :: buf
        write(buf, '(A,F0.1,A)') 'zoom ', f, 'x'
        s = trim(buf)
    end function zoom_label

    !> The drag rectangle, normalized, with the canvas's aspect ratio
    !> (the larger side of the drag decides).
    subroutine selection_box(s, x0, y0, x1, y1)
        type(app_t), intent(in) :: s
        integer, intent(out) :: x0, y0, x1, y1
        integer :: cw, ch, w, h
        call s%canvas%get_client_size(cw, ch)
        w = abs(s%x1 - s%x0)
        h = abs(s%y1 - s%y0)
        if (w * ch >= h * cw) then
            h = nint(real(w, wp) * ch / cw)
        else
            w = nint(real(h, wp) * cw / ch)
        end if
        x0 = merge(s%x0, s%x0 - w, s%x1 >= s%x0)
        y0 = merge(s%y0, s%y0 - h, s%y1 >= s%y0)
        x1 = x0 + w
        y1 = y0 + h
    end subroutine selection_box

    !> Mouse: drag to select, click to zoom in, right-click to zoom out, wheel.
    subroutine on_mouse(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: x, y, cw, ch, x0, y0, x1, y1
        real(wp) :: cr, ci
        type(view_t) :: v
        character(len=80) :: buf
        select type (s => data)
        type is (app_t)
            select case (event%kind())
            case (wxEVT_MOUSE_CAPTURE_LOST)
                s%dragging = .false.
                call s%canvas%refresh()
                return
            case (wxEVT_LEAVE_WINDOW)
                call s%frame%set_status_text('', field=1)
                return
            end select
            call event%get_position(x, y)
            call s%canvas%get_client_size(cw, ch)
            select case (event%kind())
            case (wxEVT_LEFT_DOWN)
                s%dragging = .true.
                s%x0 = x
                s%y0 = y
                s%x1 = x
                s%y1 = y
                call s%canvas%capture_mouse()
            case (wxEVT_MOTION)
                call pixel_to_point(s%view, cw, ch, real(x, wp), real(y, wp), cr, ci)
                write(buf, '(A,ES16.9,A,ES16.9)') 'x = ', cr, '   y = ', ci
                call s%frame%set_status_text(trim(buf), field=1)
                if (s%dragging) then
                    s%x1 = x
                    s%y1 = y
                    call s%canvas%refresh()
                end if
            case (wxEVT_LEFT_UP)
                if (.not. s%dragging) return
                s%dragging = .false.
                call s%canvas%release_mouse()
                s%x1 = x
                s%y1 = y
                call selection_box(s, x0, y0, x1, y1)
                if (x1 - x0 < 6) then
                    call zoom_at(s, real(x, wp), real(y, wp), 2.0_wp)   ! a click
                else
                    call pixel_to_point(s%view, cw, ch, 0.5_wp*(x0 + x1), 0.5_wp*(y0 + y1), v%cx, v%cy)
                    v%width = s%view%width * real(x1 - x0, wp) / cw
                    call go_to(s, v)
                end if
            case (wxEVT_RIGHT_UP)
                call zoom_at(s, real(x, wp), real(y, wp), 0.5_wp)
            case (wxEVT_MOUSEWHEEL)
                call zoom_at(s, real(x, wp), real(y, wp), 1.25_wp**event%get_wheel_rotation())
                s%n_history = max(s%n_history - 1, 0)   ! wheel steps are not kept for Back
                call s%redraw%start(250, one_shot=.true.)
            end select
        end select
    end subroutine on_mouse

    !> Keys: Escape cancels a drag; Backspace: back; -: zoom out; R: reset.
    subroutine on_key(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: cw, ch
        select type (s => data)
        type is (app_t)
            call s%canvas%get_client_size(cw, ch)
            select case (event%get_key_code())
            case (WXK_ESCAPE)
                if (s%dragging) then
                    s%dragging = .false.
                    call s%canvas%release_mouse()
                    call s%canvas%refresh()
                end if
            case (WXK_BACK)
                call back(s)
            case (iachar('-'))
                call zoom_at(s, 0.5_wp*cw, 0.5_wp*ch, 0.5_wp)
            case (iachar('='), iachar('+'))
                call zoom_at(s, 0.5_wp*cw, 0.5_wp*ch, 2.0_wp)
            case (iachar('R'))
                call reset(s)
            case default
                call event%skip()
            end select
        end select
    end subroutine on_key

    !> Return to the previous view.
    subroutine back(s)
        type(app_t), intent(inout) :: s
        if (s%n_history == 0) return
        s%view = s%history(s%n_history)
        s%n_history = s%n_history - 1
        call request_redraw(s, 1)
    end subroutine back

    !> The full set.
    subroutine reset(s)
        type(app_t), intent(inout) :: s
        type(view_t) :: v
        call go_to(s, v)
    end subroutine reset

    !> View menu and toolbar.
    subroutine on_view(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: cw, ch
        select type (s => data)
        type is (app_t)
            call s%canvas%get_client_size(cw, ch)
            if (event%get_id() == s%id_back) call back(s)
            if (event%get_id() == s%id_zoom_out) call zoom_at(s, 0.5_wp*cw, 0.5_wp*ch, 0.5_wp)
            if (event%get_id() == s%id_reset) call reset(s)
        end select
    end subroutine on_view

    !> Any setting changed: recompute soon.
    subroutine on_setting(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call request_redraw(s, 150)
        end select
    end subroutine on_setting

    !> A preset location.
    subroutine on_preset(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(view_t) :: v
        integer :: k
        select type (s => data)
        type is (app_t)
            k = event%get_selection()
            if (k < 1) return
            v = view_t(presets(k)%cx, presets(k)%cy, presets(k)%width)
            if (s%iterations%get_value() < presets(k)%iterations) call s%iterations%set_value(presets(k)%iterations)
            call go_to(s, v)
        end select
    end subroutine on_preset

    !> Canvas resized: recompute once the size settles.
    subroutine on_size(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call request_redraw(s, 200)
        end select
        call event%skip()
    end subroutine on_size

    !> File > Save image.
    subroutine on_save(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        select type (s => data)
        type is (app_t)
            if (.not. s%image%is_valid()) return
            if (wx_file_save_dialog(path, default_file='mandelbrot.png', wildcard='PNG images (*.png)|*.png', &
                                    parent=s%frame)) then
                call s%image%save_png(path)
                call s%frame%set_status_text('Saved '//path)
            end if
        end select
    end subroutine on_save

    !> File > Quit.
    subroutine on_quit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (s%frame%close()) continue
        end select
    end subroutine on_quit

    !> Help > About.
    subroutine on_about(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call wx_about_box('wxFortran Mandelbrot', version='0.0.1', &
                              description='A Mandelbrot set explorer in modern Fortran, with wxWidgets and OpenMP.', &
                              parent=s%frame)
        end select
    end subroutine on_about

    !> --screenshot: save the first image and quit.
    subroutine take_screenshot(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call s%image%save_png(s%screenshot)
            write(*, '(A)') 'mandelbrot: saved '//s%screenshot//' ('//s%timing//')'
            if (s%frame%close()) continue
        end select
    end subroutine take_screenshot

end module mandelbrot_ui


!> Builds the explorer window and runs it.
program mandelbrot

    use wx
    use mandelbrot_ui
    implicit none

    type(app_t), target :: s
    type(wx_panel) :: panel, side
    type(wx_box_sizer) :: main, side_sizer
    type(wx_static_box_sizer) :: render_box, view_box
    type(wx_flex_grid_sizer) :: grid
    type(wx_window) :: rbox, vbox
    type(wx_menu_bar) :: bar
    type(wx_menu) :: file_menu, view_menu, help_menu
    integer :: id, max_threads, i, start_preset, ios
    character(len=24) :: preset_names(size(presets))
    character(len=512) :: arg

    s%app = wx_app()
    max_threads = 1
!$  max_threads = omp_get_max_threads()

    start_preset = 0
    i = 1
    do while (i <= command_argument_count())
        call get_command_argument(i, arg)
        select case (arg)
        case ('--screenshot')
            i = i + 1
            call get_command_argument(i, arg)
            s%screenshot = trim(arg)
            if (len(s%screenshot) == 0) s%screenshot = 'mandelbrot.png'
        case ('--preset')
            i = i + 1
            call get_command_argument(i, arg)
            read(arg, *, iostat=ios) start_preset
            if (ios /= 0 .or. start_preset < 1 .or. start_preset > size(presets)) start_preset = 0
        end select
        i = i + 1
    end do

    s%frame = wx_frame('wxFortran Mandelbrot', width=1100, height=720)

    ! --- menus and toolbar (tools share the menu items' ids)
    bar = wx_menu_bar()
    file_menu = wx_menu()
    id = file_menu%append(id=wxID_SAVE, text='&Save image...'//achar(9)//'Ctrl+S')
    call file_menu%append_separator()
    id = file_menu%append(id=wxID_EXIT)
    view_menu = wx_menu()
    s%id_back = view_menu%append('&Back', help='Previous view (Backspace)')
    s%id_zoom_out = view_menu%append('Zoom &out', help='Zoom out 2x (-, or right-click)')
    s%id_reset = view_menu%append('&Reset'//achar(9)//'Ctrl+0', help='The whole set (R)')
    help_menu = wx_menu()
    id = help_menu%append(id=wxID_ABOUT)
    call bar%append(file_menu, '&File')
    call bar%append(view_menu, '&View')
    call bar%append(help_menu, '&Help')
    call s%frame%set_menu_bar(bar)
    s%tools = wx_tool_bar(s%frame, text=.true.)
    id = s%tools%add_tool('Back', art='wxART_GO_BACK', help='Previous view', id=s%id_back)
    id = s%tools%add_tool('Zoom out', art='wxART_MINUS', help='Zoom out 2x', id=s%id_zoom_out)
    id = s%tools%add_tool('Reset', art='wxART_GO_HOME', help='The whole set', id=s%id_reset)
    call s%tools%add_separator()
    id = s%tools%add_tool('Save', art='wxART_FILE_SAVE', help='Save the image', id=wxID_SAVE)
    call s%frame%bind(wxEVT_MENU, on_view, data=s, id=s%id_back)
    call s%frame%bind(wxEVT_MENU, on_view, data=s, id=s%id_zoom_out)
    call s%frame%bind(wxEVT_MENU, on_view, data=s, id=s%id_reset)
    call s%frame%bind(wxEVT_MENU, on_save, data=s, id=wxID_SAVE)
    call s%frame%bind(wxEVT_MENU, on_quit, data=s, id=wxID_EXIT)
    call s%frame%bind(wxEVT_MENU, on_about, data=s, id=wxID_ABOUT)
    call s%frame%create_status_bar(3)
    call s%frame%set_status_text('Drag a box to zoom in; click: 2x; right-click: zoom out; wheel: zoom')

    ! --- settings panel
    panel = wx_panel(s%frame)
    side = wx_panel(panel)
    render_box = wx_static_box_sizer(wxVERTICAL, side, 'Rendering')
    rbox = render_box%get_static_box()
    s%colormap = wx_choice(rbox, map_names, selection=1)
    s%smooth = wx_check_box(rbox, 'Smooth coloring', checked=.true.)
    s%invert = wx_check_box(rbox, 'Invert colors')
    s%supersample = wx_check_box(rbox, 'Supersample 2x2 (slower)')
    s%iterations = wx_spin_ctrl(rbox, value=presets(1)%iterations, min=20, max=100000)
    s%density = wx_spin_ctrl_double(rbox, value=1.0_wp, min=0.1_wp, max=20.0_wp, increment=0.1_wp, digits=1)
    s%threads = wx_spin_ctrl(rbox, value=max_threads, min=1, max=max_threads)
    if (max_threads == 1) call s%threads%disable()
    grid = wx_flex_grid_sizer(2, vgap=6, hgap=8)
    call grid%add(wx_static_text(rbox, 'Colormap:'), flags=wxALIGN_RIGHT)
    call grid%add(s%colormap, flags=wxEXPAND)
    call grid%add(wx_static_text(rbox, 'Iterations:'), flags=wxALIGN_RIGHT)
    call grid%add(s%iterations, flags=wxEXPAND)
    call grid%add(wx_static_text(rbox, 'Color density:'), flags=wxALIGN_RIGHT)
    call grid%add(s%density, flags=wxEXPAND)
    call grid%add(wx_static_text(rbox, 'Threads:'), flags=wxALIGN_RIGHT)
    call grid%add(s%threads, flags=wxEXPAND)
    call grid%add_growable_col(2)
    call render_box%add(grid, flags=ior(wxEXPAND, wxALL), border=6)
    call render_box%add(s%smooth, flags=ior(wxLEFT, wxBOTTOM), border=6)
    call render_box%add(s%invert, flags=ior(wxLEFT, wxBOTTOM), border=6)
    call render_box%add(s%supersample, flags=ior(wxLEFT, wxBOTTOM), border=6)

    view_box = wx_static_box_sizer(wxVERTICAL, side, 'View')
    vbox = view_box%get_static_box()
    do i = 1, size(presets)
        preset_names(i) = presets(i)%name
    end do
    s%preset = wx_choice(vbox, preset_names, selection=1)
    s%info = wx_static_text(vbox, '')
    call view_box%add(wx_static_text(vbox, 'Go to:'), flags=ior(wxLEFT, wxTOP), border=6)
    call view_box%add(s%preset, flags=ior(wxEXPAND, wxALL), border=6)
    call view_box%add(s%info, flags=ior(wxEXPAND, wxALL), border=6)

    side_sizer = wx_box_sizer(wxVERTICAL)
    call side_sizer%add(render_box, flags=ior(wxEXPAND, wxALL), border=8)
    call side_sizer%add(view_box, flags=ior(wxEXPAND, ior(wxLEFT, ior(wxRIGHT, wxBOTTOM))), border=8)
    call side%set_sizer(side_sizer)

    s%canvas = wx_canvas(panel)
    call s%canvas%set_background_color(wxBLACK)
    call s%canvas%set_cursor(WX_CURSOR_CROSS)
    main = wx_box_sizer(wxHORIZONTAL)
    call main%add(side, flags=wxEXPAND)
    call main%add(s%canvas, proportion=1, flags=wxEXPAND)
    call panel%set_sizer(main)

    ! --- events
    call s%canvas%bind(wxEVT_PAINT, on_paint, data=s)
    call s%canvas%bind(wxEVT_SIZE, on_size, data=s)
    call s%canvas%bind(wxEVT_LEFT_DOWN, on_mouse, data=s)
    call s%canvas%bind(wxEVT_LEFT_UP, on_mouse, data=s)
    call s%canvas%bind(wxEVT_RIGHT_UP, on_mouse, data=s)
    call s%canvas%bind(wxEVT_MOTION, on_mouse, data=s)
    call s%canvas%bind(wxEVT_MOUSEWHEEL, on_mouse, data=s)
    call s%canvas%bind(wxEVT_LEAVE_WINDOW, on_mouse, data=s)
    call s%canvas%bind(wxEVT_MOUSE_CAPTURE_LOST, on_mouse, data=s)
    call s%canvas%bind(wxEVT_KEY_DOWN, on_key, data=s)
    call s%colormap%bind(wxEVT_CHOICE, on_setting, data=s)
    call s%smooth%bind(wxEVT_CHECKBOX, on_setting, data=s)
    call s%invert%bind(wxEVT_CHECKBOX, on_setting, data=s)
    call s%supersample%bind(wxEVT_CHECKBOX, on_setting, data=s)
    call s%iterations%bind(wxEVT_SPINCTRL, on_setting, data=s)
    call s%density%bind(wxEVT_SPINCTRLDOUBLE, on_setting, data=s)
    call s%threads%bind(wxEVT_SPINCTRL, on_setting, data=s)
    call s%preset%bind(wxEVT_CHOICE, on_preset, data=s)
    s%redraw = wx_timer(owner=s%frame)
    call s%redraw%bind(wxEVT_TIMER, on_redraw, data=s)

    if (start_preset > 0) then
        s%view = view_t(presets(start_preset)%cx, presets(start_preset)%cy, presets(start_preset)%width)
        call s%iterations%set_value(presets(start_preset)%iterations)
        call s%preset%set_selection(start_preset)
    end if
    call update_info(s)
    call s%frame%center()
    call s%frame%show()
    call s%canvas%set_focus()
    call request_redraw(s, 50)

    stop s%app%run()

end program mandelbrot

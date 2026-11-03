!> Drawing: [[wx_graphics]], the anti-aliased 2D drawing context passed to
!> `wxEVT_PAINT` handlers, plus offscreen rendering to PNG and image reading.
!>
!> ```fortran
!> call canvas%bind(wxEVT_PAINT, on_paint, data=state)
!> ...
!> subroutine on_paint(event, data)
!>     type(wx_event), intent(inout) :: event
!>     class(*), intent(inout), optional :: data
!>     type(wx_graphics) :: g
!>     g = wx_graphics(event)
!>     call g%set_pen(wxBLUE, width=2.0_wp)
!>     call g%stroke_lines(x, y)
!> end subroutine
!> ```
!>
!> Coordinates are `real(c_double)` pixels from the top-left corner, y
!> downwards. The context is valid only during the paint handler; using it
!> afterwards fails with `WX_ERR_STATE`. The same handler draws on the screen,
!> into `canvas%save_png(file)`, and (bound to nothing) into
!> [[wx_render_png]].
module wx_graphics_mod

    use iso_c_binding
    use wx_c_core
    use wx_c_graphics
    use wx_c_layout, only: wxf_gc_draw_rgb, wxf_gc_draw_image_file
    use wx_base
    use wx_events
    use wx_colors
    implicit none
    private

    public :: wxPENSTYLE_SOLID, wxPENSTYLE_DOT, wxPENSTYLE_LONG_DASH, wxPENSTYLE_SHORT_DASH
    public :: wxFONTFAMILY_DEFAULT, wxFONTFAMILY_SWISS, wxFONTFAMILY_ROMAN, wxFONTFAMILY_TELETYPE
    public :: wx_render_png, wx_image_read_rgb

    !> An image made once (from an RGB array or a file) and drawn any number
    !> of times with `g%draw_bitmap`: much faster than `g%draw_rgb` for large
    !> images redrawn often. Owned by the program: `destroy` it when done
    !> (or it is deleted by `app%cleanup()`).
    type, extends(wx_object), public :: wx_bitmap
    contains
        procedure :: get_size => wx_bitmap_get_size
        procedure :: save_png => wx_bitmap_save_png
        procedure :: destroy => wx_bitmap_destroy
    end type wx_bitmap

    !> Create a bitmap from an RGB array or an image file.
    interface wx_bitmap
        module procedure wx_bitmap_from_rgb, wx_bitmap_from_file
    end interface wx_bitmap

    !> A drawing context (borrowed from a paint event).
    type, public :: wx_graphics
        type(c_ptr), private :: gc = c_null_ptr
        real(c_double) :: width = 0    !! width of the drawing area, in pixels
        real(c_double) :: height = 0   !! height of the drawing area, in pixels
    contains
        procedure :: set_pen => wx_graphics_set_pen
        procedure :: set_no_pen => wx_graphics_set_no_pen
        procedure :: set_brush => wx_graphics_set_brush
        procedure :: set_no_brush => wx_graphics_set_no_brush
        procedure :: set_font => wx_graphics_set_font
        procedure :: stroke_line => wx_graphics_stroke_line
        procedure :: stroke_lines => wx_graphics_stroke_lines
        procedure :: draw_polygon => wx_graphics_draw_polygon
        procedure :: draw_rectangle => wx_graphics_draw_rectangle
        procedure :: draw_ellipse => wx_graphics_draw_ellipse
        procedure :: draw_circle => wx_graphics_draw_circle
        procedure :: draw_text => wx_graphics_draw_text
        procedure :: get_text_extent => wx_graphics_get_text_extent
        procedure :: fill => wx_graphics_fill
        procedure :: clip => wx_graphics_clip
        procedure :: reset_clip => wx_graphics_reset_clip
        procedure :: push_state => wx_graphics_push_state
        procedure :: pop_state => wx_graphics_pop_state
        procedure :: translate => wx_graphics_translate
        procedure :: scale => wx_graphics_scale
        procedure :: rotate => wx_graphics_rotate
        procedure :: set_antialias => wx_graphics_set_antialias
        procedure :: draw_rgb => wx_graphics_draw_rgb
        procedure :: draw_image_file => wx_graphics_draw_image_file
        procedure :: draw_bitmap => wx_graphics_draw_bitmap
    end type wx_graphics

    !> The drawing context of a `wxEVT_PAINT` event.
    interface wx_graphics
        module procedure wx_graphics_from_event
    end interface wx_graphics

contains

    !> The drawing context of paint event `event` (with the size of the area
    !> to draw in `width` and `height`). Fails for other events.
    type(wx_graphics) function wx_graphics_from_event(event, stat) result(g)
        type(wx_event), intent(in) :: event
        integer, intent(out), optional :: stat
        call wx_check(wxf_event_get_graphics(event%c_event(), g%gc, g%width, g%height), stat)
    end function wx_graphics_from_event

    !> Draw outlines with `color`, `width` pixels wide (default 1) and
    !> `style` (`wxPENSTYLE_*`, default solid).
    subroutine wx_graphics_set_pen(self, color, width, style, stat)
        class(wx_graphics), intent(inout) :: self
        type(wx_color), intent(in) :: color
        real(c_double), intent(in), optional :: width
        integer, intent(in), optional :: style
        integer, intent(out), optional :: stat
        real(c_double) :: w
        integer(c_int) :: s
        w = 1
        if (present(width)) w = width
        if (w <= 0) w = 1.0e-3_c_double
        s = wxPENSTYLE_SOLID
        if (present(style)) s = int(style, c_int)
        call wx_check(wxf_gc_set_pen(self%gc, int(color%r, c_int), int(color%g, c_int), int(color%b, c_int), &
                                     int(color%a, c_int), w, s), stat)
    end subroutine wx_graphics_set_pen

    !> Draw no outlines.
    subroutine wx_graphics_set_no_pen(self, stat)
        class(wx_graphics), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_set_pen(self%gc, 0_c_int, 0_c_int, 0_c_int, 0_c_int, 0.0_c_double, 0_c_int), stat)
    end subroutine wx_graphics_set_no_pen

    !> Fill shapes with `color`.
    subroutine wx_graphics_set_brush(self, color, stat)
        class(wx_graphics), intent(inout) :: self
        type(wx_color), intent(in) :: color
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_set_brush(self%gc, int(color%r, c_int), int(color%g, c_int), int(color%b, c_int), &
                                       int(color%a, c_int), 0_c_int), stat)
    end subroutine wx_graphics_set_brush

    !> Do not fill shapes (outlines only).
    subroutine wx_graphics_set_no_brush(self, stat)
        class(wx_graphics), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_set_brush(self%gc, 0_c_int, 0_c_int, 0_c_int, 0_c_int, 1_c_int), stat)
    end subroutine wx_graphics_set_no_brush

    !> Font for `draw_text`: `size` in points, `color` (default black),
    !> `family` (`wxFONTFAMILY_*`), bold and italic.
    subroutine wx_graphics_set_font(self, size, color, family, bold, italic, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: size
        type(wx_color), intent(in), optional :: color
        integer, intent(in), optional :: family
        logical, intent(in), optional :: bold, italic
        integer, intent(out), optional :: stat
        type(wx_color) :: c
        integer(c_int) :: f
        logical :: b, i
        c = wxBLACK
        if (present(color)) c = color
        f = wxFONTFAMILY_DEFAULT
        if (present(family)) f = int(family, c_int)
        b = .false.
        if (present(bold)) b = bold
        i = .false.
        if (present(italic)) i = italic
        call wx_check(wxf_gc_set_font(self%gc, size, f, wx_int(b), wx_int(i), int(c%r, c_int), int(c%g, c_int), &
                                      int(c%b, c_int), int(c%a, c_int)), stat)
    end subroutine wx_graphics_set_font

    !> A line from (x1, y1) to (x2, y2), with the pen.
    subroutine wx_graphics_stroke_line(self, x1, y1, x2, y2, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x1, y1, x2, y2
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_stroke_line(self%gc, x1, y1, x2, y2), stat)
    end subroutine wx_graphics_stroke_line

    !> A polyline through the points (x(i), y(i)), with the pen.
    subroutine wx_graphics_stroke_lines(self, x, y, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x(:), y(:)
        integer, intent(out), optional :: stat
        real(c_double), allocatable :: cx(:), cy(:)
        if (size(x) /= size(y)) then
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'stroke_lines: x and y differ in size'), stat)
            return
        end if
        cx = x   ! contiguous copies
        cy = y
        call wx_check(wxf_gc_stroke_lines(self%gc, cx, cy, int(size(cx), c_int)), stat)
    end subroutine wx_graphics_stroke_lines

    !> A closed polygon through (x(i), y(i)), filled with the brush and
    !> outlined with the pen.
    subroutine wx_graphics_draw_polygon(self, x, y, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x(:), y(:)
        integer, intent(out), optional :: stat
        real(c_double), allocatable :: cx(:), cy(:)
        if (size(x) /= size(y)) then
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'draw_polygon: x and y differ in size'), stat)
            return
        end if
        cx = x
        cy = y
        call wx_check(wxf_gc_draw_polygon(self%gc, cx, cy, int(size(cx), c_int)), stat)
    end subroutine wx_graphics_draw_polygon

    !> A rectangle with top-left (x, y), filled and outlined; `radius` > 0
    !> rounds its corners.
    subroutine wx_graphics_draw_rectangle(self, x, y, width, height, radius, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x, y, width, height
        real(c_double), intent(in), optional :: radius
        integer, intent(out), optional :: stat
        real(c_double) :: r
        r = 0
        if (present(radius)) r = radius
        call wx_check(wxf_gc_draw_rectangle(self%gc, x, y, width, height, r), stat)
    end subroutine wx_graphics_draw_rectangle

    !> An ellipse inside the box with top-left (x, y), filled and outlined.
    subroutine wx_graphics_draw_ellipse(self, x, y, width, height, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x, y, width, height
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_draw_ellipse(self%gc, x, y, width, height), stat)
    end subroutine wx_graphics_draw_ellipse

    !> A circle centered on (x, y), filled and outlined.
    subroutine wx_graphics_draw_circle(self, x, y, radius, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x, y, radius
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_draw_ellipse(self%gc, x - radius, y - radius, 2*radius, 2*radius), stat)
    end subroutine wx_graphics_draw_circle

    !> `text` with its top-left corner at (x, y) in the current font, rotated
    !> by `angle` radians counter-clockwise (e.g. `pi/2` for a vertical label).
    subroutine wx_graphics_draw_text(self, text, x, y, angle, stat)
        class(wx_graphics), intent(inout) :: self
        character(len=*), intent(in) :: text
        real(c_double), intent(in) :: x, y
        real(c_double), intent(in), optional :: angle
        integer, intent(out), optional :: stat
        real(c_double) :: a
        a = 0
        if (present(angle)) a = angle
        call wx_check(wxf_gc_draw_text(self%gc, text, len(text, c_int), x, y, a), stat)
    end subroutine wx_graphics_draw_text

    !> Width and height of `text` in the current font (for alignment).
    subroutine wx_graphics_get_text_extent(self, text, width, height, stat)
        class(wx_graphics), intent(inout) :: self
        character(len=*), intent(in) :: text
        real(c_double), intent(out) :: width, height
        integer, intent(out), optional :: stat
        width = 0
        height = 0
        call wx_check(wxf_gc_get_text_extent(self%gc, text, len(text, c_int), width, height), stat)
    end subroutine wx_graphics_get_text_extent

    !> Fill the whole drawing area with `color`.
    subroutine wx_graphics_fill(self, color, stat)
        class(wx_graphics), intent(inout) :: self
        type(wx_color), intent(in) :: color
        integer, intent(out), optional :: stat
        integer :: s
        call self%push_state(s)
        if (s == WX_OK) call self%set_no_pen(s)
        if (s == WX_OK) call self%set_brush(color, s)
        if (s == WX_OK) call self%draw_rectangle(0.0_c_double, 0.0_c_double, self%width, self%height, stat=s)
        if (s == WX_OK) call self%pop_state(s)
        call wx_check(int(s, c_int), stat)
    end subroutine wx_graphics_fill

    !> Draw only inside the rectangle with top-left (x, y) (until
    !> `reset_clip` or `pop_state`).
    subroutine wx_graphics_clip(self, x, y, width, height, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: x, y, width, height
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_clip(self%gc, x, y, width, height), stat)
    end subroutine wx_graphics_clip

    !> Remove the clipping rectangle.
    subroutine wx_graphics_reset_clip(self, stat)
        class(wx_graphics), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_reset_clip(self%gc), stat)
    end subroutine wx_graphics_reset_clip

    !> Save the pen, brush, font, clip and transformation (see `pop_state`).
    subroutine wx_graphics_push_state(self, stat)
        class(wx_graphics), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_push_state(self%gc), stat)
    end subroutine wx_graphics_push_state

    !> Restore the state saved by the last `push_state`.
    subroutine wx_graphics_pop_state(self, stat)
        class(wx_graphics), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_pop_state(self%gc), stat)
    end subroutine wx_graphics_pop_state

    !> Move the origin by (dx, dy).
    subroutine wx_graphics_translate(self, dx, dy, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: dx, dy
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_translate(self%gc, dx, dy), stat)
    end subroutine wx_graphics_translate

    !> Scale the coordinates by (sx, sy).
    subroutine wx_graphics_scale(self, sx, sy, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: sx, sy
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_scale(self%gc, sx, sy), stat)
    end subroutine wx_graphics_scale

    !> Rotate the coordinates by `angle` radians (clockwise on screen).
    subroutine wx_graphics_rotate(self, angle, stat)
        class(wx_graphics), intent(inout) :: self
        real(c_double), intent(in) :: angle
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_rotate(self%gc, angle), stat)
    end subroutine wx_graphics_rotate

    !> Turn anti-aliasing on (the default) or off.
    subroutine wx_graphics_set_antialias(self, on, stat)
        class(wx_graphics), intent(inout) :: self
        logical, intent(in) :: on
        integer, intent(out), optional :: stat
        call wx_check(wxf_gc_set_antialias(self%gc, wx_int(on)), stat)
    end subroutine wx_graphics_set_antialias

    !> Draw the image `rgb(3, nx, ny)` (0-255) scaled into the box with
    !> top-left (x, y), `width` x `height` pixels (default: its own size).
    !> Pixels are drawn as crisp blocks unless `smooth` (e.g. for heatmaps of
    !> a computed field, scale up a small array).
    subroutine wx_graphics_draw_rgb(self, rgb, x, y, width, height, smooth, stat)
        class(wx_graphics), intent(inout) :: self
        integer, intent(in) :: rgb(:,:,:)
        real(c_double), intent(in) :: x, y
        real(c_double), intent(in), optional :: width, height
        logical, intent(in), optional :: smooth
        integer, intent(out), optional :: stat
        integer(c_int8_t), allocatable :: bytes(:)
        real(c_double) :: w, h
        integer(c_int) :: s
        if (size(rgb, 1) /= 3) then
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'draw_rgb: rgb must have shape (3, width, height)'), stat)
            return
        end if
        w = size(rgb, 2)
        if (present(width)) w = width
        h = size(rgb, 3)
        if (present(height)) h = height
        s = 0
        if (present(smooth)) s = wx_int(smooth)
        bytes = wx_rgb_bytes(rgb)
        call wx_check(wxf_gc_draw_rgb(self%gc, bytes, int(size(rgb, 2), c_int), int(size(rgb, 3), c_int), &
                                      x, y, w, h, s), stat)
    end subroutine wx_graphics_draw_rgb

    !> Draw an image file with top-left (x, y), scaled to `width` x `height`
    !> (default: its own size).
    subroutine wx_graphics_draw_image_file(self, file, x, y, width, height, stat)
        class(wx_graphics), intent(inout) :: self
        character(len=*), intent(in) :: file
        real(c_double), intent(in) :: x, y
        real(c_double), intent(in), optional :: width, height
        integer, intent(out), optional :: stat
        real(c_double) :: w, h
        w = 0
        if (present(width)) w = width
        h = 0
        if (present(height)) h = height
        call wx_check(wxf_gc_draw_image_file(self%gc, file, len(file, c_int), x, y, w, h), stat)
    end subroutine wx_graphics_draw_image_file

    !> Draw bitmap `bitmap` with top-left (x, y), scaled to `width` x
    !> `height` (default: its logical size), as crisp pixels unless `smooth`.
    subroutine wx_graphics_draw_bitmap(self, bitmap, x, y, width, height, smooth, stat)
        class(wx_graphics), intent(inout) :: self
        class(wx_bitmap), intent(in) :: bitmap
        real(c_double), intent(in) :: x, y
        real(c_double), intent(in), optional :: width, height
        logical, intent(in), optional :: smooth
        integer, intent(out), optional :: stat
        real(c_double) :: w, h
        integer(c_int) :: s
        w = 0
        if (present(width)) w = width
        h = 0
        if (present(height)) h = height
        s = 0
        if (present(smooth)) s = wx_int(smooth)
        call wx_check(wxf_gc_draw_bitmap(self%gc, bitmap%h, x, y, w, h, s), stat)
    end subroutine wx_graphics_draw_bitmap

    ! -------------------------------------------------------------------------
    ! bitmaps

    !> A bitmap of the image `rgb(3, nx, ny)` (0-255). With `scale` > 1
    !> (e.g. `window%get_content_scale_factor()`), the array has `scale`
    !> pixels per logical pixel: drawn at its logical size `nx/scale` x
    !> `ny/scale`, it is sharp on a high-DPI screen.
    type(wx_bitmap) function wx_bitmap_from_rgb(rgb, scale, stat) result(b)
        integer, intent(in) :: rgb(:,:,:)
        real(c_double), intent(in), optional :: scale
        integer, intent(out), optional :: stat
        integer(c_int8_t), allocatable :: bytes(:)
        real(c_double) :: s
        integer(c_int) :: status
        if (size(rgb, 1) /= 3) then
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'wx_bitmap: rgb must have shape (3, width, height)'), stat)
            return
        end if
        s = 1
        if (present(scale)) s = scale
        bytes = wx_rgb_bytes(rgb)
        status = wxf_bitmap_create_rgb(bytes, int(size(rgb, 2), c_int), int(size(rgb, 3), c_int), s, b%h)
        if (status /= WX_OK) b%h = 0
        call wx_check(status, stat)
    end function wx_bitmap_from_rgb

    !> A bitmap of the image file `file` (PNG, JPEG, ...).
    type(wx_bitmap) function wx_bitmap_from_file(file, stat) result(b)
        character(len=*), intent(in) :: file
        integer, intent(out), optional :: stat
        integer(c_int) :: status
        status = wxf_bitmap_load(file, len(file, c_int), b%h)
        if (status /= WX_OK) b%h = 0
        call wx_check(status, stat)
    end function wx_bitmap_from_file

    !> Logical size (pixels divided by the scale).
    subroutine wx_bitmap_get_size(self, width, height, stat)
        class(wx_bitmap), intent(in) :: self
        real(c_double), intent(out) :: width, height
        integer, intent(out), optional :: stat
        width = 0
        height = 0
        call wx_check(wxf_bitmap_get_size(self%h, width, height), stat)
    end subroutine wx_bitmap_get_size

    !> Save the bitmap (at full resolution) as a PNG file.
    subroutine wx_bitmap_save_png(self, filename, stat)
        class(wx_bitmap), intent(in) :: self
        character(len=*), intent(in) :: filename
        integer, intent(out), optional :: stat
        call wx_check(wxf_bitmap_save_png(self%h, filename, len(filename, c_int)), stat)
    end subroutine wx_bitmap_save_png

    !> Free the bitmap; its handle becomes invalid.
    subroutine wx_bitmap_destroy(self, stat)
        class(wx_bitmap), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_bitmap_destroy(self%h), stat)
    end subroutine wx_bitmap_destroy

    ! -------------------------------------------------------------------------
    ! images

    !> Draw an image offscreen with `draw` (a paint handler, called once,
    !> with `data`), on a `width` x `height` area filled with `background`
    !> (default white), and save it as a PNG file. Needs `wx_app` but no window.
    subroutine wx_render_png(filename, width, height, draw, data, background, stat)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: width, height
        procedure(wx_event_handler) :: draw
        class(*), intent(inout), target, optional :: data
        type(wx_color), intent(in), optional :: background
        integer, intent(out), optional :: stat
        type(wx_color) :: bg
        integer :: slot
        integer(c_int) :: status
        bg = wxWHITE
        if (present(background)) bg = background
        slot = wx_events_slot_new(draw, data)
        status = wxf_render_png(int(width, c_int), int(height, c_int), int(bg%r, c_int), int(bg%g, c_int), &
                                int(bg%b, c_int), int(bg%a, c_int), filename, len(filename, c_int), &
                                int(slot, c_int))
        call wx_events_slot_free(slot)
        call wx_check(status, stat)
    end subroutine wx_render_png

    !> Read an image file (PNG, JPEG, ...) as 8-bit RGB: `rgb(c, x, y)` is
    !> channel `c` (1 red, 2 green, 3 blue, 0-255) of pixel (x, y), from the
    !> top-left (1, 1).
    subroutine wx_image_read_rgb(filename, rgb, stat)
        character(len=*), intent(in) :: filename
        integer, allocatable, intent(out) :: rgb(:,:,:)
        integer, intent(out), optional :: stat
        type(c_ptr) :: p
        integer(c_int) :: w, h, status
        integer(c_int8_t), pointer :: bytes(:,:,:)
        status = wxf_image_read_rgb(filename, len(filename, c_int), w, h, p)
        if (status == WX_OK) then
            allocate(rgb(3, w, h))
            if (w > 0 .and. h > 0) then
                call c_f_pointer(p, bytes, [3, int(w), int(h)])
                rgb = iand(int(bytes), 255)
            end if
            call wxf_free(p)
        else
            allocate(rgb(3, 0, 0))
        end if
        call wx_check(status, stat)
    end subroutine wx_image_read_rgb

end module wx_graphics_mod

!> Private `bind(C)` interfaces to the drawing part of the C++ shim
!> (src/shim/wxf_graphics.cpp), and its constants.
module wx_c_graphics

    use iso_c_binding
    implicit none
    private

    ! pen styles: must match the enum in src/shim/wxf_graphics.cpp
    integer(c_int), parameter, public :: wxPENSTYLE_SOLID = 0       !! continuous line
    integer(c_int), parameter, public :: wxPENSTYLE_DOT = 1         !! dotted line
    integer(c_int), parameter, public :: wxPENSTYLE_LONG_DASH = 2   !! long dashes
    integer(c_int), parameter, public :: wxPENSTYLE_SHORT_DASH = 3  !! short dashes

    ! font families: must match the enum in src/shim/wxf_graphics.cpp
    integer(c_int), parameter, public :: wxFONTFAMILY_DEFAULT = 0   !! the platform's default font
    integer(c_int), parameter, public :: wxFONTFAMILY_SWISS = 1     !! sans-serif
    integer(c_int), parameter, public :: wxFONTFAMILY_ROMAN = 2     !! serif
    integer(c_int), parameter, public :: wxFONTFAMILY_TELETYPE = 3  !! monospaced

    public :: wxf_canvas_create, wxf_canvas_save_png, wxf_render_png, wxf_image_read_rgb
    public :: wxf_gc_set_pen, wxf_gc_set_brush, wxf_gc_set_font, wxf_gc_stroke_line
    public :: wxf_gc_stroke_lines, wxf_gc_draw_polygon, wxf_gc_draw_rectangle
    public :: wxf_gc_draw_ellipse, wxf_gc_draw_text, wxf_gc_get_text_extent, wxf_gc_clip
    public :: wxf_gc_reset_clip, wxf_gc_push_state, wxf_gc_pop_state, wxf_gc_translate
    public :: wxf_gc_scale, wxf_gc_rotate, wxf_gc_set_antialias

    interface

        !> Create a canvas.
        function wxf_canvas_create(parent, out) &
                bind(C, name='wxf_canvas_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_canvas_create

        !> Draw a canvas into a PNG file.
        function wxf_canvas_save_png(h, path, len_path) &
                bind(C, name='wxf_canvas_save_png') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), value :: len_path
            integer(c_int) :: r
        end function wxf_canvas_save_png

        !> Draw with slot `slot` into a new PNG file.
        function wxf_render_png(w, h, red, green, blue, alpha, path, len_path, slot) &
                bind(C, name='wxf_render_png') result(r)
            import :: c_char, c_int
            implicit none
            integer(c_int), value :: w
            integer(c_int), value :: h
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), value :: len_path
            integer(c_int), value :: slot
            integer(c_int) :: r
        end function wxf_render_png

        !> Read an image as RGB bytes (malloc'd).
        function wxf_image_read_rgb(path, len_path, w, h, rgb) &
                bind(C, name='wxf_image_read_rgb') result(r)
            import :: c_char, c_int, c_ptr
            implicit none
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), value :: len_path
            integer(c_int), intent(out) :: w
            integer(c_int), intent(out) :: h
            type(c_ptr), intent(out) :: rgb
            integer(c_int) :: r
        end function wxf_image_read_rgb

        !> Set the outline pen.
        function wxf_gc_set_pen(gc, red, green, blue, alpha, width, style) &
                bind(C, name='wxf_gc_set_pen') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            real(c_double), value :: width
            integer(c_int), value :: style
            integer(c_int) :: r
        end function wxf_gc_set_pen

        !> Set the fill brush.
        function wxf_gc_set_brush(gc, red, green, blue, alpha, none) &
                bind(C, name='wxf_gc_set_brush') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            integer(c_int), value :: none
            integer(c_int) :: r
        end function wxf_gc_set_brush

        !> Set the text font and color.
        function wxf_gc_set_font(gc, size, family, bold, italic, red, green, blue, alpha) &
                bind(C, name='wxf_gc_set_font') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: size
            integer(c_int), value :: family
            integer(c_int), value :: bold
            integer(c_int), value :: italic
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            integer(c_int) :: r
        end function wxf_gc_set_font

        !> Draw a line.
        function wxf_gc_stroke_line(gc, x1, y1, x2, y2) &
                bind(C, name='wxf_gc_stroke_line') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: x1
            real(c_double), value :: y1
            real(c_double), value :: x2
            real(c_double), value :: y2
            integer(c_int) :: r
        end function wxf_gc_stroke_line

        !> Draw a polyline.
        function wxf_gc_stroke_lines(gc, x, y, n) &
                bind(C, name='wxf_gc_stroke_lines') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), intent(in) :: x(*)
            real(c_double), intent(in) :: y(*)
            integer(c_int), value :: n
            integer(c_int) :: r
        end function wxf_gc_stroke_lines

        !> Draw a filled polygon.
        function wxf_gc_draw_polygon(gc, x, y, n) &
                bind(C, name='wxf_gc_draw_polygon') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), intent(in) :: x(*)
            real(c_double), intent(in) :: y(*)
            integer(c_int), value :: n
            integer(c_int) :: r
        end function wxf_gc_draw_polygon

        !> Draw a rectangle.
        function wxf_gc_draw_rectangle(gc, x, y, w, h, radius) &
                bind(C, name='wxf_gc_draw_rectangle') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: x
            real(c_double), value :: y
            real(c_double), value :: w
            real(c_double), value :: h
            real(c_double), value :: radius
            integer(c_int) :: r
        end function wxf_gc_draw_rectangle

        !> Draw an ellipse.
        function wxf_gc_draw_ellipse(gc, x, y, w, h) &
                bind(C, name='wxf_gc_draw_ellipse') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: x
            real(c_double), value :: y
            real(c_double), value :: w
            real(c_double), value :: h
            integer(c_int) :: r
        end function wxf_gc_draw_ellipse

        !> Draw text.
        function wxf_gc_draw_text(gc, s, len_s, x, y, angle) &
                bind(C, name='wxf_gc_draw_text') result(r)
            import :: c_char, c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            real(c_double), value :: x
            real(c_double), value :: y
            real(c_double), value :: angle
            integer(c_int) :: r
        end function wxf_gc_draw_text

        !> Size of a text.
        function wxf_gc_get_text_extent(gc, s, len_s, w, h) &
                bind(C, name='wxf_gc_get_text_extent') result(r)
            import :: c_char, c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            real(c_double), intent(out) :: w
            real(c_double), intent(out) :: h
            integer(c_int) :: r
        end function wxf_gc_get_text_extent

        !> Clip to a rectangle.
        function wxf_gc_clip(gc, x, y, w, h) &
                bind(C, name='wxf_gc_clip') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: x
            real(c_double), value :: y
            real(c_double), value :: w
            real(c_double), value :: h
            integer(c_int) :: r
        end function wxf_gc_clip

        !> Remove the clip.
        function wxf_gc_reset_clip(gc) &
                bind(C, name='wxf_gc_reset_clip') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int) :: r
        end function wxf_gc_reset_clip

        !> Save the drawing state.
        function wxf_gc_push_state(gc) &
                bind(C, name='wxf_gc_push_state') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int) :: r
        end function wxf_gc_push_state

        !> Restore the drawing state.
        function wxf_gc_pop_state(gc) &
                bind(C, name='wxf_gc_pop_state') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int) :: r
        end function wxf_gc_pop_state

        !> Translate the coordinates.
        function wxf_gc_translate(gc, dx, dy) &
                bind(C, name='wxf_gc_translate') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: dx
            real(c_double), value :: dy
            integer(c_int) :: r
        end function wxf_gc_translate

        !> Scale the coordinates.
        function wxf_gc_scale(gc, sx, sy) &
                bind(C, name='wxf_gc_scale') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: sx
            real(c_double), value :: sy
            integer(c_int) :: r
        end function wxf_gc_scale

        !> Rotate the coordinates.
        function wxf_gc_rotate(gc, angle) &
                bind(C, name='wxf_gc_rotate') result(r)
            import :: c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            real(c_double), value :: angle
            integer(c_int) :: r
        end function wxf_gc_rotate

        !> Turn anti-aliasing on or off.
        function wxf_gc_set_antialias(gc, on) &
                bind(C, name='wxf_gc_set_antialias') result(r)
            import :: c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int), value :: on
            integer(c_int) :: r
        end function wxf_gc_set_antialias

    end interface

end module wx_c_graphics

!> Tests of bitmaps (from arrays and files, high-DPI scale, drawing, saving,
!> lifetime), mouse capture, cursors, the busy cursor, the content scale
!> factor and right-button events. No user interaction needed.
module test_input_handlers

    use wx
    use iso_c_binding, only: c_double
    implicit none

    type(wx_bitmap), save :: shared   !! drawn by `draw_shared`
    integer, save :: right_ups = 0

contains

    !> Draw the shared bitmap at its logical size, and scaled.
    subroutine draw_shared(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        g = wx_graphics(event)
        call g%draw_bitmap(shared, 0.0_c_double, 0.0_c_double)
        call g%draw_bitmap(shared, 20.0_c_double, 0.0_c_double, 20.0_c_double, 20.0_c_double)
    end subroutine draw_shared

    !> Count right-button releases.
    subroutine on_right_up(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: x, y
        call event%get_position(x, y)
        if (x == 7 .and. y == 8) right_ups = right_ups + 1
    end subroutine on_right_up

end module test_input_handlers


!> Runs the bitmap and input tests.
program test_input

    use wx
    use testing
    use test_input_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_canvas) :: canvas
    type(wx_bitmap) :: b, from_file, bad
    integer, allocatable :: img(:,:,:), rgb(:,:,:)
    real(c_double) :: w, h, scale
    integer :: stat, base_objects, unit, i, j
    character(len=*), parameter :: png = 'test_input_bitmap.png', png2 = 'test_input_drawn.png'

    app = wx_app()
    base_objects = wx_live_objects()

    ! a 20x20 image: red left half, blue right half
    allocate(img(3, 20, 20))
    do j = 1, 20
        do i = 1, 20
            img(:, i, j) = merge([255, 0, 0], [0, 0, 255], i <= 10)
        end do
    end do

    ! --- bitmaps
    b = wx_bitmap(img)
    call b%get_size(w, h)
    call check(b%is_valid() .and. w == 20 .and. h == 20, 'bitmap from an RGB array')
    shared = wx_bitmap(img, scale=2.0_c_double)
    call shared%get_size(w, h)
    call check(w == 10 .and. h == 10, 'scale 2: logical size is half the pixels')
    call shared%save_png(png)
    from_file = wx_bitmap(png)
    call from_file%get_size(w, h)
    call check(w == 20 .and. h == 20, 'saved at full resolution; reloaded from the file')
    call wx_render_png(png2, 40, 20, draw_shared)
    call wx_image_read_rgb(png2, rgb)
    call check(all(rgb(:, 2, 5) == [255, 0, 0]) .and. all(rgb(:, 8, 5) == [0, 0, 255]), &
               'drawn at its logical size (10 x 10)')
    call check(all(rgb(:, 15, 5) == [255, 255, 255]), '... leaving the rest of its 20-pixel box empty')
    call check(all(rgb(:, 25, 15) == [255, 0, 0]) .and. all(rgb(:, 35, 15) == [0, 0, 255]), &
               'drawn scaled into a 20 x 20 box')
    bad = wx_bitmap(reshape([1, 2], [2, 1, 1]), stat=stat)
    call check(stat == WX_ERR_ARGUMENT .and. .not. bad%is_valid(), 'rgb must have 3 channels')
    bad = wx_bitmap(img, scale=0.0_c_double, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'scale must be positive')
    bad = wx_bitmap('/nonexistent.png', stat=stat)
    call check(stat == WX_ERR_FAILED .and. .not. bad%is_valid(), 'missing image file fails')
    call b%destroy()
    call check(.not. b%is_valid(), 'destroyed bitmap is invalid')
    call b%save_png(png, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'using a destroyed bitmap fails cleanly')
    call check(wx_live_objects() == base_objects + 2, 'live bitmaps counted')

    ! --- window input helpers
    frame = wx_frame('input', width=300, height=200)
    canvas = wx_canvas(frame)
    call frame%show()
    call app%process_pending()
    scale = canvas%get_content_scale_factor()
    call check(scale >= 1, 'content scale factor is at least 1')
    call canvas%set_cursor(WX_CURSOR_CROSS)
    call canvas%set_cursor(WX_CURSOR_ARROW)
    call canvas%set_cursor(99, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'unknown cursor rejected')
    call wx_begin_busy_cursor()
    call wx_begin_busy_cursor()
    call wx_end_busy_cursor()
    call wx_end_busy_cursor()
    call wx_end_busy_cursor()   ! one too many: harmless
    call check(.true., 'busy cursor begin/end (nested)')
    call canvas%capture_mouse()
    call check(canvas%has_capture(), 'mouse captured')
    call canvas%capture_mouse()   ! again: harmless
    call canvas%release_mouse()
    call check(.not. canvas%has_capture(), 'mouse released')
    call canvas%release_mouse()   ! again: harmless
    call canvas%bind(wxEVT_RIGHT_UP, on_right_up)
    call canvas%emit_mouse(wxEVT_RIGHT_UP, 7, 8)
    call check(right_ups == 1, 'wxEVT_RIGHT_UP delivered')
    call canvas%bind(wxEVT_MOUSE_CAPTURE_LOST, on_right_up, stat=stat)
    call check(stat == WX_OK, 'capture-lost handlers can be bound')

    ! --- cleanup deletes bitmaps nobody destroyed
    call frame%destroy()
    call app%process_pending()
    call app%cleanup()
    call check(.not. shared%is_valid() .and. .not. from_file%is_valid(), 'cleanup deletes remaining bitmaps')

    open(newunit=unit, file=png, status='old')
    close(unit, status='delete')
    open(newunit=unit, file=png2, status='old')
    close(unit, status='delete')

end program test_input

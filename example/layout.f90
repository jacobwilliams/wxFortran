!> Containers and layout: a toolbar, and a notebook with three tabs.
!>
!> * Form: a flex grid sizer (labels + growing fields) inside a static box.
!> * Image: a Mandelbrot set computed in Fortran, shown at its natural size
!>   in a wx_static_bitmap and scaled to fill a canvas with `g%draw_rgb`
!>   (the "Smooth" tool toggles interpolation; Open loads an image file).
!> * Split: a splitter with a list on the left and details on the right;
!>   drag the sash.
module layout_ui

    use wx
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: wp = c_double
    integer, parameter :: nx = 160, ny = 120    !! image size

    !> The window and its state.
    type :: layout_t
        type(wx_frame) :: frame
        type(wx_notebook) :: book
        type(wx_tool_bar) :: tools
        type(wx_static_bitmap) :: view
        type(wx_canvas) :: canvas
        type(wx_text_ctrl) :: name, email, notes
        type(wx_static_text) :: details
        type(wx_list_box) :: list
        integer :: id_smooth = 0
        integer, allocatable :: rgb(:,:,:)
    end type layout_t

contains

    !> A Mandelbrot set as an RGB image.
    function mandelbrot() result(rgb)
        integer, allocatable :: rgb(:,:,:)
        integer :: i, j, k
        complex(wp) :: c, z
        real(wp) :: t
        allocate(rgb(3, nx, ny))
        do j = 1, ny
            do i = 1, nx
                c = cmplx(-2.2_wp + 3.0_wp*(i - 1)/(nx - 1), -1.2_wp + 2.4_wp*(j - 1)/(ny - 1), wp)
                z = 0
                do k = 1, 60
                    z = z*z + c
                    if (abs(z) > 2) exit
                end do
                if (k > 60) then
                    rgb(:, i, j) = [10, 10, 30]
                else
                    t = real(k, wp) / 60
                    rgb(:, i, j) = [nint(255*t), nint(255*sqrt(t)), nint(255*(1 - t))]
                end if
            end do
        end do
    end function mandelbrot

    !> Draw the image scaled to fill the canvas.
    subroutine on_paint(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        select type (s => data)
        type is (layout_t)
            g = wx_graphics(event)
            call g%draw_rgb(s%rgb, 0.0_wp, 0.0_wp, g%width, g%height, smooth=s%tools%get_tool_state(s%id_smooth))
            call g%set_font(10.0_wp, wxWHITE, bold=.true.)
            call g%draw_text('draw_rgb on a canvas (resize the window)', 8.0_wp, 6.0_wp)
        end select
    end subroutine on_paint

    !> Toolbar: Smooth toggles interpolation.
    subroutine on_smooth(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (layout_t)
            call s%canvas%refresh()
            call s%frame%set_status_text(merge('Smooth scaling   ', 'Pixelated scaling', event%is_checked()))
        end select
    end subroutine on_smooth

    !> Toolbar / File > Open: load an image into the Image tab.
    subroutine on_open(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(wx_window) :: page
        integer :: stat
        select type (s => data)
        type is (layout_t)
            if (.not. wx_file_open_dialog(path, wildcard='Images (*.png;*.jpg)|*.png;*.jpg|All files (*.*)|*.*', &
                                          parent=s%frame)) return
            call wx_image_read_rgb(path, s%rgb, stat=stat)
            if (stat /= WX_OK) then
                call s%frame%set_status_text('Could not read '//path)
                s%rgb = mandelbrot()
                return
            end if
            call s%view%set_rgb(s%rgb)
            call s%book%set_selection(2)
            page = s%book%get_page(2)
            call page%layout()
            call s%canvas%refresh()
            call s%frame%set_status_text('Loaded '//path)
        end select
    end subroutine on_open

    !> Toolbar / File > Save: save the image shown as PNG.
    subroutine on_save(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        select type (s => data)
        type is (layout_t)
            if (wx_file_save_dialog(path, default_file='image.png', wildcard='PNG (*.png)|*.png', &
                                    parent=s%frame)) then
                call s%canvas%save_png(path)
                call s%frame%set_status_text('Saved '//path)
            end if
        end select
    end subroutine on_save

    !> Form: Submit.
    subroutine on_submit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: button
        select type (s => data)
        type is (layout_t)
            button = wx_message_box('Name: '//s%name%get_value()//new_line('a')// &
                                    'Email: '//s%email%get_value()//new_line('a')// &
                                    'Notes: '//s%notes%get_value(), 'Form contents', &
                                    ior(wxOK, wxICON_INFORMATION), parent=s%frame)
        end select
    end subroutine on_submit

    !> Split: show the selected item on the right.
    subroutine on_pick(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=16) :: buf
        select type (s => data)
        type is (layout_t)
            write(buf, '(I0)') event%get_selection()
            call s%details%set_label('Item '//trim(buf)//': '//event%get_string())
        end select
    end subroutine on_pick

    !> Notebook: report the tab shown.
    subroutine on_page(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (layout_t)
            call s%frame%set_status_text('Tab: '//s%book%get_page_text(event%get_selection()), field=1)
        end select
    end subroutine on_page

    !> File > Quit.
    subroutine on_quit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (layout_t)
            if (s%frame%close()) continue
        end select
    end subroutine on_quit

end module layout_ui


!> Builds the window and runs it.
program layout

    use wx
    use layout_ui
    implicit none

    type(wx_app) :: app
    type(layout_t), target :: s
    type(wx_panel) :: form_page, image_page, left, right
    type(wx_splitter_window) :: split
    type(wx_flex_grid_sizer) :: grid
    type(wx_static_box_sizer) :: box
    type(wx_box_sizer) :: form_sizer, image_sizer, left_sizer, right_sizer, frame_sizer
    type(wx_window) :: inbox
    type(wx_button) :: submit
    type(wx_menu_bar) :: bar
    type(wx_menu) :: file_menu
    integer :: id, i
    character(len=12) :: items(20)

    app = wx_app()
    s%frame = wx_frame('wxFortran layout', width=760, height=540)
    s%rgb = mandelbrot()

    ! --- menu and toolbar (tools with stock ids share the menu handlers)
    bar = wx_menu_bar()
    file_menu = wx_menu()
    id = file_menu%append(id=wxID_OPEN)
    id = file_menu%append(id=wxID_SAVE)
    call file_menu%append_separator()
    id = file_menu%append(id=wxID_EXIT)
    call bar%append(file_menu, '&File')
    call s%frame%set_menu_bar(bar)
    s%tools = wx_tool_bar(s%frame, text=.true.)
    id = s%tools%add_tool('Open', art='wxART_FILE_OPEN', help='Open an image', id=wxID_OPEN)
    id = s%tools%add_tool('Save', art='wxART_FILE_SAVE', help='Save the canvas as PNG', id=wxID_SAVE)
    call s%tools%add_separator()
    s%id_smooth = s%tools%add_tool('Smooth', art='wxART_TIP', help='Interpolate when scaling', kind=wxITEM_CHECK)
    call s%frame%bind(wxEVT_MENU, on_open, data=s, id=wxID_OPEN)
    call s%frame%bind(wxEVT_MENU, on_save, data=s, id=wxID_SAVE)
    call s%frame%bind(wxEVT_MENU, on_quit, data=s, id=wxID_EXIT)
    call s%frame%bind(wxEVT_TOOL, on_smooth, data=s, id=s%id_smooth)
    call s%frame%create_status_bar(2)
    call s%frame%set_status_text('Ready')

    s%book = wx_notebook(s%frame)
    frame_sizer = wx_box_sizer(wxVERTICAL)
    call frame_sizer%add(s%book, proportion=1, flags=wxEXPAND)
    call s%frame%set_sizer(frame_sizer)

    ! --- tab 1: a form in a static box, laid out with a flex grid sizer
    form_page = wx_panel(s%book)
    box = wx_static_box_sizer(wxVERTICAL, form_page, 'Contact')
    inbox = box%get_static_box()
    grid = wx_flex_grid_sizer(2, vgap=8, hgap=10)
    s%name = wx_text_ctrl(inbox)
    s%email = wx_text_ctrl(inbox)
    s%notes = wx_text_ctrl(inbox, style=wxTE_MULTILINE)
    call grid%add(wx_static_text(inbox, 'Name:'), flags=wxALIGN_RIGHT)
    call grid%add(s%name, flags=wxEXPAND)
    call grid%add(wx_static_text(inbox, 'Email:'), flags=wxALIGN_RIGHT)
    call grid%add(s%email, flags=wxEXPAND)
    call grid%add(wx_static_text(inbox, 'Notes:'), flags=wxALIGN_RIGHT)
    call grid%add(s%notes, flags=wxEXPAND)
    call grid%add_growable_col(2)
    call grid%add_growable_row(3)
    call box%add(grid, proportion=1, flags=ior(wxEXPAND, wxALL), border=10)
    submit = wx_button(form_page, 'Submit')
    call submit%bind(wxEVT_BUTTON, on_submit, data=s)
    form_sizer = wx_box_sizer(wxVERTICAL)
    call form_sizer%add(box, proportion=1, flags=ior(wxEXPAND, wxALL), border=12)
    call form_sizer%add(submit, flags=ior(wxALIGN_RIGHT, ior(wxRIGHT, wxBOTTOM)), border=12)
    call form_page%set_sizer(form_sizer)
    call s%book%add_page(form_page, 'Form')

    ! --- tab 2: the image, at its size and scaled on a canvas
    image_page = wx_panel(s%book)
    s%view = wx_static_bitmap(image_page)
    call s%view%set_rgb(s%rgb)
    s%canvas = wx_canvas(image_page)
    call s%canvas%bind(wxEVT_PAINT, on_paint, data=s)
    image_sizer = wx_box_sizer(wxHORIZONTAL)
    call image_sizer%add(s%view, flags=wxALL, border=10)
    call image_sizer%add(s%canvas, proportion=1, flags=ior(wxEXPAND, wxALL), border=10)
    call image_page%set_sizer(image_sizer)
    call s%book%add_page(image_page, 'Image')

    ! --- tab 3: a splitter
    split = wx_splitter_window(s%book)
    left = wx_panel(split)
    right = wx_panel(split)
    do i = 1, size(items)
        write(items(i), '(A,I0)') 'Item ', i
    end do
    s%list = wx_list_box(left, items)
    call s%list%bind(wxEVT_LISTBOX, on_pick, data=s)
    left_sizer = wx_box_sizer(wxVERTICAL)
    call left_sizer%add(s%list, proportion=1, flags=wxEXPAND)
    call left%set_sizer(left_sizer)
    s%details = wx_static_text(right, 'Select an item on the left. Drag the sash to resize.')
    right_sizer = wx_box_sizer(wxVERTICAL)
    call right_sizer%add(s%details, flags=wxALL, border=12)
    call right%set_sizer(right_sizer)
    call split%split_vertically(left, right, position=200)
    call split%set_sash_gravity(0.3d0)
    call s%book%add_page(split, 'Split')

    call s%book%bind(wxEVT_NOTEBOOK_PAGE_CHANGED, on_page, data=s)
    call s%frame%center()
    call s%frame%show()

    stop app%run()

end program layout

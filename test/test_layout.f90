!> Layout tests: notebook pages and events (including a vetoed change and a
!> page deleted from its own handler), splitter panes, grid / flex grid /
!> static box sizers, toolbar tools and their events, image views, and
!> drawing RGB arrays and image files on a graphics context. No user
!> interaction needed.
module test_layout_handlers

    use wx
    use iso_c_binding, only: c_double
    implicit none

    !> What the handlers saw.
    type :: seen_t
        integer :: changing = 0, changed = 0
        integer :: last_page = -1
        logical :: veto = .false.
        integer :: tool_calls = 0, tool_id = 0
        logical :: tool_checked = .false.
        type(wx_notebook) :: book
    end type seen_t

    integer, parameter :: quad(3, 2, 2) = reshape([255, 0, 0,   0, 255, 0, &
                                                   0, 0, 255,   255, 255, 0], [3, 2, 2])

contains

    !> Notebook events: count, record the page, and veto if asked.
    subroutine on_page(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (seen_t)
            s%last_page = event%get_selection()
            if (event%kind() == wxEVT_NOTEBOOK_PAGE_CHANGING) then
                s%changing = s%changing + 1
                if (s%veto .and. event%can_veto()) call event%veto()
            else
                s%changed = s%changed + 1
            end if
        end select
    end subroutine on_page

    !> Tool clicks.
    subroutine on_tool(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (seen_t)
            s%tool_calls = s%tool_calls + 1
            s%tool_id = event%get_id()
            s%tool_checked = event%is_checked()
        end select
    end subroutine on_tool

    !> A button on page 2 that deletes its own page.
    subroutine delete_my_page(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (seen_t)
            call s%book%delete_page(2)
        end select
    end subroutine delete_my_page

    !> Draw the 2x2 test image scaled up, and an image file.
    subroutine draw_images(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        g = wx_graphics(event)
        call g%draw_rgb(quad, 0.0_c_double, 0.0_c_double, 40.0_c_double, 40.0_c_double)
        if (present(data)) then
            select type (data)
            type is (character(len=*))
                call g%draw_image_file(data, 50.0_c_double, 0.0_c_double, 20.0_c_double, 20.0_c_double)
            end select
        end if
    end subroutine draw_images

end module test_layout_handlers


!> Runs the layout tests.
program test_layout

    use wx
    use testing
    use test_layout_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_panel) :: p1, p2, p3, left, right, stray, panel
    type(wx_window) :: w
    type(wx_button) :: killer
    type(wx_splitter_window) :: split
    type(wx_grid_sizer) :: grid
    type(wx_flex_grid_sizer) :: form
    type(wx_static_box_sizer) :: box
    type(wx_box_sizer) :: other
    type(wx_static_text) :: cells(6), label
    type(wx_text_ctrl) :: field
    type(wx_check_box) :: inside
    type(wx_tool_bar) :: tb, tb2
    type(wx_choice) :: tool_choice
    type(wx_static_bitmap) :: view
    type(seen_t), target :: seen
    integer, allocatable :: rgb(:,:,:)
    integer :: stat, id_open, id_grid, id_x, x1, y1, x4, y4, w1, h1, w2, h2, base_handlers, base_objects, unit
    character(len=*), parameter :: png = 'test_layout_quad.png', png2 = 'test_layout_both.png'
    character(len=len(png)), target :: png_name = png

    app = wx_app()
    base_handlers = wx_active_handlers()
    base_objects = wx_live_objects()
    frame = wx_frame('layout', width=600, height=400)

    ! --- notebook
    seen%book = wx_notebook(frame)
    p1 = wx_panel(seen%book)
    p2 = wx_panel(seen%book)
    p3 = wx_panel(seen%book)
    call seen%book%add_page(p1, 'One')
    call seen%book%add_page(p2, 'Two')
    call seen%book%add_page(p3, 'Three')
    call check(seen%book%page_count() == 3, 'three pages')
    call check(seen%book%get_selection() == 1, 'the first page is shown')
    call check(seen%book%get_page(2) == p2, 'get_page')
    call check(seen%book%get_page_text(3) == 'Three', 'page text')
    call seen%book%set_page_text(3, 'Drei')
    call check(seen%book%get_page_text(3) == 'Drei', 'set_page_text')
    stray = wx_panel(frame)
    call seen%book%add_page(stray, 'Stray', stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a page must be a child of the notebook')
    call seen%book%add_page(p2, 'Again', stat=stat)
    call check(stat == WX_ERR_STATE, 'a page cannot be added twice')
    call seen%book%bind(wxEVT_NOTEBOOK_PAGE_CHANGING, on_page, data=seen)
    call seen%book%bind(wxEVT_NOTEBOOK_PAGE_CHANGED, on_page, data=seen)
    call seen%book%set_selection(2)
    call check(seen%book%get_selection() == 2 .and. seen%changing + seen%changed == 0, 'set_selection sends no events')
    call seen%book%emit_select(3)
    call check(seen%changing == 1 .and. seen%changed == 1 .and. seen%last_page == 3, 'changing then changed, new page')
    call check(seen%book%get_selection() == 3, 'page 3 shown')
    seen%veto = .true.
    call seen%book%emit_select(1)
    call check(seen%changing == 2 .and. seen%changed == 1, 'vetoed change: no changed event')
    call check(seen%book%get_selection() == 3, 'vetoed change keeps the page')
    seen%veto = .false.
    call seen%book%set_selection(9, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'page index out of range')
    ! a page deleted from a handler of one of its own controls
    killer = wx_button(p2, 'Delete this page')
    call killer%bind(wxEVT_BUTTON, delete_my_page, data=seen)
    call killer%emit_click()
    call check(seen%book%page_count() == 2 .and. .not. p2%is_valid(), 'page deleted from its own handler')
    call app%process_pending()
    call check(.not. killer%is_valid(), '... and its controls destroyed afterwards')
    call seen%book%delete_page(2)
    call check(seen%book%page_count() == 1 .and. .not. p3%is_valid(), 'delete_page destroys the page')
    call seen%book%destroy()
    call app%process_pending()

    ! --- splitter
    split = wx_splitter_window(frame)
    call split%set_size(500, 300)
    left = wx_panel(split)
    right = wx_panel(split)
    call split%split_vertically(left, right, position=150)
    call check(split%is_split(), 'split')
    call check(split%get_sash_position() == 150, 'initial sash position')
    call split%set_sash_position(200)
    call check(split%get_sash_position() == 200, 'set_sash_position')
    call split%unsplit()
    call check(.not. split%is_split() .and. .not. right%is_shown() .and. right%is_valid(), &
               'unsplit hides (not destroys) pane 2')
    call split%split_horizontally(left, right)
    call check(split%is_split() .and. right%is_shown(), 'split again, horizontally')
    call split%initialize(right)
    call check(.not. split%is_split() .and. right%is_shown(), 'initialize: one pane')
    call split%split_vertically(left, stray, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'panes must be children of the splitter')
    call split%split_vertically(left, left, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'panes must differ')
    call split%set_sash_gravity(2.0d0, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'gravity outside 0..1 rejected')
    call split%set_sash_gravity(0.5d0)
    call split%set_minimum_pane_size(50)
    call split%destroy()
    call stray%destroy()

    ! --- grid sizer: 3 columns
    panel = wx_panel(frame)
    call panel%set_size(600, 400)
    grid = wx_grid_sizer(3, vgap=5, hgap=5)
    do x1 = 1, 6
        cells(x1) = wx_static_text(panel, 'cell')
        call grid%add(cells(x1))
    end do
    call check(grid%item_count() == 6, 'grid sizer items')
    call panel%set_sizer(grid)
    call panel%layout()
    call cells(1)%get_position(x1, y1)
    call cells(4)%get_position(x4, y4)
    call check(x4 == x1 .and. y4 > y1, 'item 4 starts the second row')
    grid = wx_grid_sizer(0, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a grid sizer needs columns')

    ! --- flex grid sizer: a form whose second column grows
    form = wx_flex_grid_sizer(2, hgap=8)
    label = wx_static_text(panel, 'Name:')
    field = wx_text_ctrl(panel)
    call form%add(label)
    call form%add(field, flags=wxEXPAND)
    call form%add_growable_col(2)
    call form%add_growable_col(3, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'growable column out of range')
    call panel%set_sizer(form)
    call panel%layout()
    call label%get_size(w1, h1)
    call field%get_size(w2, h2)
    call check(w2 > 400 .and. w2 > 3*w1, 'growable column stretches the field')

    ! --- static box sizer
    box = wx_static_box_sizer(wxVERTICAL, panel, 'Options')
    w = box%get_static_box()
    call check(w%is_valid(), 'static box window')
    inside = wx_check_box(w, 'inside the box')
    call box%add(inside, flags=wxALL, border=5)
    call panel%set_sizer(box)
    call panel%layout()
    call check(inside%get_parent() == w, 'control parented to the box')
    other = wx_box_sizer(wxVERTICAL)
    call panel%set_sizer(other)
    call check(.not. box%is_valid() .and. .not. w%is_valid(), 'replaced static box sizer destroys its box')
    call panel%destroy()

    ! --- toolbar
    tb = wx_tool_bar(frame, text=.true.)
    id_open = tb%add_tool('Open', art='wxART_FILE_OPEN', help='Open a file', id=wxID_OPEN)
    id_grid = tb%add_tool('Grid', art='wxART_LIST_VIEW', kind=wxITEM_CHECK)
    call tb%add_separator()
    call tb%add_stretch()
    tool_choice = wx_choice(tb, [character(len=6) :: 'fast', 'slow'])
    call tb%add_control(tool_choice)
    call check(id_open == wxID_OPEN .and. id_grid /= wxID_ANY, 'tool ids')
    call check(tb%tool_count() == 5, 'tool count (tools, separators, control)')
    id_x = tb%add_tool('Bad', art='wxART_NO_SUCH_ICON', stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'unknown art id rejected')
    id_x = tb%add_tool('Bad', file='/nonexistent.png', stat=stat)
    call check(stat == WX_ERR_FAILED, 'missing icon file fails')
    id_x = tb%add_tool('Dup', art='wxART_NEW', id=wxID_OPEN, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'duplicate tool id rejected')
    tb2 = wx_tool_bar(frame, stat=stat)
    call check(stat == WX_ERR_STATE, 'one toolbar per frame')
    call frame%bind(wxEVT_TOOL, on_tool, data=seen, id=wxID_OPEN)
    call frame%bind(wxEVT_MENU, on_tool, data=seen, id=id_grid)
    call tb%emit_click(id_open)
    call check(seen%tool_calls == 1 .and. seen%tool_id == wxID_OPEN, 'tool click reaches the frame')
    call tb%emit_click(id_grid)
    call check(seen%tool_calls == 2 .and. seen%tool_checked .and. tb%get_tool_state(id_grid), 'check tool on')
    call tb%emit_click(id_grid)
    call check(.not. seen%tool_checked .and. .not. tb%get_tool_state(id_grid), 'check tool off')
    call tb%toggle_tool(id_grid)
    call check(tb%get_tool_state(id_grid) .and. seen%tool_calls == 3, 'toggle_tool sends no event')
    call tb%toggle_tool(id_open, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a normal tool cannot be toggled')
    call tb%enable_tool(id_open, .false.)
    call check(.not. tb%is_tool_enabled(id_open), 'tool disabled')
    call tb%emit_click(id_open, stat=stat)
    call check(stat == WX_ERR_STATE .and. seen%tool_calls == 3, 'a disabled tool cannot be clicked')

    ! --- images: draw an RGB array, read it back, show it
    call wx_render_png(png, 40, 40, draw_images)
    call wx_image_read_rgb(png, rgb)
    write(*, '(A,4(3I4,2X))') 'draw_rgb pixels (10,10) (30,10) (10,30) (30,30):', &
        rgb(:, 10, 10), rgb(:, 30, 10), rgb(:, 10, 30), rgb(:, 30, 30)
    call check(all(rgb(:, 10, 10) == [255, 0, 0]) .and. all(rgb(:, 30, 10) == [0, 255, 0]), &
               'draw_rgb: top row of the scaled image')
    call check(all(rgb(:, 10, 30) == [0, 0, 255]) .and. all(rgb(:, 30, 30) == [255, 255, 0]), &
               'draw_rgb: bottom row, nearest-neighbor scaling')
    call wx_render_png(png2, 80, 40, draw_images, data=png_name)
    call wx_image_read_rgb(png2, rgb)
    write(*, '(A,2(3I4,2X))') 'draw_image_file pixels (55,5) (65,15):', rgb(:, 55, 5), rgb(:, 65, 15)
    call check(all(rgb(:, 55, 5) == [255, 0, 0]) .and. all(rgb(:, 65, 15) == [255, 255, 0]), &
               'draw_image_file scaled into its box')
    view = wx_static_bitmap(frame, file=png)
    call view%get_image_size(w1, h1)
    call check(w1 == 40 .and. h1 == 40, 'image view shows a file at its size')
    call view%set_rgb(quad)
    call view%get_image_size(w1, h1)
    call check(w1 == 2 .and. h1 == 2, 'image view shows an RGB array')
    call view%set_rgb(reshape([1, 2], [2, 1, 1]), stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'rgb array must have 3 channels')
    call view%load('/nonexistent.png', stat=stat)
    call check(stat == WX_ERR_FAILED, 'missing image file fails')

    ! --- teardown
    call frame%destroy()
    call app%process_pending()
    call check(.not. tb%is_valid() .and. .not. view%is_valid(), 'toolbar and image view destroyed with the frame')
    call check(wx_active_handlers() == base_handlers, 'handlers released')
    call check(wx_live_objects() == base_objects, 'no live objects left')
    open(newunit=unit, file=png, status='old')
    close(unit, status='delete')
    open(newunit=unit, file=png2, status='old')
    close(unit, status='delete')

end program test_layout

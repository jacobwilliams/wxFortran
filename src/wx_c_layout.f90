!> Private `bind(C)` interfaces to the containers and layout part of the
!> C++ shim (src/cpp/wxf_layout.cpp). Page indices are 1-based (0: none).
module wx_c_layout

    use iso_c_binding
    implicit none
    private

    public :: wxf_notebook_create, wxf_notebook_add_page, wxf_notebook_page_count
    public :: wxf_notebook_get_selection, wxf_notebook_set_selection, wxf_notebook_get_page
    public :: wxf_notebook_get_page_text, wxf_notebook_set_page_text, wxf_notebook_delete_page
    public :: wxf_splitter_create, wxf_splitter_split, wxf_splitter_initialize
    public :: wxf_splitter_unsplit, wxf_splitter_is_split, wxf_splitter_set_sash_position
    public :: wxf_splitter_get_sash_position, wxf_splitter_set_minimum_pane_size
    public :: wxf_splitter_set_sash_gravity, wxf_grid_sizer_create, wxf_flex_grid_add_growable
    public :: wxf_static_box_sizer_create, wxf_frame_create_tool_bar, wxf_tool_bar_add_tool
    public :: wxf_tool_bar_add_separator, wxf_tool_bar_add_control, wxf_tool_bar_tool_count
    public :: wxf_tool_bar_enable_tool, wxf_tool_bar_is_tool_enabled, wxf_tool_bar_toggle_tool
    public :: wxf_tool_bar_get_tool_state, wxf_tool_bar_emit_click, wxf_static_bitmap_create
    public :: wxf_static_bitmap_load, wxf_static_bitmap_set_rgb
    public :: wxf_static_bitmap_get_image_size, wxf_gc_draw_rgb, wxf_gc_draw_image_file

    interface

        !> Create a notebook.
        function wxf_notebook_create(parent, out) &
                bind(C, name='wxf_notebook_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_notebook_create

        !> Add a page.
        function wxf_notebook_add_page(h, page, text, len_text, select) &
                bind(C, name='wxf_notebook_add_page') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: page
            character(kind=c_char), intent(in) :: text(*)
            integer(c_int), value :: len_text
            integer(c_int), value :: select
            integer(c_int) :: r
        end function wxf_notebook_add_page

        !> Number of pages.
        function wxf_notebook_page_count(h, n) &
                bind(C, name='wxf_notebook_page_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_notebook_page_count

        !> The current page (0: none).
        function wxf_notebook_get_selection(h, i) &
                bind(C, name='wxf_notebook_get_selection') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: i
            integer(c_int) :: r
        end function wxf_notebook_get_selection

        !> Show a page.
        function wxf_notebook_set_selection(h, i, notify) &
                bind(C, name='wxf_notebook_set_selection') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int), value :: notify
            integer(c_int) :: r
        end function wxf_notebook_set_selection

        !> Handle of page i.
        function wxf_notebook_get_page(h, i, page) &
                bind(C, name='wxf_notebook_get_page') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int64_t), intent(out) :: page
            integer(c_int) :: r
        end function wxf_notebook_get_page

        !> Tab text of page i (malloc'd).
        function wxf_notebook_get_page_text(h, i, s, len) &
                bind(C, name='wxf_notebook_get_page_text') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_notebook_get_page_text

        !> Set the tab text of page i.
        function wxf_notebook_set_page_text(h, i, s, len_s) &
                bind(C, name='wxf_notebook_set_page_text') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            integer(c_int) :: r
        end function wxf_notebook_set_page_text

        !> Remove and destroy page i.
        function wxf_notebook_delete_page(h, i) &
                bind(C, name='wxf_notebook_delete_page') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int) :: r
        end function wxf_notebook_delete_page

        !> Create a splitter window.
        function wxf_splitter_create(parent, live, out) &
                bind(C, name='wxf_splitter_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int), value :: live
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_splitter_create

        !> Split into two panes.
        function wxf_splitter_split(h, first, second, vertical, pos) &
                bind(C, name='wxf_splitter_split') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: first
            integer(c_int64_t), value :: second
            integer(c_int), value :: vertical
            integer(c_int), value :: pos
            integer(c_int) :: r
        end function wxf_splitter_split

        !> Show a single pane.
        function wxf_splitter_initialize(h, window) &
                bind(C, name='wxf_splitter_initialize') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: window
            integer(c_int) :: r
        end function wxf_splitter_initialize

        !> Hide pane 1 or 2.
        function wxf_splitter_unsplit(h, which) &
                bind(C, name='wxf_splitter_unsplit') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: which
            integer(c_int) :: r
        end function wxf_splitter_unsplit

        !> Whether both panes show.
        function wxf_splitter_is_split(h, split) &
                bind(C, name='wxf_splitter_is_split') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: split
            integer(c_int) :: r
        end function wxf_splitter_is_split

        !> Move the sash.
        function wxf_splitter_set_sash_position(h, pos) &
                bind(C, name='wxf_splitter_set_sash_position') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: pos
            integer(c_int) :: r
        end function wxf_splitter_set_sash_position

        !> The sash position.
        function wxf_splitter_get_sash_position(h, pos) &
                bind(C, name='wxf_splitter_get_sash_position') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: pos
            integer(c_int) :: r
        end function wxf_splitter_get_sash_position

        !> Set the smallest pane size.
        function wxf_splitter_set_minimum_pane_size(h, size) &
                bind(C, name='wxf_splitter_set_minimum_pane_size') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: size
            integer(c_int) :: r
        end function wxf_splitter_set_minimum_pane_size

        !> Set the first pane's share of resizing.
        function wxf_splitter_set_sash_gravity(h, gravity) &
                bind(C, name='wxf_splitter_set_sash_gravity') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            real(c_double), value :: gravity
            integer(c_int) :: r
        end function wxf_splitter_set_sash_gravity

        !> Create a (flex) grid sizer.
        function wxf_grid_sizer_create(rows, cols, vgap, hgap, flex, out) &
                bind(C, name='wxf_grid_sizer_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int), value :: rows
            integer(c_int), value :: cols
            integer(c_int), value :: vgap
            integer(c_int), value :: hgap
            integer(c_int), value :: flex
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_grid_sizer_create

        !> Make a row or column growable.
        function wxf_flex_grid_add_growable(h, i, proportion, col) &
                bind(C, name='wxf_flex_grid_add_growable') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int), value :: proportion
            integer(c_int), value :: col
            integer(c_int) :: r
        end function wxf_flex_grid_add_growable

        !> Create a static box sizer.
        function wxf_static_box_sizer_create(orient, parent, label, len_label, out, box) &
                bind(C, name='wxf_static_box_sizer_create') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int), value :: orient
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len_label
            integer(c_int64_t), intent(out) :: out
            integer(c_int64_t), intent(out) :: box
            integer(c_int) :: r
        end function wxf_static_box_sizer_create

        !> Give a frame a toolbar.
        function wxf_frame_create_tool_bar(h, text, out) &
                bind(C, name='wxf_frame_create_tool_bar') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: text
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_frame_create_tool_bar

        !> Add a tool; `out_id` gets its id.
        function wxf_tool_bar_add_tool(h, id, label, len_label, art, len_art, file, len_file, help, len_help, kind, out_id) &
                bind(C, name='wxf_tool_bar_add_tool') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len_label
            character(kind=c_char), intent(in) :: art(*)
            integer(c_int), value :: len_art
            character(kind=c_char), intent(in) :: file(*)
            integer(c_int), value :: len_file
            character(kind=c_char), intent(in) :: help(*)
            integer(c_int), value :: len_help
            integer(c_int), value :: kind
            integer(c_int), intent(out) :: out_id
            integer(c_int) :: r
        end function wxf_tool_bar_add_tool

        !> Add a separator (or stretchable space).
        function wxf_tool_bar_add_separator(h, stretch) &
                bind(C, name='wxf_tool_bar_add_separator') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: stretch
            integer(c_int) :: r
        end function wxf_tool_bar_add_separator

        !> Add a control.
        function wxf_tool_bar_add_control(h, window, label, len_label) &
                bind(C, name='wxf_tool_bar_add_control') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int64_t), value :: window
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len_label
            integer(c_int) :: r
        end function wxf_tool_bar_add_control

        !> Number of tools.
        function wxf_tool_bar_tool_count(h, n) &
                bind(C, name='wxf_tool_bar_tool_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_tool_bar_tool_count

        !> Enable or disable a tool.
        function wxf_tool_bar_enable_tool(h, id, enable) &
                bind(C, name='wxf_tool_bar_enable_tool') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), value :: enable
            integer(c_int) :: r
        end function wxf_tool_bar_enable_tool

        !> Whether a tool is enabled.
        function wxf_tool_bar_is_tool_enabled(h, id, enabled) &
                bind(C, name='wxf_tool_bar_is_tool_enabled') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), intent(out) :: enabled
            integer(c_int) :: r
        end function wxf_tool_bar_is_tool_enabled

        !> Press or release a check tool.
        function wxf_tool_bar_toggle_tool(h, id, on) &
                bind(C, name='wxf_tool_bar_toggle_tool') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), value :: on
            integer(c_int) :: r
        end function wxf_tool_bar_toggle_tool

        !> Whether a check tool is pressed.
        function wxf_tool_bar_get_tool_state(h, id, on) &
                bind(C, name='wxf_tool_bar_get_tool_state') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int), intent(out) :: on
            integer(c_int) :: r
        end function wxf_tool_bar_get_tool_state

        !> Click a tool and send its event.
        function wxf_tool_bar_emit_click(h, id) &
                bind(C, name='wxf_tool_bar_emit_click') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: id
            integer(c_int) :: r
        end function wxf_tool_bar_emit_click

        !> Create an image view.
        function wxf_static_bitmap_create(parent, out) &
                bind(C, name='wxf_static_bitmap_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_static_bitmap_create

        !> Show an image file.
        function wxf_static_bitmap_load(h, path, len_path) &
                bind(C, name='wxf_static_bitmap_load') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), value :: len_path
            integer(c_int) :: r
        end function wxf_static_bitmap_load

        !> Show RGB data.
        function wxf_static_bitmap_set_rgb(h, rgb, w, ht) &
                bind(C, name='wxf_static_bitmap_set_rgb') result(r)
            import :: c_int, c_int64_t, c_int8_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int8_t), intent(in) :: rgb(*)
            integer(c_int), value :: w
            integer(c_int), value :: ht
            integer(c_int) :: r
        end function wxf_static_bitmap_set_rgb

        !> Size of the image shown.
        function wxf_static_bitmap_get_image_size(h, w, ht) &
                bind(C, name='wxf_static_bitmap_get_image_size') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: w
            integer(c_int), intent(out) :: ht
            integer(c_int) :: r
        end function wxf_static_bitmap_get_image_size

        !> Draw RGB data scaled into a box.
        function wxf_gc_draw_rgb(gc, rgb, w, ht, x, y, bw, bh, smooth) &
                bind(C, name='wxf_gc_draw_rgb') result(r)
            import :: c_double, c_int, c_int8_t, c_ptr
            implicit none
            type(c_ptr), value :: gc
            integer(c_int8_t), intent(in) :: rgb(*)
            integer(c_int), value :: w
            integer(c_int), value :: ht
            real(c_double), value :: x
            real(c_double), value :: y
            real(c_double), value :: bw
            real(c_double), value :: bh
            integer(c_int), value :: smooth
            integer(c_int) :: r
        end function wxf_gc_draw_rgb

        !> Draw an image file.
        function wxf_gc_draw_image_file(gc, path, len_path, x, y, bw, bh) &
                bind(C, name='wxf_gc_draw_image_file') result(r)
            import :: c_char, c_double, c_int, c_ptr
            implicit none
            type(c_ptr), value :: gc
            character(kind=c_char), intent(in) :: path(*)
            integer(c_int), value :: len_path
            real(c_double), value :: x
            real(c_double), value :: y
            real(c_double), value :: bw
            real(c_double), value :: bh
            integer(c_int) :: r
        end function wxf_gc_draw_image_file

    end interface

end module wx_c_layout

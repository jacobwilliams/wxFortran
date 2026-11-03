!> Containers and layout: [[wx_notebook]] (tabbed pages),
!> [[wx_splitter_window]] (two resizable panes), [[wx_grid_sizer]],
!> [[wx_flex_grid_sizer]], [[wx_static_box_sizer]] (a labeled group box),
!> [[wx_tool_bar]] and [[wx_static_bitmap]] (an image view).
!>
!> Notebook pages and splitter panes are ordinary windows (usually panels)
!> created with the notebook or splitter as their parent:
!>
!> ```fortran
!> book = wx_notebook(frame)
!> page = wx_panel(book)
!> call book%add_page(page, 'Settings')
!> ```
!>
!> Page indices are 1-based (0: none). Tools are identified by ids, like
!> menu items; their clicks are `wxEVT_TOOL` events, which are the same
!> events as `wxEVT_MENU`, so bind them on the frame with `id=`.
module wx_layout

    use iso_c_binding
    use wx_c_layout
    use wx_c_menus, only: wxITEM_NORMAL, wxITEM_CHECK, wxITEM_RADIO
    use wx_base
    use wx_events, only: wxID_ANY
    use wx_windows
    implicit none
    private

    ! ---------------------------------------------------------------- notebook

    !> Tabbed pages (`wxEVT_NOTEBOOK_PAGE_CHANGED`; `wxEVT_NOTEBOOK_PAGE_CHANGING`
    !> can be vetoed). `event%get_selection()` gives the new page.
    type, extends(wx_window), public :: wx_notebook
    contains
        procedure :: add_page => wx_notebook_add_page
        procedure :: page_count => wx_notebook_page_count
        procedure :: get_selection => wx_notebook_get_selection
        procedure :: set_selection => wx_notebook_set_selection
        procedure :: emit_select => wx_notebook_emit_select
        procedure :: get_page => wx_notebook_get_page
        procedure :: get_page_text => wx_notebook_get_page_text
        procedure :: set_page_text => wx_notebook_set_page_text
        procedure :: delete_page => wx_notebook_delete_page
    end type wx_notebook

    !> Create a notebook.
    interface wx_notebook
        module procedure wx_notebook_new
    end interface wx_notebook

    ! ---------------------------------------------------------------- splitter

    !> Two panes separated by a sash the user can drag.
    type, extends(wx_window), public :: wx_splitter_window
    contains
        procedure :: split_vertically => wx_splitter_split_vertically
        procedure :: split_horizontally => wx_splitter_split_horizontally
        procedure :: initialize => wx_splitter_initialize
        procedure :: unsplit => wx_splitter_unsplit
        procedure :: is_split => wx_splitter_is_split
        procedure :: set_sash_position => wx_splitter_set_sash_position
        procedure :: get_sash_position => wx_splitter_get_sash_position
        procedure :: set_minimum_pane_size => wx_splitter_set_minimum_pane_size
        procedure :: set_sash_gravity => wx_splitter_set_sash_gravity
    end type wx_splitter_window

    !> Create a splitter window.
    interface wx_splitter_window
        module procedure wx_splitter_new
    end interface wx_splitter_window

    ! ---------------------------------------------------------------- sizers

    !> A sizer placing items in a grid of equal cells, row by row.
    type, extends(wx_sizer), public :: wx_grid_sizer
    end type wx_grid_sizer

    !> Create a grid sizer.
    interface wx_grid_sizer
        module procedure wx_grid_sizer_new
    end interface wx_grid_sizer

    !> A grid sizer whose rows and columns fit their contents; chosen rows
    !> and columns grow (e.g. a form: labels, then fields that stretch).
    type, extends(wx_sizer), public :: wx_flex_grid_sizer
    contains
        procedure :: add_growable_col => wx_flex_add_growable_col
        procedure :: add_growable_row => wx_flex_add_growable_row
    end type wx_flex_grid_sizer

    !> Create a flex grid sizer.
    interface wx_flex_grid_sizer
        module procedure wx_flex_grid_sizer_new
    end interface wx_flex_grid_sizer

    !> A box sizer drawn as a labeled frame around its items.
    type, extends(wx_sizer), public :: wx_static_box_sizer
        integer(c_int64_t), private :: box = 0
    contains
        procedure :: get_static_box => wx_static_box_sizer_get_box
    end type wx_static_box_sizer

    !> Create a static box sizer.
    interface wx_static_box_sizer
        module procedure wx_static_box_sizer_new
    end interface wx_static_box_sizer

    ! ---------------------------------------------------------------- toolbar

    !> A frame's toolbar (one per frame).
    type, extends(wx_window), public :: wx_tool_bar
    contains
        procedure :: add_tool => wx_tool_bar_add_tool
        procedure :: add_separator => wx_tool_bar_add_separator
        procedure :: add_stretch => wx_tool_bar_add_stretch
        procedure :: add_control => wx_tool_bar_add_control
        procedure :: tool_count => wx_tool_bar_tool_count
        procedure :: enable_tool => wx_tool_bar_enable_tool
        procedure :: is_tool_enabled => wx_tool_bar_is_tool_enabled
        procedure :: toggle_tool => wx_tool_bar_toggle_tool
        procedure :: get_tool_state => wx_tool_bar_get_tool_state
        procedure :: emit_click => wx_tool_bar_emit_click
    end type wx_tool_bar

    !> Give a frame its toolbar.
    interface wx_tool_bar
        module procedure wx_tool_bar_new
    end interface wx_tool_bar

    ! ---------------------------------------------------------------- image view

    !> Shows an image at its natural size (for scaled or drawn images, use
    !> a canvas and `g%draw_rgb`).
    type, extends(wx_window), public :: wx_static_bitmap
    contains
        procedure :: load => wx_static_bitmap_load
        procedure :: set_rgb => wx_static_bitmap_set_rgb
        procedure :: get_image_size => wx_static_bitmap_get_image_size
    end type wx_static_bitmap

    !> Create an image view.
    interface wx_static_bitmap
        module procedure wx_static_bitmap_new
    end interface wx_static_bitmap

contains

    !> Report a creation status; on failure the new handle is cleared.
    subroutine created(status, h, stat)
        integer(c_int), intent(in) :: status
        integer(c_int64_t), intent(inout) :: h
        integer, intent(out), optional :: stat
        if (status /= WX_OK) h = 0
        call wx_check(status, stat)
    end subroutine created

    !> `x`, or '' if absent.
    function opt(x) result(s)
        character(len=*), intent(in), optional :: x
        character(len=:), allocatable :: s
        s = ''
        if (present(x)) s = x
    end function opt

    ! -------------------------------------------------------------------------
    ! wx_notebook

    !> Create a notebook inside `parent`.
    type(wx_notebook) function wx_notebook_new(parent, stat) result(nb)
        class(wx_window), intent(in) :: parent
        integer, intent(out), optional :: stat
        call created(wxf_notebook_create(parent%h, nb%h), nb%h, stat)
    end function wx_notebook_new

    !> Add `page` (created with the notebook as parent) as a tab labeled
    !> `text`; `select` shows it (without sending events).
    subroutine wx_notebook_add_page(self, page, text, select, stat)
        class(wx_notebook), intent(inout) :: self
        class(wx_window), intent(in) :: page
        character(len=*), intent(in) :: text
        logical, intent(in), optional :: select
        integer, intent(out), optional :: stat
        integer(c_int) :: sel
        sel = 0
        if (present(select)) sel = wx_int(select)
        call wx_check(wxf_notebook_add_page(self%h, page%h, text, len(text, c_int), sel), stat)
    end subroutine wx_notebook_add_page

    !> Number of pages.
    integer function wx_notebook_page_count(self, stat)
        class(wx_notebook), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: n
        n = 0
        call wx_check(wxf_notebook_page_count(self%h, n), stat)
        wx_notebook_page_count = n
    end function wx_notebook_page_count

    !> The page shown (0: none).
    integer function wx_notebook_get_selection(self, stat)
        class(wx_notebook), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: i
        i = 0
        call wx_check(wxf_notebook_get_selection(self%h, i), stat)
        wx_notebook_get_selection = i
    end function wx_notebook_get_selection

    !> Show page `index`, without sending events.
    subroutine wx_notebook_set_selection(self, index, stat)
        class(wx_notebook), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_notebook_set_selection(self%h, int(index, c_int), 0_c_int), stat)
    end subroutine wx_notebook_set_selection

    !> Show page `index` as a click on its tab would: sends
    !> `wxEVT_NOTEBOOK_PAGE_CHANGING` (a handler may veto it) and then
    !> `wxEVT_NOTEBOOK_PAGE_CHANGED`.
    subroutine wx_notebook_emit_select(self, index, stat)
        class(wx_notebook), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_notebook_set_selection(self%h, int(index, c_int), 1_c_int), stat)
    end subroutine wx_notebook_emit_select

    !> The window of page `index`.
    type(wx_window) function wx_notebook_get_page(self, index, stat) result(w)
        class(wx_notebook), intent(in) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_notebook_get_page(self%h, int(index, c_int), w%h), stat)
    end function wx_notebook_get_page

    !> The tab label of page `index`.
    function wx_notebook_get_page_text(self, index, stat) result(s)
        class(wx_notebook), intent(in) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        type(c_ptr) :: p
        integer(c_int) :: len, status
        status = wxf_notebook_get_page_text(self%h, int(index, c_int), p, len)
        s = wx_take_string(status, p, len, stat)
    end function wx_notebook_get_page_text

    !> Change the tab label of page `index`.
    subroutine wx_notebook_set_page_text(self, index, text, stat)
        class(wx_notebook), intent(inout) :: self
        integer, intent(in) :: index
        character(len=*), intent(in) :: text
        integer, intent(out), optional :: stat
        call wx_check(wxf_notebook_set_page_text(self%h, int(index, c_int), text, len(text, c_int)), stat)
    end subroutine wx_notebook_set_page_text

    !> Remove page `index` and destroy its window.
    subroutine wx_notebook_delete_page(self, index, stat)
        class(wx_notebook), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_notebook_delete_page(self%h, int(index, c_int)), stat)
    end subroutine wx_notebook_delete_page

    ! -------------------------------------------------------------------------
    ! wx_splitter_window

    !> Create a splitter inside `parent`. `live_update` (default true)
    !> resizes the panes while the sash is dragged.
    type(wx_splitter_window) function wx_splitter_new(parent, live_update, stat) result(sp)
        class(wx_window), intent(in) :: parent
        logical, intent(in), optional :: live_update
        integer, intent(out), optional :: stat
        integer(c_int) :: live
        live = 1
        if (present(live_update)) live = wx_int(live_update)
        call created(wxf_splitter_create(parent%h, live, sp%h), sp%h, stat)
    end function wx_splitter_new

    !> Show `left` and `right` side by side. `position`: sash position in
    !> pixels from the left (negative: from the right; default: the middle).
    subroutine wx_splitter_split_vertically(self, left, right, position, stat)
        class(wx_splitter_window), intent(inout) :: self
        class(wx_window), intent(in) :: left, right
        integer, intent(in), optional :: position
        integer, intent(out), optional :: stat
        integer(c_int) :: pos
        pos = 0
        if (present(position)) pos = int(position, c_int)
        call wx_check(wxf_splitter_split(self%h, left%h, right%h, 1_c_int, pos), stat)
    end subroutine wx_splitter_split_vertically

    !> Show `top` above `bottom` (`position` as for `split_vertically`).
    subroutine wx_splitter_split_horizontally(self, top, bottom, position, stat)
        class(wx_splitter_window), intent(inout) :: self
        class(wx_window), intent(in) :: top, bottom
        integer, intent(in), optional :: position
        integer, intent(out), optional :: stat
        integer(c_int) :: pos
        pos = 0
        if (present(position)) pos = int(position, c_int)
        call wx_check(wxf_splitter_split(self%h, top%h, bottom%h, 0_c_int, pos), stat)
    end subroutine wx_splitter_split_horizontally

    !> Show only `window` (a child of the splitter).
    subroutine wx_splitter_initialize(self, window, stat)
        class(wx_splitter_window), intent(inout) :: self
        class(wx_window), intent(in) :: window
        integer, intent(out), optional :: stat
        call wx_check(wxf_splitter_initialize(self%h, window%h), stat)
    end subroutine wx_splitter_initialize

    !> Hide pane `which` (1 or 2, default 2): the other one fills the splitter.
    subroutine wx_splitter_unsplit(self, which, stat)
        class(wx_splitter_window), intent(inout) :: self
        integer, intent(in), optional :: which
        integer, intent(out), optional :: stat
        integer(c_int) :: w
        w = 2
        if (present(which)) w = int(which, c_int)
        call wx_check(wxf_splitter_unsplit(self%h, w), stat)
    end subroutine wx_splitter_unsplit

    !> True if both panes are shown.
    logical function wx_splitter_is_split(self, stat)
        class(wx_splitter_window), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_splitter_is_split(self%h, v), stat)
        wx_splitter_is_split = wx_logical(v)
    end function wx_splitter_is_split

    !> Move the sash to `position` pixels.
    subroutine wx_splitter_set_sash_position(self, position, stat)
        class(wx_splitter_window), intent(inout) :: self
        integer, intent(in) :: position
        integer, intent(out), optional :: stat
        call wx_check(wxf_splitter_set_sash_position(self%h, int(position, c_int)), stat)
    end subroutine wx_splitter_set_sash_position

    !> The sash position in pixels.
    integer function wx_splitter_get_sash_position(self, stat)
        class(wx_splitter_window), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_splitter_get_sash_position(self%h, v), stat)
        wx_splitter_get_sash_position = v
    end function wx_splitter_get_sash_position

    !> The smallest size a pane can be dragged to (default 20 pixels).
    subroutine wx_splitter_set_minimum_pane_size(self, size, stat)
        class(wx_splitter_window), intent(inout) :: self
        integer, intent(in) :: size
        integer, intent(out), optional :: stat
        call wx_check(wxf_splitter_set_minimum_pane_size(self%h, int(size, c_int)), stat)
    end subroutine wx_splitter_set_minimum_pane_size

    !> Share (0..1) of a size change given to the first pane: 0 (default)
    !> keeps it fixed, 1 grows only it, 0.5 shares equally.
    subroutine wx_splitter_set_sash_gravity(self, gravity, stat)
        class(wx_splitter_window), intent(inout) :: self
        real(c_double), intent(in) :: gravity
        integer, intent(out), optional :: stat
        call wx_check(wxf_splitter_set_sash_gravity(self%h, gravity), stat)
    end subroutine wx_splitter_set_sash_gravity

    ! -------------------------------------------------------------------------
    ! sizers

    !> Create a grid sizer with `cols` columns (rows are added as needed);
    !> `vgap` and `hgap` are the gaps between cells in pixels.
    type(wx_grid_sizer) function wx_grid_sizer_new(cols, vgap, hgap, stat) result(s)
        integer, intent(in) :: cols
        integer, intent(in), optional :: vgap, hgap
        integer, intent(out), optional :: stat
        call created(wxf_grid_sizer_create(0_c_int, int(cols, c_int), gap(vgap), gap(hgap), 0_c_int, s%h), s%h, stat)
    end function wx_grid_sizer_new

    !> Create a flex grid sizer with `cols` columns (arguments as for
    !> [[wx_grid_sizer]]).
    type(wx_flex_grid_sizer) function wx_flex_grid_sizer_new(cols, vgap, hgap, stat) result(s)
        integer, intent(in) :: cols
        integer, intent(in), optional :: vgap, hgap
        integer, intent(out), optional :: stat
        call created(wxf_grid_sizer_create(0_c_int, int(cols, c_int), gap(vgap), gap(hgap), 1_c_int, s%h), s%h, stat)
    end function wx_flex_grid_sizer_new

    !> An optional gap (default 0).
    pure integer(c_int) function gap(g)
        integer, intent(in), optional :: g
        gap = 0
        if (present(g)) gap = int(g, c_int)
    end function gap

    !> Column `col` (1-based) takes a share `proportion` (default 1) of the
    !> extra width.
    subroutine wx_flex_add_growable_col(self, col, proportion, stat)
        class(wx_flex_grid_sizer), intent(inout) :: self
        integer, intent(in) :: col
        integer, intent(in), optional :: proportion
        integer, intent(out), optional :: stat
        integer(c_int) :: p
        p = 1
        if (present(proportion)) p = int(proportion, c_int)
        call wx_check(wxf_flex_grid_add_growable(self%h, int(col, c_int), p, 1_c_int), stat)
    end subroutine wx_flex_add_growable_col

    !> Row `row` (1-based) takes a share `proportion` (default 1) of the
    !> extra height.
    subroutine wx_flex_add_growable_row(self, row, proportion, stat)
        class(wx_flex_grid_sizer), intent(inout) :: self
        integer, intent(in) :: row
        integer, intent(in), optional :: proportion
        integer, intent(out), optional :: stat
        integer(c_int) :: p
        p = 1
        if (present(proportion)) p = int(proportion, c_int)
        call wx_check(wxf_flex_grid_add_growable(self%h, int(row, c_int), p, 0_c_int), stat)
    end subroutine wx_flex_add_growable_row

    !> Create a static box sizer laying out along `orient` inside a box
    !> labeled `label`, drawn in window `parent`. Create the items with
    !> `sizer%get_static_box()` as their parent.
    type(wx_static_box_sizer) function wx_static_box_sizer_new(orient, parent, label, stat) result(s)
        integer, intent(in) :: orient
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in), optional :: label
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: l
        integer(c_int) :: status
        l = opt(label)
        status = wxf_static_box_sizer_create(int(orient, c_int), parent%h, l, len(l, c_int), s%h, s%box)
        if (status /= WX_OK) s%box = 0
        call created(status, s%h, stat)
    end function wx_static_box_sizer_new

    !> The box window: the parent for the controls inside the box.
    type(wx_window) function wx_static_box_sizer_get_box(self) result(w)
        class(wx_static_box_sizer), intent(in) :: self
        w%h = self%box
    end function wx_static_box_sizer_get_box

    ! -------------------------------------------------------------------------
    ! wx_tool_bar

    !> Create the toolbar of `frame` (a frame has at most one). `text`
    !> shows labels under the icons.
    type(wx_tool_bar) function wx_tool_bar_new(frame, text, stat) result(tb)
        class(wx_window), intent(in) :: frame
        logical, intent(in), optional :: text
        integer, intent(out), optional :: stat
        integer(c_int) :: t
        t = 0
        if (present(text)) t = wx_int(text)
        call created(wxf_frame_create_tool_bar(frame%h, t, tb%h), tb%h, stat)
    end function wx_tool_bar_new

    !> Add a tool and return its id. Its icon is a standard one, `art`
    !> (wxWidgets art id, e.g. `'wxART_FILE_OPEN'`, `'wxART_NEW'`,
    !> `'wxART_GO_FORWARD'`), or the image file `file`. `help` is its tooltip;
    !> `kind`: `wxITEM_NORMAL` (default), `wxITEM_CHECK` or `wxITEM_RADIO`;
    !> `id`: a stock id (e.g. `wxID_OPEN`, sharing the handler of the menu
    !> item with that id) or a new id is generated.
    integer function wx_tool_bar_add_tool(self, label, art, file, help, kind, id, stat) result(tool_id)
        class(wx_tool_bar), intent(inout) :: self
        character(len=*), intent(in) :: label
        character(len=*), intent(in), optional :: art, file, help
        integer, intent(in), optional :: kind, id
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: a, f, h
        integer(c_int) :: k, i, out
        a = opt(art)
        f = opt(file)
        h = opt(help)
        k = wxITEM_NORMAL
        if (present(kind)) k = int(kind, c_int)
        i = wxID_ANY
        if (present(id)) i = int(id, c_int)
        out = 0
        call wx_check(wxf_tool_bar_add_tool(self%h, i, label, len(label, c_int), a, len(a, c_int), f, len(f, c_int), &
                                            h, len(h, c_int), k, out), stat)
        tool_id = out
    end function wx_tool_bar_add_tool

    !> Add a separator line.
    subroutine wx_tool_bar_add_separator(self, stat)
        class(wx_tool_bar), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_tool_bar_add_separator(self%h, 0_c_int), stat)
    end subroutine wx_tool_bar_add_separator

    !> Add stretchable space (pushes the following tools to the end).
    subroutine wx_tool_bar_add_stretch(self, stat)
        class(wx_tool_bar), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_tool_bar_add_separator(self%h, 1_c_int), stat)
    end subroutine wx_tool_bar_add_stretch

    !> Add a control (e.g. a `wx_choice`, created with the toolbar as its parent).
    subroutine wx_tool_bar_add_control(self, control, label, stat)
        class(wx_tool_bar), intent(inout) :: self
        class(wx_window), intent(in) :: control
        character(len=*), intent(in), optional :: label
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: l
        l = opt(label)
        call wx_check(wxf_tool_bar_add_control(self%h, control%h, l, len(l, c_int)), stat)
    end subroutine wx_tool_bar_add_control

    !> Number of tools (including separators and controls).
    integer function wx_tool_bar_tool_count(self, stat)
        class(wx_tool_bar), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: n
        n = 0
        call wx_check(wxf_tool_bar_tool_count(self%h, n), stat)
        wx_tool_bar_tool_count = n
    end function wx_tool_bar_tool_count

    !> Enable (or with `enable=.false.` disable) tool `id`.
    subroutine wx_tool_bar_enable_tool(self, id, enable, stat)
        class(wx_tool_bar), intent(inout) :: self
        integer, intent(in) :: id
        logical, intent(in), optional :: enable
        integer, intent(out), optional :: stat
        logical :: e
        e = .true.
        if (present(enable)) e = enable
        call wx_check(wxf_tool_bar_enable_tool(self%h, int(id, c_int), wx_int(e)), stat)
    end subroutine wx_tool_bar_enable_tool

    !> True if tool `id` is enabled.
    logical function wx_tool_bar_is_tool_enabled(self, id, stat)
        class(wx_tool_bar), intent(in) :: self
        integer, intent(in) :: id
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_tool_bar_is_tool_enabled(self%h, int(id, c_int), v), stat)
        wx_tool_bar_is_tool_enabled = wx_logical(v)
    end function wx_tool_bar_is_tool_enabled

    !> Press (or with `on=.false.` release) check or radio tool `id`, without an event.
    subroutine wx_tool_bar_toggle_tool(self, id, on, stat)
        class(wx_tool_bar), intent(inout) :: self
        integer, intent(in) :: id
        logical, intent(in), optional :: on
        integer, intent(out), optional :: stat
        logical :: o
        o = .true.
        if (present(on)) o = on
        call wx_check(wxf_tool_bar_toggle_tool(self%h, int(id, c_int), wx_int(o)), stat)
    end subroutine wx_tool_bar_toggle_tool

    !> True if check or radio tool `id` is pressed.
    logical function wx_tool_bar_get_tool_state(self, id, stat)
        class(wx_tool_bar), intent(in) :: self
        integer, intent(in) :: id
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_tool_bar_get_tool_state(self%h, int(id, c_int), v), stat)
        wx_tool_bar_get_tool_state = wx_logical(v)
    end function wx_tool_bar_get_tool_state

    !> Click tool `id` as the user would (for tests and automation): toggle
    !> a check tool, then send `wxEVT_TOOL` to the toolbar and its frame.
    !> Fails with `WX_ERR_STATE` for a disabled tool.
    subroutine wx_tool_bar_emit_click(self, id, stat)
        class(wx_tool_bar), intent(inout) :: self
        integer, intent(in) :: id
        integer, intent(out), optional :: stat
        call wx_check(wxf_tool_bar_emit_click(self%h, int(id, c_int)), stat)
    end subroutine wx_tool_bar_emit_click

    ! -------------------------------------------------------------------------
    ! wx_static_bitmap

    !> Create an image view inside `parent`, showing image file `file` if given.
    type(wx_static_bitmap) function wx_static_bitmap_new(parent, file, stat) result(b)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in), optional :: file
        integer, intent(out), optional :: stat
        integer(c_int) :: status
        status = wxf_static_bitmap_create(parent%h, b%h)
        if (status == WX_OK .and. present(file)) status = wxf_static_bitmap_load(b%h, file, len(file, c_int))
        call created(status, b%h, stat)
    end function wx_static_bitmap_new

    !> Show the image file `file` (PNG, JPEG, ...).
    subroutine wx_static_bitmap_load(self, file, stat)
        class(wx_static_bitmap), intent(inout) :: self
        character(len=*), intent(in) :: file
        integer, intent(out), optional :: stat
        call wx_check(wxf_static_bitmap_load(self%h, file, len(file, c_int)), stat)
    end subroutine wx_static_bitmap_load

    !> Show an image given as `rgb(3, width, height)` (0-255; as read by
    !> `wx_image_read_rgb`).
    subroutine wx_static_bitmap_set_rgb(self, rgb, stat)
        class(wx_static_bitmap), intent(inout) :: self
        integer, intent(in) :: rgb(:,:,:)
        integer, intent(out), optional :: stat
        integer(c_int8_t), allocatable :: bytes(:)
        if (size(rgb, 1) /= 3) then
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'set_rgb: rgb must have shape (3, width, height)'), stat)
            return
        end if
        bytes = wx_rgb_bytes(rgb)
        call wx_check(wxf_static_bitmap_set_rgb(self%h, bytes, int(size(rgb, 2), c_int), &
                                                int(size(rgb, 3), c_int)), stat)
    end subroutine wx_static_bitmap_set_rgb

    !> Size of the image shown (0 x 0 if none).
    subroutine wx_static_bitmap_get_image_size(self, width, height, stat)
        class(wx_static_bitmap), intent(in) :: self
        integer, intent(out) :: width, height
        integer, intent(out), optional :: stat
        integer(c_int) :: w, h
        w = 0
        h = 0
        call wx_check(wxf_static_bitmap_get_image_size(self%h, w, h), stat)
        width = w
        height = h
    end subroutine wx_static_bitmap_get_image_size

end module wx_layout

!> Controls showing a list of strings: [[wx_choice]] (drop-down list),
!> [[wx_list_box]] (scrolling list, single or multiple selection) and
!> [[wx_radio_box]] (a labeled group of radio buttons).
!>
!> Items are numbered from 1; a selection of 0 means none. Items are given
!> as a character array (trailing blanks are ignored):
!> `choice = wx_choice(panel, [character(len=8) :: 'red', 'green', 'blue'])`.
!> Selecting an item sends `wxEVT_CHOICE`, `wxEVT_LISTBOX` or
!> `wxEVT_RADIOBOX`; `event%get_selection()` and `event%get_string()` give it.
!> Changing the selection from code (`set_selection`) sends no event.
module wx_lists

    use iso_c_binding
    use wx_c_controls
    use wx_base
    use wx_windows
    implicit none
    private

    !> Operations common to the list controls.
    type, extends(wx_window), public :: wx_item_control
    contains
        procedure :: count => wx_items_count_
        procedure :: get_string => wx_items_get_string_
        procedure :: set_string => wx_items_set_string_
        procedure :: get_selection => wx_items_get_selection_
        procedure :: set_selection => wx_items_set_selection_
        procedure :: get_string_selection => wx_items_get_string_selection_
        procedure :: find_string => wx_items_find_
        procedure :: emit_select => wx_items_emit_select_
    end type wx_item_control

    !> A list control whose items can change (choice and list box).
    type, extends(wx_item_control), public :: wx_item_list
    contains
        procedure :: append => wx_items_append_
        procedure :: delete => wx_items_delete_
        procedure :: clear => wx_items_clear_
    end type wx_item_list

    !> A drop-down list to choose one item from (`wxEVT_CHOICE`).
    type, extends(wx_item_list), public :: wx_choice
    end type wx_choice

    !> Create a choice.
    interface wx_choice
        module procedure wx_choice_new
    end interface wx_choice

    !> A scrolling list (`wxEVT_LISTBOX`, `wxEVT_LISTBOX_DCLICK`).
    type, extends(wx_item_list), public :: wx_list_box
    contains
        procedure :: get_selections => wx_list_box_get_selections
        procedure :: select => wx_list_box_select
        procedure :: deselect => wx_list_box_deselect
        procedure :: is_selected => wx_list_box_is_selected
    end type wx_list_box

    !> Create a list box.
    interface wx_list_box
        module procedure wx_list_box_new
    end interface wx_list_box

    !> A labeled box of radio buttons, exactly one selected (`wxEVT_RADIOBOX`).
    type, extends(wx_item_control), public :: wx_radio_box
    end type wx_radio_box

    !> Create a radio box.
    interface wx_radio_box
        module procedure wx_radio_box_new
    end interface wx_radio_box

contains

    !> Report a creation status; on failure the new handle is cleared.
    subroutine created(status, h, stat)
        integer(c_int), intent(in) :: status
        integer(c_int64_t), intent(inout) :: h
        integer, intent(out), optional :: stat
        if (status /= WX_OK) h = 0
        call wx_check(status, stat)
    end subroutine created

    ! -------------------------------------------------------------------------
    ! constructors

    !> Create a choice inside `parent` with `items`, selecting item
    !> `selection` (default: the first item, if there are items).
    type(wx_choice) function wx_choice_new(parent, items, selection, stat) result(c)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in), optional :: items(:)
        integer, intent(in), optional :: selection
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: buf(:)
        integer(c_int) :: itemlen, n, status
        call wx_pack_strings(items, buf, itemlen, n)
        status = wxf_choice_create(parent%h, buf, itemlen, n, c%h)
        if (status == WX_OK .and. present(selection)) status = wxf_items_set_selection(c%h, int(selection, c_int))
        call created(status, c%h, stat)
    end function wx_choice_new

    !> Create a list box inside `parent` with `items`; `multiple` allows
    !> selecting several items (Shift/Ctrl-click).
    type(wx_list_box) function wx_list_box_new(parent, items, multiple, stat) result(l)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in), optional :: items(:)
        logical, intent(in), optional :: multiple
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: buf(:)
        integer(c_int) :: itemlen, n, m
        call wx_pack_strings(items, buf, itemlen, n)
        m = 0
        if (present(multiple)) m = wx_int(multiple)
        call created(wxf_list_box_create(parent%h, buf, itemlen, n, m, l%h), l%h, stat)
    end function wx_list_box_new

    !> Create a radio box labeled `label` inside `parent`, with one radio
    !> button per item, laid out in `columns` columns (default 1) or, if
    !> given instead, `rows` rows. `selection` defaults to 1.
    type(wx_radio_box) function wx_radio_box_new(parent, label, items, columns, rows, selection, stat) result(r)
        class(wx_window), intent(in) :: parent
        character(len=*), intent(in) :: label
        character(len=*), intent(in) :: items(:)
        integer, intent(in), optional :: columns, rows, selection
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: buf(:)
        integer(c_int) :: itemlen, n, major, by_rows, status
        call wx_pack_strings(items, buf, itemlen, n)
        major = 1
        by_rows = 0
        if (present(columns)) major = int(columns, c_int)
        if (present(rows)) then
            major = int(rows, c_int)
            by_rows = 1
        end if
        status = wxf_radio_box_create(parent%h, label, len(label, c_int), buf, itemlen, n, major, by_rows, r%h)
        if (status == WX_OK .and. present(selection)) status = wxf_items_set_selection(r%h, int(selection, c_int))
        call created(status, r%h, stat)
    end function wx_radio_box_new

    ! -------------------------------------------------------------------------
    ! items

    !> Number of items.
    integer function wx_items_count_(self, stat)
        class(wx_item_control), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: n
        n = 0
        call wx_check(wxf_items_count(self%h, n), stat)
        wx_items_count_ = n
    end function wx_items_count_

    !> The text of item `index`.
    function wx_items_get_string_(self, index, stat) result(s)
        class(wx_item_control), intent(in) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        type(c_ptr) :: p
        integer(c_int) :: len, status
        status = wxf_items_get_string(self%h, int(index, c_int), p, len)
        s = wx_take_string(status, p, len, stat)
    end function wx_items_get_string_

    !> Change the text of item `index`.
    subroutine wx_items_set_string_(self, index, text, stat)
        class(wx_item_control), intent(inout) :: self
        integer, intent(in) :: index
        character(len=*), intent(in) :: text
        integer, intent(out), optional :: stat
        call wx_check(wxf_items_set_string(self%h, int(index, c_int), text, len(text, c_int)), stat)
    end subroutine wx_items_set_string_

    !> The selected item (0: none; a multiple-selection list box: the first).
    integer function wx_items_get_selection_(self, stat)
        class(wx_item_control), intent(in) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: i
        i = 0
        call wx_check(wxf_items_get_selection(self%h, i), stat)
        wx_items_get_selection_ = i
    end function wx_items_get_selection_

    !> Select item `index` (0: none, not for radio boxes), without an event.
    subroutine wx_items_set_selection_(self, index, stat)
        class(wx_item_control), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_items_set_selection(self%h, int(index, c_int)), stat)
    end subroutine wx_items_set_selection_

    !> The text of the selected item ('' if none).
    function wx_items_get_string_selection_(self, stat) result(s)
        class(wx_item_control), intent(in) :: self
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        integer :: i
        i = self%get_selection(stat)
        s = ''
        if (i > 0) s = self%get_string(i, stat)
    end function wx_items_get_string_selection_

    !> The index of the item with text `text` (case-insensitive; 0: none).
    integer function wx_items_find_(self, text, stat)
        class(wx_item_control), intent(in) :: self
        character(len=*), intent(in) :: text
        integer, intent(out), optional :: stat
        integer(c_int) :: i
        i = 0
        call wx_check(wxf_items_find(self%h, text, len(text, c_int), i), stat)
        wx_items_find_ = i
    end function wx_items_find_

    !> Select item `index` and send the selection event, as a click would
    !> (for tests and automation). Handlers run before this returns.
    subroutine wx_items_emit_select_(self, index, stat)
        class(wx_item_control), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_items_emit_select(self%h, int(index, c_int)), stat)
    end subroutine wx_items_emit_select_

    !> Append `items` at the end.
    subroutine wx_items_append_(self, items, stat)
        class(wx_item_list), intent(inout) :: self
        character(len=*), intent(in) :: items(:)
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: buf(:)
        integer(c_int) :: itemlen, n
        call wx_pack_strings(items, buf, itemlen, n)
        call wx_check(wxf_items_append(self%h, buf, itemlen, n), stat)
    end subroutine wx_items_append_

    !> Remove item `index`.
    subroutine wx_items_delete_(self, index, stat)
        class(wx_item_list), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_items_delete(self%h, int(index, c_int)), stat)
    end subroutine wx_items_delete_

    !> Remove all items.
    subroutine wx_items_clear_(self, stat)
        class(wx_item_list), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_items_clear(self%h), stat)
    end subroutine wx_items_clear_

    ! -------------------------------------------------------------------------
    ! wx_list_box

    !> All selected items, in order.
    function wx_list_box_get_selections(self, stat) result(sel)
        class(wx_list_box), intent(in) :: self
        integer, intent(out), optional :: stat
        integer, allocatable :: sel(:)
        type(c_ptr) :: p
        integer(c_int) :: n, status
        n = 0
        status = wxf_list_box_get_selections(self%h, p, n)
        sel = wx_take_ints(status, p, n, stat)
    end function wx_list_box_get_selections

    !> Select item `index` (keeping other selected items in a multiple
    !> selection list box), without an event.
    subroutine wx_list_box_select(self, index, stat)
        class(wx_list_box), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_list_box_select(self%h, int(index, c_int), 1_c_int), stat)
    end subroutine wx_list_box_select

    !> Deselect item `index`, without an event.
    subroutine wx_list_box_deselect(self, index, stat)
        class(wx_list_box), intent(inout) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        call wx_check(wxf_list_box_select(self%h, int(index, c_int), 0_c_int), stat)
    end subroutine wx_list_box_deselect

    !> True if item `index` is selected.
    logical function wx_list_box_is_selected(self, index, stat)
        class(wx_list_box), intent(in) :: self
        integer, intent(in) :: index
        integer, intent(out), optional :: stat
        integer(c_int) :: v
        v = 0
        call wx_check(wxf_list_box_is_selected(self%h, int(index, c_int), v), stat)
        wx_list_box_is_selected = wx_logical(v)
    end function wx_list_box_is_selected

end module wx_lists

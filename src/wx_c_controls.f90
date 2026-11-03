!> Private `bind(C)` interfaces to the item and value controls of the C++
!> shim (src/cpp/wxf_controls.cpp). Item indices are 1-based (0: none).
module wx_c_controls

    use iso_c_binding
    implicit none
    private

    public :: wxf_choice_create, wxf_list_box_create, wxf_radio_box_create, wxf_items_count
    public :: wxf_items_get_string, wxf_items_set_string, wxf_items_get_selection
    public :: wxf_items_set_selection, wxf_items_find, wxf_items_append, wxf_items_delete
    public :: wxf_items_clear, wxf_items_emit_select, wxf_list_box_get_selections
    public :: wxf_list_box_select, wxf_list_box_is_selected, wxf_slider_create
    public :: wxf_slider_set_value, wxf_slider_get_value, wxf_slider_set_range
    public :: wxf_slider_get_range, wxf_slider_emit_change, wxf_spin_ctrl_create
    public :: wxf_spin_ctrl_set_value, wxf_spin_ctrl_get_value, wxf_spin_ctrl_set_range
    public :: wxf_spin_ctrl_emit_change, wxf_spin_double_create, wxf_spin_double_set_value
    public :: wxf_spin_double_get_value, wxf_spin_double_set_range
    public :: wxf_spin_double_emit_change, wxf_gauge_create, wxf_gauge_set_value
    public :: wxf_gauge_get_value, wxf_gauge_set_range, wxf_gauge_get_range, wxf_gauge_pulse

    interface

        !> Create a choice.
        function wxf_choice_create(parent, items, itemlen_items, n_items, out) &
                bind(C, name='wxf_choice_create') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: items(*)
            integer(c_int), value :: itemlen_items
            integer(c_int), value :: n_items
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_choice_create

        !> Create a list box.
        function wxf_list_box_create(parent, items, itemlen_items, n_items, multiple, out) &
                bind(C, name='wxf_list_box_create') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: items(*)
            integer(c_int), value :: itemlen_items
            integer(c_int), value :: n_items
            integer(c_int), value :: multiple
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_list_box_create

        !> Create a radio box.
        function wxf_radio_box_create(parent, label, len_label, items, itemlen_items, n_items, major, by_rows, out) &
                bind(C, name='wxf_radio_box_create') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: label(*)
            integer(c_int), value :: len_label
            character(kind=c_char), intent(in) :: items(*)
            integer(c_int), value :: itemlen_items
            integer(c_int), value :: n_items
            integer(c_int), value :: major
            integer(c_int), value :: by_rows
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_radio_box_create

        !> Number of items.
        function wxf_items_count(h, n) &
                bind(C, name='wxf_items_count') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_items_count

        !> Text of item i (malloc'd).
        function wxf_items_get_string(h, i, s, len) &
                bind(C, name='wxf_items_get_string') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_items_get_string

        !> Set the text of item i.
        function wxf_items_set_string(h, i, s, len_s) &
                bind(C, name='wxf_items_set_string') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            integer(c_int) :: r
        end function wxf_items_set_string

        !> Selected item (0: none).
        function wxf_items_get_selection(h, i) &
                bind(C, name='wxf_items_get_selection') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: i
            integer(c_int) :: r
        end function wxf_items_get_selection

        !> Select item i (0: none).
        function wxf_items_set_selection(h, i) &
                bind(C, name='wxf_items_set_selection') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int) :: r
        end function wxf_items_set_selection

        !> Index of an item by text (0: none).
        function wxf_items_find(h, s, len_s, i) &
                bind(C, name='wxf_items_find') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: s(*)
            integer(c_int), value :: len_s
            integer(c_int), intent(out) :: i
            integer(c_int) :: r
        end function wxf_items_find

        !> Append items.
        function wxf_items_append(h, items, itemlen_items, n_items) &
                bind(C, name='wxf_items_append') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            character(kind=c_char), intent(in) :: items(*)
            integer(c_int), value :: itemlen_items
            integer(c_int), value :: n_items
            integer(c_int) :: r
        end function wxf_items_append

        !> Delete item i.
        function wxf_items_delete(h, i) &
                bind(C, name='wxf_items_delete') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int) :: r
        end function wxf_items_delete

        !> Delete all items.
        function wxf_items_clear(h) &
                bind(C, name='wxf_items_clear') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_items_clear

        !> Select item i and send the selection event.
        function wxf_items_emit_select(h, i) &
                bind(C, name='wxf_items_emit_select') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int) :: r
        end function wxf_items_emit_select

        !> Selected items (malloc'd ints).
        function wxf_list_box_get_selections(h, sel, n) &
                bind(C, name='wxf_list_box_get_selections') result(r)
            import :: c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: h
            type(c_ptr), intent(out) :: sel
            integer(c_int), intent(out) :: n
            integer(c_int) :: r
        end function wxf_list_box_get_selections

        !> Select or deselect item i.
        function wxf_list_box_select(h, i, select) &
                bind(C, name='wxf_list_box_select') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int), value :: select
            integer(c_int) :: r
        end function wxf_list_box_select

        !> Whether item i is selected.
        function wxf_list_box_is_selected(h, i, selected) &
                bind(C, name='wxf_list_box_is_selected') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: i
            integer(c_int), intent(out) :: selected
            integer(c_int) :: r
        end function wxf_list_box_is_selected

        !> Create a slider.
        function wxf_slider_create(parent, value, min, max, vertical, labels, out) &
                bind(C, name='wxf_slider_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int), value :: value
            integer(c_int), value :: min
            integer(c_int), value :: max
            integer(c_int), value :: vertical
            integer(c_int), value :: labels
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_slider_create

        !> Set a slider's value.
        function wxf_slider_set_value(h, value) &
                bind(C, name='wxf_slider_set_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: value
            integer(c_int) :: r
        end function wxf_slider_set_value

        !> A slider's value.
        function wxf_slider_get_value(h, value) &
                bind(C, name='wxf_slider_get_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: value
            integer(c_int) :: r
        end function wxf_slider_get_value

        !> Set a slider's range.
        function wxf_slider_set_range(h, min, max) &
                bind(C, name='wxf_slider_set_range') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: min
            integer(c_int), value :: max
            integer(c_int) :: r
        end function wxf_slider_set_range

        !> A slider's range.
        function wxf_slider_get_range(h, min, max) &
                bind(C, name='wxf_slider_get_range') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: min
            integer(c_int), intent(out) :: max
            integer(c_int) :: r
        end function wxf_slider_get_range

        !> Move a slider and send its event.
        function wxf_slider_emit_change(h, value) &
                bind(C, name='wxf_slider_emit_change') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: value
            integer(c_int) :: r
        end function wxf_slider_emit_change

        !> Create an integer spin control.
        function wxf_spin_ctrl_create(parent, value, min, max, out) &
                bind(C, name='wxf_spin_ctrl_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int), value :: value
            integer(c_int), value :: min
            integer(c_int), value :: max
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_spin_ctrl_create

        !> Set a spin control's value.
        function wxf_spin_ctrl_set_value(h, value) &
                bind(C, name='wxf_spin_ctrl_set_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: value
            integer(c_int) :: r
        end function wxf_spin_ctrl_set_value

        !> A spin control's value.
        function wxf_spin_ctrl_get_value(h, value) &
                bind(C, name='wxf_spin_ctrl_get_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: value
            integer(c_int) :: r
        end function wxf_spin_ctrl_get_value

        !> Set a spin control's range.
        function wxf_spin_ctrl_set_range(h, min, max) &
                bind(C, name='wxf_spin_ctrl_set_range') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: min
            integer(c_int), value :: max
            integer(c_int) :: r
        end function wxf_spin_ctrl_set_range

        !> Set a spin control and send its event.
        function wxf_spin_ctrl_emit_change(h, value) &
                bind(C, name='wxf_spin_ctrl_emit_change') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: value
            integer(c_int) :: r
        end function wxf_spin_ctrl_emit_change

        !> Create a real spin control.
        function wxf_spin_double_create(parent, value, min, max, increment, digits, out) &
                bind(C, name='wxf_spin_double_create') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            real(c_double), value :: value
            real(c_double), value :: min
            real(c_double), value :: max
            real(c_double), value :: increment
            integer(c_int), value :: digits
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_spin_double_create

        !> Set a real spin control's value.
        function wxf_spin_double_set_value(h, value) &
                bind(C, name='wxf_spin_double_set_value') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            real(c_double), value :: value
            integer(c_int) :: r
        end function wxf_spin_double_set_value

        !> A real spin control's value.
        function wxf_spin_double_get_value(h, value) &
                bind(C, name='wxf_spin_double_get_value') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            real(c_double), intent(out) :: value
            integer(c_int) :: r
        end function wxf_spin_double_get_value

        !> Set a real spin control's range.
        function wxf_spin_double_set_range(h, min, max) &
                bind(C, name='wxf_spin_double_set_range') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            real(c_double), value :: min
            real(c_double), value :: max
            integer(c_int) :: r
        end function wxf_spin_double_set_range

        !> Set a real spin control and send its event.
        function wxf_spin_double_emit_change(h, value) &
                bind(C, name='wxf_spin_double_emit_change') result(r)
            import :: c_double, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            real(c_double), value :: value
            integer(c_int) :: r
        end function wxf_spin_double_emit_change

        !> Create a gauge.
        function wxf_gauge_create(parent, range, vertical, out) &
                bind(C, name='wxf_gauge_create') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int), value :: range
            integer(c_int), value :: vertical
            integer(c_int64_t), intent(out) :: out
            integer(c_int) :: r
        end function wxf_gauge_create

        !> Set a gauge's value.
        function wxf_gauge_set_value(h, value) &
                bind(C, name='wxf_gauge_set_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: value
            integer(c_int) :: r
        end function wxf_gauge_set_value

        !> A gauge's value.
        function wxf_gauge_get_value(h, value) &
                bind(C, name='wxf_gauge_get_value') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: value
            integer(c_int) :: r
        end function wxf_gauge_get_value

        !> Set a gauge's range.
        function wxf_gauge_set_range(h, range) &
                bind(C, name='wxf_gauge_set_range') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), value :: range
            integer(c_int) :: r
        end function wxf_gauge_set_range

        !> A gauge's range.
        function wxf_gauge_get_range(h, range) &
                bind(C, name='wxf_gauge_get_range') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int), intent(out) :: range
            integer(c_int) :: r
        end function wxf_gauge_get_range

        !> Pulse an indeterminate gauge.
        function wxf_gauge_pulse(h) &
                bind(C, name='wxf_gauge_pulse') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: h
            integer(c_int) :: r
        end function wxf_gauge_pulse

    end interface

end module wx_c_controls

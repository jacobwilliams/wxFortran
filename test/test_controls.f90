!> Tests of the list and value controls: wx_choice, wx_list_box,
!> wx_radio_box, wx_slider, wx_spin_ctrl, wx_spin_ctrl_double, wx_gauge,
!> their item and value operations, events and errors. No user interaction needed.
module test_controls_handlers

    use wx
    use iso_c_binding, only: c_double
    implicit none

    !> What the handlers saw.
    type :: seen_t
        integer :: calls = 0
        integer :: kind = 0
        integer :: selection = -1
        integer :: int_value = -1
        real(c_double) :: real_value = -1
        character(len=:), allocatable :: text
    end type seen_t

contains

    !> Record a control event.
    subroutine record(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (seen_t)
            s%calls = s%calls + 1
            s%kind = event%kind()
            select case (event%kind())
            case (wxEVT_CHOICE, wxEVT_LISTBOX, wxEVT_RADIOBOX)
                s%selection = event%get_selection()
                s%text = event%get_string()
            case (wxEVT_SLIDER, wxEVT_SPINCTRL)
                s%int_value = event%get_int()
            case (wxEVT_SPINCTRLDOUBLE)
                s%real_value = event%get_double()
            end select
        end select
    end subroutine record

end module test_controls_handlers


!> Runs the control tests.
program test_controls

    use wx
    use testing
    use test_controls_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_panel) :: panel
    type(wx_choice) :: choice
    type(wx_list_box) :: list, multi
    type(wx_radio_box) :: radio
    type(wx_slider) :: slider
    type(wx_spin_ctrl) :: spin
    type(wx_spin_ctrl_double) :: dspin
    type(wx_gauge) :: gauge
    type(wx_box_sizer) :: sizer
    type(seen_t), target :: seen
    integer, allocatable :: sel(:)
    integer :: stat, lo, hi, base_handlers, base_objects
    character(len=*), parameter :: unicode = 'h' // char(195) // char(169) // 'llo'   ! "héllo"

    app = wx_app()
    base_handlers = wx_active_handlers()
    base_objects = wx_live_objects()
    frame = wx_frame('controls', width=500, height=500)
    panel = wx_panel(frame)

    ! --- wx_choice
    choice = wx_choice(panel, [character(len=8) :: 'red', 'green', 'blue'])
    call check(choice%count() == 3, 'choice has three items')
    call check(choice%get_string(2) == 'green', 'items trimmed')
    call check(choice%get_selection() == 1 .and. choice%get_string_selection() == 'red', 'first item selected initially')
    call choice%set_selection(3)
    call check(choice%get_selection() == 3 .and. choice%get_string_selection() == 'blue', 'set_selection')
    call check(choice%find_string('GREEN') == 2 .and. choice%find_string('pink') == 0, 'find_string')
    call choice%append([character(len=8) :: 'cyan', unicode])
    call check(choice%count() == 5 .and. choice%get_string(5) == unicode, 'append (non-ASCII item)')
    call choice%set_string(4, 'teal')
    call check(choice%get_string(4) == 'teal', 'set_string')
    call choice%delete(1)
    call check(choice%count() == 4 .and. choice%get_string(1) == 'green', 'delete')
    call choice%set_selection(9, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'out-of-range selection rejected')
    call choice%bind(wxEVT_CHOICE, record, data=seen)
    call choice%emit_select(2)
    call check(seen%calls == 1 .and. seen%kind == wxEVT_CHOICE, 'wxEVT_CHOICE delivered')
    call check(seen%selection == 2 .and. seen%text == 'blue', 'event selection (1-based) and text')
    call check(choice%get_selection() == 2, 'emit_select selects')
    call choice%set_selection(0)
    call check(choice%get_selection() == 0, 'selection cleared')
    call choice%clear()
    call check(choice%count() == 0, 'clear')
    choice = wx_choice(panel, [character(len=3) :: 'a', 'b'], selection=2)
    call check(choice%get_selection() == 2, 'initial selection')

    ! --- wx_list_box, single and multiple selection
    list = wx_list_box(panel, [character(len=6) :: 'one', 'two', 'three'])
    call list%bind(wxEVT_LISTBOX, record, data=seen)
    seen = seen_t()
    call list%emit_select(3)
    call check(seen%kind == wxEVT_LISTBOX .and. seen%selection == 3 .and. seen%text == 'three', 'wxEVT_LISTBOX')
    call list%select(1)
    call check(list%get_selection() == 1 .and. .not. list%is_selected(3), 'single selection replaces')
    multi = wx_list_box(panel, [character(len=6) :: 'one', 'two', 'three', 'four'], multiple=.true.)
    call multi%select(2)
    call multi%select(4)
    sel = multi%get_selections()
    call check(size(sel) == 2 .and. all(sel == [2, 4]), 'multiple selection')
    call multi%deselect(2)
    sel = multi%get_selections()
    call check(size(sel) == 1 .and. sel(1) == 4 .and. multi%get_selection() == 4, 'deselect')
    call multi%set_selection(0)
    call check(size(multi%get_selections()) == 0, 'selection cleared')
    list = wx_list_box(panel)
    call check(list%count() == 0, 'empty list box')
    call list%append([character(len=3) :: 'x'])
    call check(list%count() == 1, 'append to an empty list box')

    ! --- wx_radio_box
    radio = wx_radio_box(panel, 'Size', [character(len=6) :: 'small', 'medium', 'large'], columns=3)
    call check(radio%count() == 3 .and. radio%get_selection() == 1, 'radio box selects its first item')
    call radio%bind(wxEVT_RADIOBOX, record, data=seen)
    seen = seen_t()
    call radio%emit_select(3)
    call check(seen%kind == wxEVT_RADIOBOX .and. seen%selection == 3 .and. seen%text == 'large', 'wxEVT_RADIOBOX')
    call radio%set_selection(0, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a radio box cannot have no selection')
    radio = wx_radio_box(panel, 'Mode', [character(len=2) :: 'a', 'b', 'c', 'd'], rows=2, selection=4)
    call check(radio%get_selection() == 4, 'radio box in rows, initial selection')
    radio = wx_radio_box(panel, 'Empty', [character(len=1) ::], stat=stat)
    call check(stat == WX_ERR_ARGUMENT .and. .not. radio%is_valid(), 'a radio box needs items')

    ! --- wx_slider
    slider = wx_slider(panel)
    call slider%get_range(lo, hi)
    call check(lo == 0 .and. hi == 100 .and. slider%get_value() == 0, 'slider defaults')
    slider = wx_slider(panel, value=25, min=-50, max=50, labels=.true.)
    call check(slider%get_value() == 25, 'slider value')
    call slider%set_value(500)
    call check(slider%get_value() == 50, 'slider value clamped to the range')
    call slider%bind(wxEVT_SLIDER, record, data=seen)
    seen = seen_t()
    call slider%emit_change(-10)
    call check(seen%kind == wxEVT_SLIDER .and. seen%int_value == -10 .and. slider%get_value() == -10, 'wxEVT_SLIDER')
    call slider%set_range(0, 10)
    call slider%get_range(lo, hi)
    call check(lo == 0 .and. hi == 10, 'slider set_range')
    slider = wx_slider(panel, min=5, max=1, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'slider with min > max rejected')
    call check(.not. slider%is_valid(), 'failed slider is invalid')
    slider = wx_slider(panel, vertical=.true.)

    ! --- spin controls
    spin = wx_spin_ctrl(panel, value=7, min=1, max=10)
    call check(spin%get_value() == 7, 'spin value')
    call spin%set_value(99)
    call check(spin%get_value() == 10, 'spin value clamped')
    call spin%bind(wxEVT_SPINCTRL, record, data=seen)
    seen = seen_t()
    call spin%emit_change(3)
    call check(seen%kind == wxEVT_SPINCTRL .and. seen%int_value == 3, 'wxEVT_SPINCTRL')
    dspin = wx_spin_ctrl_double(panel, value=0.5d0, min=0d0, max=2d0, increment=0.25d0, digits=3)
    call check(abs(dspin%get_value() - 0.5d0) < 1d-12, 'real spin value')
    call dspin%bind(wxEVT_SPINCTRLDOUBLE, record, data=seen)
    seen = seen_t()
    call dspin%emit_change(1.75d0)
    call check(seen%kind == wxEVT_SPINCTRLDOUBLE .and. abs(seen%real_value - 1.75d0) < 1d-12, &
               'wxEVT_SPINCTRLDOUBLE with event%get_double')
    call dspin%set_value(5d0)
    call check(abs(dspin%get_value() - 2d0) < 1d-12, 'real spin value clamped')

    ! --- wx_gauge
    gauge = wx_gauge(panel, range=200)
    call check(gauge%get_range() == 200 .and. gauge%get_value() == 0, 'gauge range and value')
    call gauge%set_value(150)
    call check(gauge%get_value() == 150, 'gauge set_value')
    call gauge%set_value(201, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'gauge value beyond range rejected')
    call gauge%pulse()
    call gauge%set_range(10, stat=stat)
    call check(stat == WX_OK .and. gauge%get_range() == 10, 'gauge set_range')

    ! --- wrong-type calls and layout
    choice%h = gauge%h   ! a choice wrapper around a gauge's handle
    call choice%set_selection(1, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'item method on a non-list control fails')
    choice = wx_choice(panel)
    sizer = wx_box_sizer(wxVERTICAL)
    call sizer%add(choice, flags=wxEXPAND)
    call sizer%add(multi, proportion=1, flags=wxEXPAND)
    call sizer%add(slider, flags=wxEXPAND)
    call sizer%add(spin)
    call sizer%add(dspin)
    call sizer%add(gauge, flags=wxEXPAND)
    call panel%set_sizer(sizer)
    call panel%layout()

    ! --- teardown
    call frame%destroy()
    call app%process_pending()
    call check(wx_active_handlers() == base_handlers, 'control handlers released')
    call check(wx_live_objects() == base_objects, 'no live objects left')

end program test_controls

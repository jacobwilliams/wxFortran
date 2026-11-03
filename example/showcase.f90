!> A tour of wxFortran's widgets, events, menus and timers, for testing by
!> hand (drawing is shown by example/plot.f90). Everything that happens is
!> written to the event log at the bottom of the window.
!>
!> Try:
!> * Type in the field: the byte count updates (wxEVT_TEXT) and the text
!>   logger echoes it (a second handler on the same event). "Disconnect text
!>   logger" removes that handler with its connection, and reconnects it.
!> * Enter or "Add" (wxEVT_TEXT_ENTER / wxEVT_BUTTON) logs the text.
!> * "Enable buttons" (wxEVT_CHECKBOX) enables/disables buttons.
!> * "Start timer" runs a repeating timer (status bar: ticks); View > Timer
!>   speed (radio items) changes its interval. "One-shot (2 s)" fires once.
!> * "Add a button" creates buttons at run time; each one destroys itself
!>   when clicked (from its own handler) and logs its wxEVT_DESTROY.
!> * File > Clear log (Ctrl+L), View > Log size events (check item; resize
!>   the window), View > More > Allow "Clear log" (check item in a submenu;
!>   disables File > Clear log), Help > About (stock id).
!> * Controls row: the choice, radio box, list box (multiple selection), slider
!>   (it drives the progress gauge) and the two spin controls log their events.
!> * Dialogs menu: every standard dialog; the log shows what was chosen.
!>   Help > About shows the About box.
!> * Closing the window (or File > Quit) is vetoed once (wxEVT_CLOSE_WINDOW);
!>   close again to quit.
module showcase_ui

    use wx
    implicit none

    !> Everything the handlers need.
    type :: showcase_t
        type(wx_frame) :: frame
        type(wx_panel) :: panel
        type(wx_text_ctrl) :: entry
        type(wx_text_ctrl) :: log
        type(wx_static_text) :: count
        type(wx_check_box) :: enable
        type(wx_button) :: add, timer_button, oneshot_button, spawn_button, logger_button
        type(wx_box_sizer) :: dynamic_row
        type(wx_choice) :: choice
        type(wx_radio_box) :: radio
        type(wx_list_box) :: list
        type(wx_slider) :: slider
        type(wx_gauge) :: gauge
        type(wx_spin_ctrl) :: spin
        type(wx_spin_ctrl_double) :: dspin
        integer :: id_msg = 0, id_yes_no = 0, id_open = 0, id_open_many = 0, id_save = 0
        integer :: id_dir = 0, id_text = 0, id_password = 0, id_pick = 0, id_color = 0
        type(wx_timer) :: ticker, oneshot
        type(wx_menu) :: file_menu, view_menu
        type(wx_connection) :: logger
        integer :: id_clear = 0, id_log_size = 0, id_fast = 0, id_slow = 0, id_allow_clear = 0
        integer :: ticks = 0
        integer :: spawned = 0
        integer :: interval = 1000
        logical :: close_warned = .false.
    end type showcase_t

contains

    !> Append a line to the event log (ignored if the log is gone, e.g. while
    !> the window is being destroyed).
    subroutine log_line(s, msg)
        type(showcase_t), intent(inout) :: s
        character(len=*), intent(in) :: msg
        integer :: stat
        call s%log%append_text(msg//new_line('a'), stat=stat)
    end subroutine log_line

    !> Show `msg` in status bar field `field` (ignored if there is none yet).
    subroutine status(s, msg, field)
        type(showcase_t), intent(inout) :: s
        character(len=*), intent(in) :: msg
        integer, intent(in), optional :: field
        integer :: stat
        call s%frame%set_status_text(msg, field=field, stat=stat)
    end subroutine status

    !> An integer as text.
    function str(i) result(r)
        integer, intent(in) :: i
        character(len=:), allocatable :: r
        character(len=16) :: buf
        write(buf, '(I0)') i
        r = trim(buf)
    end function str

    ! ---------------------------------------------------------------- text

    !> Add / Enter: log the text and empty the field.
    subroutine on_add(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: text
        select type (s => data)
        type is (showcase_t)
            text = s%entry%get_value()
            if (len(text) == 0) then
                call status(s, 'Nothing to add')
            else
                call log_line(s, 'added: "'//text//'"  (from '// &
                              merge('Enter key ', 'Add button', event%kind() == wxEVT_TEXT_ENTER)//')')
                call s%entry%change_value('')   ! no wxEVT_TEXT
                call s%count%set_label('0 bytes')
            end if
        end select
    end subroutine on_add

    !> Live byte count of the field.
    subroutine on_text(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call s%count%set_label(str(len(event%get_string()))//' bytes')
        end select
        call event%skip()   ! let the other wxEVT_TEXT handler run too
    end subroutine on_text

    !> The disconnectable text logger.
    subroutine on_text_logged(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call log_line(s, 'text changed: "'//event%get_string()//'"')
        end select
        call event%skip()
    end subroutine on_text_logged

    !> Disconnect or reconnect the text logger.
    subroutine on_toggle_logger(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            if (s%logger%is_connected()) then
                call s%logger%disconnect()
                call s%logger_button%set_label('Reconnect text logger')
                call log_line(s, 'text logger disconnected')
            else
                call s%entry%bind(wxEVT_TEXT, on_text_logged, data=s, connection=s%logger)
                call s%logger_button%set_label('Disconnect text logger')
                call log_line(s, 'text logger connected')
            end if
            call s%panel%layout()
        end select
    end subroutine on_toggle_logger

    ! ---------------------------------------------------------------- check box

    !> Enable or disable the action buttons.
    subroutine on_enable(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        logical :: on
        select type (s => data)
        type is (showcase_t)
            on = event%is_checked()
            call s%add%enable(on)
            call s%spawn_button%enable(on)
            call s%timer_button%enable(on)
            call log_line(s, 'buttons '//merge('enabled ', 'disabled', on))
        end select
    end subroutine on_enable

    ! ---------------------------------------------------------------- timers

    !> Start or stop the repeating timer.
    subroutine on_timer_button(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            if (s%ticker%is_running()) then
                call s%ticker%stop()
                call s%timer_button%set_label('Start timer')
                call log_line(s, 'timer stopped after '//str(s%ticks)//' ticks')
            else
                call s%ticker%start(s%interval)
                call s%timer_button%set_label('Stop timer')
                call log_line(s, 'timer started, every '//str(s%interval)//' ms')
            end if
        end select
    end subroutine on_timer_button

    !> A tick of the repeating timer.
    subroutine on_tick(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            s%ticks = s%ticks + 1
            call status(s, 'ticks: '//str(s%ticks), field=1)
        end select
    end subroutine on_tick

    !> Start the one-shot timer.
    subroutine on_oneshot_button(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call s%oneshot%start(2000, one_shot=.true.)
            call s%oneshot_button%disable()
            call log_line(s, 'one-shot timer started (2 s)')
        end select
    end subroutine on_oneshot_button

    !> The one-shot timer fired.
    subroutine on_oneshot(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call s%oneshot_button%enable()
            call log_line(s, 'one-shot timer fired (running: '// &
                          merge('yes', 'no ', s%oneshot%is_running())//')')
        end select
    end subroutine on_oneshot

    ! ---------------------------------------------------------------- dynamic windows

    !> Create a button that destroys itself when clicked.
    subroutine on_spawn(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_button) :: b
        select type (s => data)
        type is (showcase_t)
            s%spawned = s%spawned + 1
            b = wx_button(s%panel, 'Remove me #'//str(s%spawned))
            call b%set_tooltip('Click to destroy this button from its own handler')
            call b%bind(wxEVT_BUTTON, on_remove, data=s)
            call b%bind(wxEVT_DESTROY, on_destroyed, data=s)
            call s%dynamic_row%add(b, flags=wxALL, border=2)
            call s%panel%layout()
            call log_line(s, 'created "'//b%get_label()//'" (panel has '// &
                          str(s%panel%child_count())//' children)')
        end select
    end subroutine on_spawn

    !> A dynamic button destroys itself.
    subroutine on_remove(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_window) :: b
        select type (s => data)
        type is (showcase_t)
            b = wx_window(event%source())
            call log_line(s, 'destroying "'//b%get_label()//'" from its own click handler')
            call b%destroy()
            call log_line(s, '  its handle is now '//merge('valid  ', 'invalid', b%is_valid()))
            call s%panel%layout()
        end select
    end subroutine on_remove

    !> wxEVT_DESTROY of a dynamic button.
    subroutine on_destroyed(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call log_line(s, '  wxEVT_DESTROY received for a dynamic button')
        end select
        call event%skip()
    end subroutine on_destroyed

    ! ---------------------------------------------------------------- menus

    !> File > Clear log.
    subroutine on_clear(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call s%log%clear()
            call status(s, 'Log cleared')
        end select
    end subroutine on_clear

    !> File > Quit (stock wxID_EXIT): ask the frame to close.
    subroutine on_quit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        logical :: closed
        select type (s => data)
        type is (showcase_t)
            closed = s%frame%close()
        end select
    end subroutine on_quit

    !> View > Timer speed (radio items): change the interval.
    subroutine on_speed(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            s%interval = merge(250, 1000, event%get_id() == s%id_fast)
            if (s%ticker%is_running()) call s%ticker%start(s%interval)
            call log_line(s, 'timer interval: '//str(s%interval)//' ms')
        end select
    end subroutine on_speed

    !> View > More > Allow "Clear log" (check item in a submenu).
    subroutine on_allow_clear(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call s%file_menu%enable(s%id_clear, event%is_checked())
            call log_line(s, 'File > Clear log '//merge('enabled ', 'disabled', event%is_checked()))
        end select
    end subroutine on_allow_clear

    !> Help > About (stock wxID_ABOUT).
    subroutine on_about(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call log_line(s, 'About box (menu item id '//str(event%get_id())//')')
            call wx_about_box('wxFortran showcase', version='0.0.1', &
                              description='A tour of wxFortran: modern Fortran bindings for wxWidgets.', &
                              copyright='(c) 2026 Jacob Williams', website='https://github.com/jacobwilliams/wxFortran', &
                              parent=s%frame)
        end select
    end subroutine on_about

    !> The Dialogs menu: show the chosen dialog and log the answer.
    subroutine on_dialog(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path, text
        type(wx_string), allocatable :: paths(:)
        type(wx_color) :: color
        integer :: id, button, index, i
        character(len=12), parameter :: planets(4) = [character(len=12) :: 'Mercury', 'Venus', 'Earth', 'Mars']
        select type (s => data)
        type is (showcase_t)
            id = event%get_id()
            if (id == s%id_msg) then
                button = wx_message_box('This is a message box.', 'Message', ior(wxOK, wxICON_INFORMATION), &
                                        parent=s%frame)
                call log_line(s, 'message box: button '//button_name(button))
            else if (id == s%id_yes_no) then
                button = wx_message_box('Save changes before closing?', 'Question', &
                                        ior(ior(wxYES_NO, wxCANCEL), wxICON_QUESTION), parent=s%frame)
                call log_line(s, 'yes/no/cancel: '//button_name(button))
            else if (id == s%id_open) then
                if (wx_file_open_dialog(path, wildcard='Fortran sources (*.f90)|*.f90|All files (*.*)|*.*', &
                                        parent=s%frame)) then
                    call log_line(s, 'open: '//path)
                else
                    call log_line(s, 'open: cancelled')
                end if
            else if (id == s%id_open_many) then
                if (wx_file_open_multiple_dialog(paths, parent=s%frame)) then
                    call log_line(s, 'open several: '//str(size(paths))//' file(s)')
                    do i = 1, size(paths)
                        call log_line(s, '  '//paths(i)%s)
                    end do
                else
                    call log_line(s, 'open several: cancelled')
                end if
            else if (id == s%id_save) then
                if (wx_file_save_dialog(path, default_file='untitled.txt', parent=s%frame)) then
                    call log_line(s, 'save as: '//path//'  (nothing is written)')
                else
                    call log_line(s, 'save as: cancelled')
                end if
            else if (id == s%id_dir) then
                if (wx_dir_dialog(path, parent=s%frame)) then
                    call log_line(s, 'folder: '//path)
                else
                    call log_line(s, 'folder: cancelled')
                end if
            else if (id == s%id_text .or. id == s%id_password) then
                if (wx_text_entry_dialog(text, merge('Your name:', 'Password: ', id == s%id_text), &
                                         default_value=merge('Ada  ', '     ', id == s%id_text), &
                                         password=id == s%id_password, parent=s%frame)) then
                    if (id == s%id_text) then
                        call log_line(s, 'text: "'//text//'"')
                    else
                        call log_line(s, 'password: '//str(len(text))//' characters')
                    end if
                else
                    call log_line(s, 'text entry: cancelled')
                end if
            else if (id == s%id_pick) then
                if (wx_choice_dialog(index, 'Pick a planet:', planets, initial=3, parent=s%frame)) then
                    call log_line(s, 'choice: '//str(index)//' = '//trim(planets(index)))
                else
                    call log_line(s, 'choice: cancelled')
                end if
            else if (id == s%id_color) then
                if (wx_color_dialog(color, initial=wx_color(31, 119, 180), parent=s%frame)) then
                    call log_line(s, 'color: rgb('//str(color%r)//', '//str(color%g)//', '//str(color%b)//')')
                    call s%log%set_background_color(color)
                else
                    call log_line(s, 'color: cancelled')
                end if
            end if
        end select
    end subroutine on_dialog

    !> Name of a dialog button id.
    function button_name(id) result(name)
        integer, intent(in) :: id
        character(len=:), allocatable :: name
        select case (id)
        case (wxID_OK)
            name = 'OK'
        case (wxID_CANCEL)
            name = 'Cancel'
        case (wxID_YES)
            name = 'Yes'
        case (wxID_NO)
            name = 'No'
        case default
            name = str(id)
        end select
    end function button_name

    !> Events of the controls row.
    subroutine on_control(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer, allocatable :: sel(:)
        integer :: i
        character(len=:), allocatable :: msg
        select type (s => data)
        type is (showcase_t)
            select case (event%kind())
            case (wxEVT_CHOICE)
                call log_line(s, 'choice: item '//str(event%get_selection())//' "'//event%get_string()//'"')
            case (wxEVT_RADIOBOX)
                call log_line(s, 'radio box: item '//str(event%get_selection())//' "'//event%get_string()//'"')
            case (wxEVT_LISTBOX)
                sel = s%list%get_selections()
                msg = 'list box: selected'
                do i = 1, size(sel)
                    msg = msg//' '//str(sel(i))
                end do
                call log_line(s, msg)
            case (wxEVT_LISTBOX_DCLICK)
                call log_line(s, 'list box: double-clicked "'//event%get_string()//'"')
            case (wxEVT_SLIDER)
                call s%gauge%set_value(event%get_int())
                call status(s, 'slider: '//str(event%get_int()))
            case (wxEVT_SPINCTRL)
                call log_line(s, 'spin: '//str(event%get_int()))
            case (wxEVT_SPINCTRLDOUBLE)
                block
                    character(len=24) :: buf
                    write(buf, '(F0.2)') event%get_double()
                    call log_line(s, 'real spin: '//trim(buf))
                end block
            end select
        end select
    end subroutine on_control

    !> Any menu event (bound without id, on the frame, after the others: runs
    !> first and passes the event on).
    subroutine on_any_menu(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call status(s, 'menu item '//str(event%get_id()))
        end select
        call event%skip()
    end subroutine on_any_menu

    ! ---------------------------------------------------------------- frame

    !> Window resized: show the size; log it if View > Log size events.
    subroutine on_size(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: w, h, stat
        select type (s => data)
        type is (showcase_t)
            call event%get_size(w, h)
            call status(s, str(w)//' x '//str(h), field=2)
            if (s%view_menu%is_checked(s%id_log_size, stat=stat)) then
                if (stat == WX_OK) call log_line(s, 'size: '//str(w)//' x '//str(h))
            end if
        end select
        call event%skip()   ! required: default processing lays out the frame
    end subroutine on_size

    !> Veto the first close; allow the next one.
    subroutine on_close(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            if (.not. s%close_warned .and. event%can_veto()) then
                call event%veto()
                s%close_warned = .true.
                call log_line(s, 'close vetoed: close again to quit')
                call status(s, 'Close again to quit')
            else
                call event%skip()   ! let the frame close (and the program end)
            end if
        end select
    end subroutine on_close

    !> Runs once the event loop has started (wx_call_after).
    subroutine on_started(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (showcase_t)
            call log_line(s, 'event loop running; live objects: '//str(wx_live_objects())// &
                          ', handlers: '//str(wx_active_handlers()))
        end select
    end subroutine on_started

end module showcase_ui


!> Builds the showcase window and runs it.
program showcase

    use wx
    use showcase_ui
    implicit none

    type(wx_app) :: app
    type(showcase_t), target :: s
    type(wx_box_sizer) :: main, entry_row, button_row
    type(wx_menu_bar) :: bar
    type(wx_menu) :: more, help, dialogs
    type(wx_box_sizer) :: controls_row, value_col
    integer :: dialog_ids(10)
    integer :: id
    character(len=*), parameter :: tab = achar(9)
    character(len=*), parameter :: check_mark = char(226)//char(156)//char(147)   ! U+2713 in UTF-8

    app = wx_app()

    s%frame = wx_frame('wxFortran showcase '//check_mark, width=860, height=680)
    s%panel = wx_panel(s%frame)

    ! --- controls
    s%entry = wx_text_ctrl(s%panel, style=wxTE_PROCESS_ENTER)
    call s%entry%set_tooltip('Type here; Enter adds the text to the log')
    s%add = wx_button(s%panel, 'Add')
    s%count = wx_static_text(s%panel, '0 bytes')
    s%enable = wx_check_box(s%panel, 'Enable buttons', checked=.true.)
    s%timer_button = wx_button(s%panel, 'Start timer')
    s%oneshot_button = wx_button(s%panel, 'One-shot (2 s)')
    s%spawn_button = wx_button(s%panel, 'Add a button')
    s%logger_button = wx_button(s%panel, 'Disconnect text logger')
    s%log = wx_text_ctrl(s%panel, style=ior(wxTE_MULTILINE, wxTE_READONLY))

    ! --- layout: nested box sizers
    entry_row = wx_box_sizer(wxHORIZONTAL)
    call entry_row%add(wx_static_text(s%panel, 'Type something:'), &
                       flags=ior(wxRIGHT, wxALIGN_CENTER), border=8)
    call entry_row%add(s%entry, proportion=1, flags=wxALIGN_CENTER)
    call entry_row%add(s%add, flags=ior(wxLEFT, wxALIGN_CENTER), border=8)
    call entry_row%add(s%count, flags=ior(wxLEFT, wxALIGN_CENTER), border=8)
    call s%count%set_min_size(70, -1)

    button_row = wx_box_sizer(wxHORIZONTAL)
    call button_row%add(s%enable, flags=ior(wxRIGHT, wxALIGN_CENTER), border=12)
    call button_row%add(s%timer_button, flags=wxRIGHT, border=6)
    call button_row%add(s%oneshot_button, flags=wxRIGHT, border=6)
    call button_row%add(s%spawn_button, flags=wxRIGHT, border=6)
    call button_row%add_stretch()
    call button_row%add(s%logger_button)

    ! more controls: lists and values
    s%choice = wx_choice(s%panel, [character(len=8) :: 'Red', 'Green', 'Blue'])
    s%radio = wx_radio_box(s%panel, 'Size', [character(len=6) :: 'Small', 'Medium', 'Large'], columns=1)
    s%list = wx_list_box(s%panel, [character(len=10) :: 'alpha', 'beta', 'gamma', 'delta', 'epsilon'], &
                         multiple=.true.)
    call s%list%set_min_size(110, 90)
    s%slider = wx_slider(s%panel, value=30, min=0, max=100, labels=.true.)
    s%gauge = wx_gauge(s%panel, range=100)
    call s%gauge%set_value(30)
    s%spin = wx_spin_ctrl(s%panel, value=5, min=0, max=10)
    s%dspin = wx_spin_ctrl_double(s%panel, value=1.5d0, min=0d0, max=10d0, increment=0.25d0)
    value_col = wx_box_sizer(wxVERTICAL)
    call value_col%add(s%slider, flags=wxEXPAND)
    call value_col%add(s%gauge, flags=ior(wxEXPAND, wxTOP), border=4)
    call value_col%add(s%spin, flags=wxTOP, border=6)
    call value_col%add(s%dspin, flags=wxTOP, border=4)
    controls_row = wx_box_sizer(wxHORIZONTAL)
    call controls_row%add(s%choice, flags=ior(wxRIGHT, wxALIGN_CENTER), border=10)
    call controls_row%add(s%radio, flags=wxRIGHT, border=10)
    call controls_row%add(s%list, flags=wxRIGHT, border=10)
    call controls_row%add(value_col, proportion=1)
    call s%choice%bind(wxEVT_CHOICE, on_control, data=s)
    call s%radio%bind(wxEVT_RADIOBOX, on_control, data=s)
    call s%list%bind(wxEVT_LISTBOX, on_control, data=s)
    call s%list%bind(wxEVT_LISTBOX_DCLICK, on_control, data=s)
    call s%slider%bind(wxEVT_SLIDER, on_control, data=s)
    call s%spin%bind(wxEVT_SPINCTRL, on_control, data=s)
    call s%dspin%bind(wxEVT_SPINCTRLDOUBLE, on_control, data=s)

    s%dynamic_row = wx_box_sizer(wxHORIZONTAL)
    call s%dynamic_row%add(wx_static_text(s%panel, 'Dynamic buttons:'), &
                           flags=ior(wxRIGHT, wxALIGN_CENTER), border=8)

    main = wx_box_sizer(wxVERTICAL)
    call main%add(entry_row, flags=ior(wxEXPAND, wxALL), border=10)
    call main%add(button_row, flags=ior(wxEXPAND, ior(wxLEFT, wxRIGHT)), border=10)
    call main%add_spacer(8)
    call main%add(controls_row, flags=ior(wxEXPAND, ior(wxLEFT, ior(wxRIGHT, wxTOP))), border=10)
    call main%add_spacer(8)
    call main%add(s%dynamic_row, flags=ior(wxEXPAND, ior(wxLEFT, wxRIGHT)), border=10)
    call main%add(s%log, proportion=1, flags=ior(wxEXPAND, wxALL), border=10)
    call s%panel%set_sizer(main)

    ! --- control events
    call s%add%bind(wxEVT_BUTTON, on_add, data=s)
    call s%entry%bind(wxEVT_TEXT_ENTER, on_add, data=s)
    call s%entry%bind(wxEVT_TEXT, on_text, data=s)
    call s%entry%bind(wxEVT_TEXT, on_text_logged, data=s, connection=s%logger)
    call s%logger_button%bind(wxEVT_BUTTON, on_toggle_logger, data=s)
    call s%enable%bind(wxEVT_CHECKBOX, on_enable, data=s)
    call s%timer_button%bind(wxEVT_BUTTON, on_timer_button, data=s)
    call s%oneshot_button%bind(wxEVT_BUTTON, on_oneshot_button, data=s)
    call s%spawn_button%bind(wxEVT_BUTTON, on_spawn, data=s)

    ! --- timers, owned by the frame
    s%ticker = wx_timer(owner=s%frame)
    call s%ticker%bind(wxEVT_TIMER, on_tick, data=s)
    s%oneshot = wx_timer(owner=s%frame)
    call s%oneshot%bind(wxEVT_TIMER, on_oneshot, data=s)

    ! --- menus
    bar = wx_menu_bar()
    s%file_menu = wx_menu()
    s%id_clear = s%file_menu%append('&Clear log'//tab//'Ctrl+L', help='Empty the event log')
    call s%file_menu%append_separator()
    id = s%file_menu%append(id=wxID_EXIT, help='Quit (asks twice)')
    s%view_menu = wx_menu()
    s%id_log_size = s%view_menu%append('&Log size events', kind=wxITEM_CHECK, &
                                       help='Log every wxEVT_SIZE of the frame')
    call s%view_menu%append_separator()
    s%id_slow = s%view_menu%append('Timer: &slow (1 s)', kind=wxITEM_RADIO)
    s%id_fast = s%view_menu%append('Timer: &fast (0.25 s)', kind=wxITEM_RADIO)
    more = wx_menu()
    s%id_allow_clear = more%append('Allow "Clear log"', kind=wxITEM_CHECK, &
                                   help='Enable or disable File > Clear log')
    call more%check(s%id_allow_clear)
    call s%view_menu%append_submenu(more, '&More')
    dialogs = wx_menu()
    s%id_msg = dialogs%append('&Message box...')
    s%id_yes_no = dialogs%append('&Yes / No / Cancel...')
    call dialogs%append_separator()
    s%id_open = dialogs%append('&Open file...')
    s%id_open_many = dialogs%append('Open &several files...')
    s%id_save = dialogs%append('&Save as...')
    s%id_dir = dialogs%append('Choose &folder...')
    call dialogs%append_separator()
    s%id_text = dialogs%append('&Text entry...')
    s%id_password = dialogs%append('&Password entry...')
    s%id_pick = dialogs%append('&Choice...')
    s%id_color = dialogs%append('Co&lor...', help='Pick a color for the log background')
    help = wx_menu()
    id = help%append(id=wxID_ABOUT)
    call bar%append(s%file_menu, '&File')
    call bar%append(s%view_menu, '&View')
    call bar%append(dialogs, '&Dialogs')
    call bar%append(help, '&Help')
    call s%frame%set_menu_bar(bar)

    call s%frame%bind(wxEVT_MENU, on_clear, data=s, id=s%id_clear)
    call s%frame%bind(wxEVT_MENU, on_quit, data=s, id=wxID_EXIT)
    call s%frame%bind(wxEVT_MENU, on_speed, data=s, id=s%id_slow)
    call s%frame%bind(wxEVT_MENU, on_speed, data=s, id=s%id_fast)
    call s%frame%bind(wxEVT_MENU, on_allow_clear, data=s, id=s%id_allow_clear)
    call s%frame%bind(wxEVT_MENU, on_about, data=s, id=wxID_ABOUT)
    dialog_ids = [s%id_msg, s%id_yes_no, s%id_open, s%id_open_many, s%id_save, &
                  s%id_dir, s%id_text, s%id_password, s%id_pick, s%id_color]
    do id = 1, size(dialog_ids)
        call s%frame%bind(wxEVT_MENU, on_dialog, data=s, id=dialog_ids(id))
    end do
    call s%frame%bind(wxEVT_MENU, on_any_menu, data=s)

    ! --- status bar: message, ticks, size
    call s%frame%create_status_bar(3)
    call s%frame%set_status_text('Ready')
    call s%frame%set_status_text('ticks: 0', field=1)

    ! --- frame events
    call s%frame%bind(wxEVT_SIZE, on_size, data=s)
    call s%frame%bind(wxEVT_CLOSE_WINDOW, on_close, data=s)

    call s%frame%set_min_size(760, 560)
    call s%frame%center()
    call s%frame%show()
    call s%entry%set_focus()
    call wx_call_after(on_started, s)

    stop app%run()

end program showcase

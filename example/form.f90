!> A small form: labeled text fields, a check box and buttons laid out with
!> nested sizers. Submit (or Enter in a field) shows a greeting; the live
!> character count updates as you type; Quit closes the frame. A menu bar
!> (File > Clear, File > Quit, Help > About) and a status bar with a clock
!> updated by a timer.
module form_ui

    use wx
    implicit none

    !> The form's controls, passed to the handlers as their data.
    type :: form_t
        type(wx_frame) :: frame
        type(wx_text_ctrl) :: name
        type(wx_text_ctrl) :: city
        type(wx_check_box) :: shout
        type(wx_static_text) :: count
        type(wx_static_text) :: result
        type(wx_timer) :: clock
    end type form_t

contains

    !> Build the greeting from the fields.
    subroutine on_submit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: msg
        select type (f => data)
        type is (form_t)
            if (len(f%name%get_value()) == 0) then
                msg = 'Please enter your name.'
            else
                msg = 'Hello, '//f%name%get_value()
                if (len(f%city%get_value()) > 0) msg = msg//' from '//f%city%get_value()
                msg = msg//'!'
                if (f%shout%get_value()) msg = upper(msg)
            end if
            call f%result%set_label(msg)
            call f%frame%layout()
            call f%frame%set_status_text('Submitted')
        end select
    end subroutine on_submit

    !> File > Clear: empty the fields.
    subroutine on_clear(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (f => data)
        type is (form_t)
            call f%name%clear()
            call f%city%clear()
            call f%result%set_label('')
            call f%frame%set_status_text('Cleared')
        end select
    end subroutine on_clear

    !> Help > About.
    subroutine on_about(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (f => data)
        type is (form_t)
            call f%frame%set_status_text('wxFortran form example')
        end select
    end subroutine on_about

    !> Clock timer: show the time in the second status field.
    subroutine on_clock(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=10) :: t
        select type (f => data)
        type is (form_t)
            call date_and_time(time=t)
            call f%frame%set_status_text(t(1:2)//':'//t(3:4)//':'//t(5:6), field=1)
        end select
    end subroutine on_clock

    !> Show the length of the name as it is typed.
    subroutine on_name_changed(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=32) :: msg
        select type (f => data)
        type is (form_t)
            write(msg, '(I0,A)') len(event%get_string()), ' characters'
            call f%count%set_label(trim(msg))
        end select
    end subroutine on_name_changed

    !> Close the frame (which ends the program's main loop); from the Quit
    !> button or File > Quit.
    subroutine on_quit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        logical :: closed
        select type (f => data)
        type is (form_t)
            closed = f%frame%close()
        end select
    end subroutine on_quit

    !> ASCII upper case.
    pure function upper(s) result(u)
        character(len=*), intent(in) :: s
        character(len=len(s)) :: u
        integer :: i
        u = s
        do i = 1, len(s)
            if (s(i:i) >= 'a' .and. s(i:i) <= 'z') u(i:i) = achar(iachar(s(i:i)) - 32)
        end do
    end function upper

end module form_ui


!> Runs the form.
program form

    use wx
    use form_ui
    implicit none

    type(wx_app) :: app
    type(form_t), target :: f
    type(wx_panel) :: panel
    type(wx_button) :: submit, quit
    type(wx_box_sizer) :: main, row1, row2, buttons
    type(wx_menu_bar) :: bar
    type(wx_menu) :: file_menu, help_menu
    integer :: id_clear, id

    app = wx_app()

    f%frame = wx_frame("wxFortran form")
    panel = wx_panel(f%frame)

    f%name = wx_text_ctrl(panel, style=wxTE_PROCESS_ENTER)
    f%city = wx_text_ctrl(panel, style=wxTE_PROCESS_ENTER)
    f%shout = wx_check_box(panel, "Shout")
    f%count = wx_static_text(panel, "0 characters")
    f%result = wx_static_text(panel, "")
    submit = wx_button(panel, "Submit")
    quit = wx_button(panel, "Quit")
    call f%name%set_tooltip("Your name")

    row1 = wx_box_sizer(wxHORIZONTAL)
    call row1%add(wx_static_text(panel, "Name:"), flags=ior(wxRIGHT, wxALIGN_CENTER), border=8)
    call row1%add(f%name, proportion=1)
    call row1%add(f%count, flags=ior(wxLEFT, wxALIGN_CENTER), border=8)

    row2 = wx_box_sizer(wxHORIZONTAL)
    call row2%add(wx_static_text(panel, "City:"), flags=ior(wxRIGHT, wxALIGN_CENTER), border=8)
    call row2%add(f%city, proportion=1)

    buttons = wx_box_sizer(wxHORIZONTAL)
    call buttons%add_stretch()
    call buttons%add(submit, flags=wxRIGHT, border=8)
    call buttons%add(quit)

    main = wx_box_sizer(wxVERTICAL)
    call main%add(row1, flags=ior(wxEXPAND, wxALL), border=10)
    call main%add(row2, flags=ior(wxEXPAND, ior(wxLEFT, wxRIGHT)), border=10)
    call main%add(f%shout, flags=wxALL, border=10)
    call main%add(f%result, proportion=1, flags=ior(wxEXPAND, ior(wxLEFT, wxRIGHT)), border=10)
    call main%add(buttons, flags=ior(wxEXPAND, wxALL), border=10)
    call panel%set_sizer(main)

    call submit%bind(wxEVT_BUTTON, on_submit, data=f)
    call f%name%bind(wxEVT_TEXT_ENTER, on_submit, data=f)
    call f%city%bind(wxEVT_TEXT_ENTER, on_submit, data=f)
    call f%name%bind(wxEVT_TEXT, on_name_changed, data=f)
    call quit%bind(wxEVT_BUTTON, on_quit, data=f)

    ! menus: stock items get standard labels and shortcuts (and on macOS move
    ! to the application menu)
    bar = wx_menu_bar()
    file_menu = wx_menu()
    id_clear = file_menu%append("&Clear"//achar(9)//"Ctrl+L", help="Empty the fields")
    call file_menu%append_separator()
    id = file_menu%append(id=wxID_EXIT, help="Quit the program")
    help_menu = wx_menu()
    id = help_menu%append(id=wxID_ABOUT, help="About this example")
    call bar%append(file_menu, "&File")
    call bar%append(help_menu, "&Help")
    call f%frame%set_menu_bar(bar)
    call f%frame%bind(wxEVT_MENU, on_clear, data=f, id=id_clear)
    call f%frame%bind(wxEVT_MENU, on_quit, data=f, id=wxID_EXIT)
    call f%frame%bind(wxEVT_MENU, on_about, data=f, id=wxID_ABOUT)

    ! status bar: messages (and menu help) in field 0, a clock in field 1
    call f%frame%create_status_bar(2)
    call f%frame%set_status_text("Ready")
    f%clock = wx_timer(owner=f%frame)
    call f%clock%bind(wxEVT_TIMER, on_clock, data=f)
    call f%clock%start(1000)

    call f%frame%set_size(440, 300)
    call f%frame%set_min_size(380, 280)
    call f%frame%center()
    call f%frame%show()
    call f%name%set_focus()

    stop app%run()

end program form

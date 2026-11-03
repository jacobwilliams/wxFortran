!> The smallest wxFortran program: a frame with a label and a button.
program hello

    use wx
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_panel) :: panel
    type(wx_static_text) :: label
    type(wx_button) :: button
    type(wx_box_sizer) :: sizer
    integer, target :: clicks = 0

    app = wx_app()

    frame = wx_frame("wxFortran", width=320, height=160)
    panel = wx_panel(frame)
    label = wx_static_text(panel, "Hello from Fortran!")
    button = wx_button(panel, "Click me")

    sizer = wx_box_sizer(wxVERTICAL)
    call sizer%add(label, flags=ior(wxALL, wxALIGN_CENTER), border=10)
    call sizer%add(button, flags=ior(wxALL, wxALIGN_CENTER), border=10)
    call panel%set_sizer(sizer)

    call button%bind(wxEVT_BUTTON, on_click, data=clicks)

    call frame%center()
    call frame%show()

    stop app%run()

contains

    !> Count the clicks and show the count in the label.
    subroutine on_click(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        character(len=32) :: msg
        select type (data)
        type is (integer)
            data = data + 1
            write(msg, '(A,I0,A)') 'Clicked ', data, ' time(s)'
            call label%set_label(trim(msg))
            call panel%layout()
        end select
    end subroutine on_click

end program hello

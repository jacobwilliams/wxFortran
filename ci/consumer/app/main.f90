!> Downstream smoke test: create a window and a button, deliver an event,
!> run the main loop briefly, and shut down.
module consumer_handlers

    use wx
    implicit none

contains

    !> Count clicks.
    subroutine on_click(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (integer)
            data = data + 1
        end select
    end subroutine on_click

    !> Leave the main loop.
    subroutine quit(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (wx_app)
            call data%exit_main_loop()
        end select
    end subroutine quit

end module consumer_handlers


!> Runs the downstream smoke test.
program consumer

    use wx
    use consumer_handlers
    implicit none

    type(wx_app), target :: app
    type(wx_frame) :: frame
    type(wx_button) :: button
    integer, target :: clicks = 0

    app = wx_app()
    frame = wx_frame("consumer")
    button = wx_button(frame, "OK")
    call button%bind(wxEVT_BUTTON, on_click, data=clicks)
    call button%emit_click()
    call frame%show()
    call wx_call_after(quit, app)
    if (app%run() /= 0 .or. clicks /= 1) error stop 'consumer: unexpected result'
    call frame%destroy()
    call app%cleanup()
    write(*,'(A)') 'consumer: ok'

end program consumer

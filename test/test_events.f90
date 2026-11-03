!> Event tests: handler delivery and user data, disconnecting, release of
!> handlers when their window is destroyed, close vetoes, deferred calls and
!> the main loop. No user interaction needed.
module test_events_handlers

    use wx
    implicit none

    !> Records the events seen by `record`.
    type :: recorder
        integer :: calls = 0
        integer :: last_kind = 0
        integer :: last_int = -1
        character(len=:), allocatable :: last_string
        type(wx_object) :: last_source
    end type recorder

    !> State for the close-veto test.
    type :: closer
        logical :: allow = .false.
        integer :: calls = 0
    end type closer

    !> State for the main-loop test.
    type :: loop_state
        type(wx_app) :: app
        type(wx_button) :: button
        integer :: step = 0
        integer :: clicks = 0
    end type loop_state

    type(wx_event), save :: kept_event          ! copied out of a handler
    type(wx_connection), save :: self_connection   ! for a handler that disconnects itself
    integer, save :: self_calls = 0

contains

    !> Record any event into a `recorder`.
    subroutine record(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%last_kind = event%kind()
            data%last_source = event%source()
            if (event%kind() == wxEVT_TEXT) data%last_string = event%get_string()
            if (event%kind() == wxEVT_CHECKBOX) data%last_int = event%get_int()
        end select
        kept_event = event
    end subroutine record

    !> Count calls into an integer.
    subroutine count_calls(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        if (.not. present(data)) return
        select type (data)
        type is (integer)
            data = data + 1
        end select
        call event%skip()   ! let other handlers run too
    end subroutine count_calls

    !> A handler without data.
    subroutine no_data(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        if (present(data)) error stop 'no_data: unexpected data'
        self_calls = self_calls + 100
        call event%skip()
    end subroutine no_data

    !> Veto the close unless allowed; if allowed, let it proceed (skip).
    subroutine on_close(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (closer)
            data%calls = data%calls + 1
            if (data%allow .or. .not. event%can_veto()) then
                call event%skip()
            else
                call event%veto()
            end if
        end select
    end subroutine on_close

    !> Disconnect itself on its first call.
    subroutine once(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        self_calls = self_calls + 1
        call self_connection%disconnect()
        call event%skip()
    end subroutine once

    !> Main-loop driver: click the button, then quit, from deferred calls.
    subroutine step(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (loop_state)
            data%step = data%step + 1
            if (data%step < 3) then
                call data%button%emit_click()
                call wx_call_after(step, data)
            else
                call data%app%exit_main_loop()
            end if
        end select
    end subroutine step

    !> Count clicks into a `loop_state`.
    subroutine loop_click(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (loop_state)
            data%clicks = data%clicks + 1
        end select
    end subroutine loop_click

end module test_events_handlers


!> Runs the event tests.
program test_events

    use wx
    use testing
    use test_events_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_panel) :: panel
    type(wx_button) :: button
    type(wx_text_ctrl) :: text
    type(wx_check_box) :: box
    type(wx_connection) :: conn, conn2
    type(recorder), target :: rec
    type(closer), target :: cl
    type(loop_state), target :: ls
    integer, target :: n1, n2, frame_clicks
    integer :: stat, base_handlers, i
    logical :: closed

    app = wx_app()
    base_handlers = wx_active_handlers()

    frame = wx_frame("events")
    panel = wx_panel(frame)
    button = wx_button(panel, "Go")
    text = wx_text_ctrl(panel)
    box = wx_check_box(panel, "Box")

    ! --- delivery with data and source
    call button%bind(wxEVT_BUTTON, record, data=rec, connection=conn)
    call check(conn%is_connected(), 'connection is connected after bind')
    call button%emit_click()
    call check(rec%calls == 1, 'button handler called once')
    call check(rec%last_kind == wxEVT_BUTTON, 'event kind is wxEVT_BUTTON')
    call check(rec%last_source == button, 'event source is the button')

    ! --- using an event outside its handler is an error, not a crash
    call kept_event%skip(stat=stat)
    call check(stat == WX_ERR_STATE, 'event used outside its handler fails with WX_ERR_STATE')

    ! --- disconnect
    call conn%disconnect()
    call check(.not. conn%is_connected(), 'disconnected')
    call button%emit_click()
    call check(rec%calls == 1, 'no call after disconnect')
    call conn%disconnect(stat=stat)
    call check(stat == WX_OK, 'disconnecting twice is harmless')
    call check(wx_active_handlers() == base_handlers, 'handler released by disconnect')

    ! --- several handlers; skip passes the event on (and up to the parent)
    n1 = 0
    n2 = 0
    frame_clicks = 0
    call button%bind(wxEVT_BUTTON, count_calls, data=n1)
    call button%bind(wxEVT_BUTTON, count_calls, data=n2)
    call button%bind(wxEVT_BUTTON, no_data)
    call frame%bind(wxEVT_BUTTON, count_calls, data=frame_clicks)
    self_calls = 0
    call button%emit_click()
    call check(n1 == 1 .and. n2 == 1, 'both skipping handlers called')
    call check(self_calls == 100, 'handler without data called')
    call check(frame_clicks == 1, 'skipped command event propagates to the frame')

    ! --- a handler can disconnect itself while running
    self_calls = 0
    call button%bind(wxEVT_BUTTON, once, connection=self_connection)
    call button%emit_click()
    call button%emit_click()
    call check(self_calls == 1 + 2*100, 'self-disconnecting handler ran once')

    ! --- text events carry the new text; change_value does not send one
    rec = recorder()
    call text%bind(wxEVT_TEXT, record, data=rec)
    call text%set_value("abc")
    call check(rec%calls == 1 .and. rec%last_string == "abc", 'wxEVT_TEXT carries the new text')
    call text%change_value("silent")
    call check(rec%calls == 1, 'change_value sends no event')

    ! --- check box events carry the state
    rec = recorder()
    call box%bind(wxEVT_CHECKBOX, record, data=rec)
    call box%emit_click()
    call check(rec%calls == 1 .and. rec%last_int == 1 .and. box%get_value(), 'check box event: checked')
    call box%emit_click()
    call check(rec%calls == 2 .and. rec%last_int == 0, 'check box event: unchecked')

    ! --- bad event kind
    call button%bind(999, record, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'unknown event kind fails with WX_ERR_ARGUMENT')
    call check(wx_active_handlers() > base_handlers, 'handlers bound')

    ! --- close: veto, then allow
    call frame%bind(wxEVT_CLOSE_WINDOW, on_close, data=cl)
    closed = frame%close()
    call check(cl%calls == 1 .and. .not. closed, 'close vetoed by handler')
    call check(frame%is_valid(), 'vetoed frame still valid')
    cl%allow = .true.
    closed = frame%close()
    call check(cl%calls == 2 .and. closed, 'close allowed by handler')
    call check(.not. frame%is_valid() .and. .not. button%is_valid(), 'closed frame and children invalid')

    ! --- every binding of the destroyed windows is released
    call app%process_pending()
    call check(wx_active_handlers() == base_handlers, 'destroying a window releases its handlers')

    ! --- binding on a destroyed window fails cleanly
    call button%bind(wxEVT_BUTTON, record, data=rec, connection=conn2, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'bind on destroyed window fails')
    call check(.not. conn2%is_connected(), 'failed bind gives no connection')
    call check(wx_active_handlers() == base_handlers, 'failed bind releases its slot')

    ! --- repeated bind/destroy cycles do not leak handlers
    do i = 1, 100
        frame = wx_frame("cycle")
        button = wx_button(frame, "b")
        call button%bind(wxEVT_BUTTON, count_calls, data=n1)
        call frame%bind(wxEVT_SIZE, count_calls, data=n2)
        call frame%destroy()
    end do
    call app%process_pending()
    call check(wx_active_handlers() == base_handlers, 'repeated bind/destroy leaks no handlers')

    ! --- main loop: deferred calls click a button, then exit the loop
    frame = wx_frame("loop")
    ls%app = app
    ls%button = wx_button(frame, "loop")
    call ls%button%bind(wxEVT_BUTTON, loop_click, data=ls)
    call app%set_exit_on_frame_delete(.false.)
    call wx_call_after(step, ls)
    call check(app%run() == 0, 'main loop exits with code 0')
    call check(ls%step == 3 .and. ls%clicks == 2, 'deferred calls and clicks ran inside the main loop')
    call check(.not. app%is_main_loop_running(), 'main loop stopped')

    ! the loop can be run again
    ls%step = 0
    call wx_call_after(step, ls)
    call check(app%run() == 0 .and. ls%clicks == 4, 'main loop runs a second time')
    call frame%destroy()
    call app%process_pending()
    call check(wx_active_handlers() == base_handlers, 'no handlers or deferred calls left')

end program test_events

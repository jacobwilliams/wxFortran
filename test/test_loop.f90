!> Main-loop tests: events queued for the event loop (as real user input
!> is), calls not allowed while the loop runs, destroying windows from a
!> deferred call, and the normal exit when the last frame is closed.
!> No user interaction needed.
module test_loop_handlers

    use wx
    implicit none

    integer, parameter :: n_posted = 3     !! clicks queued before the loop starts
    integer, parameter :: max_polls = 10000 !! watchdog: give up after this many deferred calls

    !> Shared state for the main-loop test.
    type :: loop_t
        type(wx_app) :: app
        type(wx_frame) :: frame
        type(wx_button) :: button
        type(wx_button) :: spare
        integer :: clicks = 0
        integer :: polls = 0
        integer :: stat_cleanup = -1
        integer :: stat_run = -1
        logical :: running_inside = .false.
        logical :: spare_gone = .false.
        logical :: timed_out = .false.
        logical :: closed = .false.
    end type loop_t

contains

    !> Count clicks; on the first one, try calls that the running loop forbids.
    subroutine on_click(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer :: code
        select type (s => data)
        type is (loop_t)
            s%clicks = s%clicks + 1
            if (s%clicks == 1) then
                s%running_inside = s%app%is_main_loop_running()
                call s%app%cleanup(stat=s%stat_cleanup)
                code = s%app%run(stat=s%stat_run)
            end if
        end select
    end subroutine on_click

    !> Poll (re-scheduling itself) until the queued clicks are delivered, then
    !> destroy a child window (immediately: no event is being handled) and
    !> close the frame, which should end the loop by itself.
    subroutine poll(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (loop_t)
            s%polls = s%polls + 1
            if (s%polls > max_polls) then
                s%timed_out = .true.
                call s%app%exit_main_loop()
            else if (s%clicks < n_posted) then
                call wx_call_after(poll, s)
            else
                call s%spare%destroy()
                s%spare_gone = .not. s%spare%is_valid()
                s%closed = s%frame%close()
            end if
        end select
    end subroutine poll

end module test_loop_handlers


!> Runs the main-loop tests.
program test_loop

    use wx
    use testing
    use test_loop_handlers
    implicit none

    type(loop_t), target :: s
    integer :: i, code, base_handlers

    s%app = wx_app()
    base_handlers = wx_active_handlers()

    s%frame = wx_frame("loop")
    s%button = wx_button(s%frame, "button")
    s%spare = wx_button(s%frame, "spare")
    call s%button%bind(wxEVT_BUTTON, on_click, data=s)
    call s%frame%show()

    ! queued clicks are delivered by the event loop, not by post_click itself
    do i = 1, n_posted
        call s%button%post_click()
    end do
    call check(s%clicks == 0, 'post_click does not run handlers before returning')

    call wx_call_after(poll, s)
    code = s%app%run()

    call check(.not. s%timed_out, 'queued clicks delivered (no watchdog timeout)')
    call check(code == 0, 'main loop exit code 0')
    call check(s%clicks == n_posted, 'every queued click delivered once inside the loop')
    call check(s%running_inside, 'is_main_loop_running is true inside a handler')
    call check(s%stat_cleanup == WX_ERR_STATE, 'cleanup inside the loop fails with WX_ERR_STATE')
    call check(s%stat_run == WX_ERR_STATE, 'a nested run fails with WX_ERR_STATE')
    call check(s%spare_gone, 'child destroyed from a deferred call is invalid at once')
    call check(s%closed, 'frame close from a deferred call not vetoed')
    call check(.not. s%frame%is_valid(), 'closing the last frame ended the loop and destroyed it')
    call check(.not. s%app%is_main_loop_running(), 'main loop no longer running')
    call check(wx_active_handlers() == base_handlers, 'no handlers or deferred calls left')

    call s%app%cleanup()

end program test_loop

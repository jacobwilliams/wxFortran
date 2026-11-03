!> Timer tests: argument checks, a repeating timer in the real event loop, a
!> one-shot timer that destroys timers from inside handlers (including its
!> own), ownership by a window, and cleanup. A watchdog timer ends the loop
!> if something hangs. No user interaction needed.
module test_timer_handlers

    use wx
    implicit none

    integer, parameter :: n_ticks = 3   !! ticks of the repeating timer

    !> State shared by the timer handlers.
    type :: timer_state
        type(wx_app) :: app
        type(wx_timer) :: repeating
        type(wx_timer) :: once
        type(wx_timer) :: watchdog
        integer :: ticks = 0
        integer :: once_calls = 0
        logical :: timed_out = .false.
        logical :: source_ok = .false.
        logical :: invalid_inside = .false.
        logical :: once_was_running = .true.
    end type timer_state

contains

    !> Repeating timer: after `n_ticks` ticks, stop and start the one-shot timer.
    subroutine on_tick(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (timer_state)
            s%ticks = s%ticks + 1
            if (s%ticks == 1) s%source_ok = event%source() == s%repeating
            if (s%ticks == n_ticks) then
                call s%repeating%stop()
                call s%once%start(20, one_shot=.true.)
            end if
        end select
    end subroutine on_tick

    !> One-shot timer: destroy both timers (itself too), then leave the loop.
    subroutine on_once(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (timer_state)
            s%once_calls = s%once_calls + 1
            s%once_was_running = s%once%is_running()
            call s%repeating%destroy()
            call s%once%destroy()
            s%invalid_inside = .not. s%repeating%is_valid() .and. .not. s%once%is_valid()
            call s%watchdog%stop()
            call s%app%exit_main_loop()
        end select
    end subroutine on_once

    !> Watchdog: give up.
    subroutine on_watchdog(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (timer_state)
            s%timed_out = .true.
            call s%app%exit_main_loop()
        end select
    end subroutine on_watchdog

end module test_timer_handlers


!> Runs the timer tests.
program test_timer

    use wx
    use testing
    use test_timer_handlers
    implicit none

    type(timer_state), target :: s
    type(wx_frame) :: frame
    type(wx_timer) :: t, owned, orphan
    integer :: stat, code, base_handlers, base_objects, calls
    integer, target :: unused

    s%app = wx_app()
    base_handlers = wx_active_handlers()
    base_objects = wx_live_objects()

    ! --- basic state and argument checks (no loop needed)
    t = wx_timer()
    call check(t%is_valid() .and. .not. t%is_running(), 'new timer is valid and stopped')
    call t%start(0, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a zero interval fails with WX_ERR_ARGUMENT')
    call t%start(1000)
    call check(t%is_running() .and. t%get_interval() == 1000, 'started timer runs with its interval')
    call t%stop()
    call check(.not. t%is_running(), 'stopped')
    call t%destroy()
    call check(.not. t%is_valid(), 'destroyed timer is invalid')
    call t%start(10, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'using a destroyed timer fails cleanly')

    ! --- the event loop: repeating ticks, then a one-shot that destroys timers
    s%repeating = wx_timer()
    s%once = wx_timer()
    s%watchdog = wx_timer()
    call s%repeating%bind(wxEVT_TIMER, on_tick, data=s)
    call s%once%bind(wxEVT_TIMER, on_once, data=s)
    call s%watchdog%bind(wxEVT_TIMER, on_watchdog, data=s)
    call s%watchdog%start(10000, one_shot=.true.)
    call s%repeating%start(5)
    code = s%app%run()
    call check(.not. s%timed_out, 'timers fired before the watchdog')
    call check(s%ticks == n_ticks, 'repeating timer ticked until stopped')
    call check(s%source_ok, 'timer event source is the timer')
    call check(s%once_calls == 1, 'one-shot timer fired once')
    call check(.not. s%once_was_running, 'a one-shot timer is not running in its handler')
    call check(s%invalid_inside, 'timers destroyed from a handler are invalid at once')
    call s%app%process_pending()
    call s%watchdog%destroy()
    call check(wx_active_handlers() == base_handlers, 'handlers of destroyed timers released')
    call check(wx_live_objects() == base_objects, 'no live objects left')

    ! --- a timer owned by a window is destroyed with it
    frame = wx_frame("owner")
    owned = wx_timer(owner=frame)
    call owned%bind(wxEVT_TIMER, on_tick, data=unused)
    call owned%start(1000)
    call frame%destroy()
    call s%app%process_pending()
    call check(.not. owned%is_valid(), 'owned timer destroyed with its window')
    call check(wx_active_handlers() == base_handlers, 'owned timer''s handler released')
    t = wx_timer(owner=frame, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE .and. .not. t%is_valid(), 'a destroyed owner is rejected')

    ! --- cleanup deletes timers nobody destroyed
    orphan = wx_timer()
    call orphan%start(1000)
    calls = wx_live_objects()
    call check(calls == base_objects + 1, 'orphan timer alive before cleanup')
    call s%app%cleanup()
    call check(.not. orphan%is_valid(), 'cleanup destroys remaining timers')

end program test_timer

!> Lifetime tests: handlers that destroy windows (including the one whose
!> event they handle), disconnect other handlers, or observe destruction.
!> No user interaction needed.
module test_lifetime_handlers

    use wx
    implicit none

    !> Windows a handler acts on, and what it saw.
    type :: scene
        type(wx_frame) :: frame
        type(wx_panel) :: panel
        type(wx_button) :: button
        type(wx_button) :: other
        type(wx_connection) :: victim
        integer :: calls = 0
        integer :: other_calls = 0
        logical :: invalid_inside = .false.
        integer :: stat_inside = -1
    end type scene

    type(wx_object), save :: destroyed_source
    integer, save :: destroy_calls = 0
    integer, save :: destroy_stat = -1

contains

    !> Destroy the button whose click is being handled.
    subroutine destroy_self(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%calls = s%calls + 1
            call s%button%destroy()
            s%invalid_inside = .not. s%button%is_valid()
            call s%button%set_label("gone", stat=s%stat_inside)
        end select
    end subroutine destroy_self

    !> Destroy the panel containing the clicked button.
    subroutine destroy_parent(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%calls = s%calls + 1
            call s%panel%destroy()
            s%invalid_inside = .not. s%button%is_valid() .and. .not. s%panel%is_valid()
        end select
    end subroutine destroy_parent

    !> Destroy the frame containing the clicked button.
    subroutine destroy_frame(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%calls = s%calls + 1
            call s%frame%destroy()
            s%invalid_inside = .not. s%button%is_valid()
        end select
    end subroutine destroy_frame

    !> Disconnect `victim` (bound earlier to the same event) and pass the event on.
    subroutine disconnect_victim(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%calls = s%calls + 1
            call s%victim%disconnect()
        end select
        call event%skip()
    end subroutine disconnect_victim

    !> Count calls in `other_calls`.
    subroutine count_other(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%other_calls = s%other_calls + 1
        end select
        call event%skip()
    end subroutine count_other

    !> Queue a click on `other`, then destroy `other`.
    subroutine post_then_destroy(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%calls = s%calls + 1
            call s%other%post_click()
            call s%other%destroy()
        end select
    end subroutine post_then_destroy

    !> Observe a window's destruction.
    subroutine on_destroy(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_window) :: w
        destroy_calls = destroy_calls + 1
        destroyed_source = event%source()
        w = wx_window(destroyed_source)
        call w%set_label("x", stat=destroy_stat)
        call event%skip()
    end subroutine on_destroy

end module test_lifetime_handlers


!> Runs the lifetime tests.
program test_lifetime

    use wx
    use testing
    use test_lifetime_handlers
    implicit none

    type(wx_app) :: app
    type(scene), target :: s
    integer :: base_handlers, base_objects

    app = wx_app()
    base_handlers = wx_active_handlers()
    base_objects = wx_live_objects()

    ! --- a click handler destroys its own button
    call build(s)
    call s%button%bind(wxEVT_BUTTON, destroy_self, data=s)
    call s%button%emit_click()
    call check(s%calls == 1, 'destroy-self handler ran')
    call check(s%invalid_inside, 'button invalid inside the handler right after destroy')
    call check(s%stat_inside == WX_ERR_INVALID_HANDLE, 'using it inside the handler fails cleanly')
    call app%process_pending()
    call check(s%panel%child_count() == 0, 'button deleted after pending events are processed')
    call s%button%emit_click(stat=s%stat_inside)
    call check(s%stat_inside == WX_ERR_INVALID_HANDLE .and. s%calls == 1, 'no more clicks on it')
    call teardown(s)

    ! --- a click handler destroys the button's parent panel
    call build(s)
    call s%button%bind(wxEVT_BUTTON, destroy_parent, data=s)
    call s%button%emit_click()
    call check(s%calls == 1 .and. s%invalid_inside, 'parent panel and button invalid inside the handler')
    call app%process_pending()
    call check(s%frame%child_count() == 1, 'panel deleted after pending events are processed')
    call check(wx_active_handlers() == base_handlers, 'handlers of the destroyed panel released')
    call teardown(s)

    ! --- a click handler destroys the whole frame
    call build(s)
    call s%button%bind(wxEVT_BUTTON, destroy_frame, data=s)
    call s%button%emit_click()
    call check(s%calls == 1 .and. s%invalid_inside, 'frame descendants invalid inside the handler')
    call app%process_pending()
    call check(.not. s%frame%is_valid(), 'frame destroyed by its child''s handler')
    call check(wx_active_handlers() == base_handlers, 'handlers released')
    call check(wx_live_objects() == base_objects, 'no live objects left')

    ! --- a handler disconnects another handler of the same event
    ! (handlers bound later run first in wxWidgets)
    call build(s)
    call s%button%bind(wxEVT_BUTTON, count_other, data=s, connection=s%victim)
    call s%button%bind(wxEVT_BUTTON, disconnect_victim, data=s)
    call s%button%emit_click()
    call check(s%calls == 1 .and. s%other_calls == 0, 'handler disconnected by an earlier one is not called')
    call check(.not. s%victim%is_connected(), 'victim disconnected')
    call s%button%emit_click()
    call check(s%calls == 2 .and. s%other_calls == 0, 'still not called on the next event')
    call teardown(s)

    ! --- an event queued for a window destroyed before delivery is dropped
    call build(s)
    call s%other%bind(wxEVT_BUTTON, count_other, data=s)
    call s%button%bind(wxEVT_BUTTON, post_then_destroy, data=s)
    call s%button%emit_click()
    call app%process_pending()
    call app%process_pending()
    call check(s%calls == 1 .and. s%other_calls == 0, 'queued click on a destroyed button not delivered')
    call check(.not. s%other%is_valid(), 'destroyed button invalid')
    call teardown(s)

    ! --- destroy handlers see the dying window, which is already invalid
    call build(s)
    call s%frame%bind(wxEVT_DESTROY, on_destroy)
    destroy_calls = 0
    call s%frame%destroy()
    call app%process_pending()
    call check(destroy_calls == 1, 'destroy handler called once (not for the children)')
    call check(destroyed_source == s%frame, 'destroy event source is the frame')
    call check(destroy_stat == WX_ERR_INVALID_HANDLE, 'the dying window cannot be used')
    call check(wx_active_handlers() == base_handlers, 'destroy handler released')
    call check(wx_live_objects() == base_objects, 'no live objects left at the end')

contains

    !> A frame holding a panel (with `button`) and `other`; reset the counters.
    subroutine build(s)
        type(scene), intent(inout) :: s
        s%calls = 0
        s%other_calls = 0
        s%invalid_inside = .false.
        s%stat_inside = -1
        s%frame = wx_frame("lifetime")
        s%panel = wx_panel(s%frame)
        s%button = wx_button(s%panel, "button")
        s%other = wx_button(s%frame, "other")
    end subroutine build

    !> Destroy the scene's frame and process the deletion.
    subroutine teardown(s)
        type(scene), intent(inout) :: s
        if (s%frame%is_valid()) call s%frame%destroy()
        call app%process_pending()
        call check(wx_active_handlers() == base_handlers .and. wx_live_objects() == base_objects, &
                   'scene torn down without leaks')
    end subroutine teardown

end program test_lifetime

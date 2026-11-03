!> Core tests: application state, errors, strings, window properties,
!> parent/child lifetime and sizer ownership. No user interaction needed.
program test_core

    use wx
    use testing
    implicit none

    type(wx_app) :: app, app2
    type(wx_frame) :: frame, frame2
    type(wx_panel) :: panel
    type(wx_button) :: button, stale
    type(wx_static_text) :: label
    type(wx_text_ctrl) :: text
    type(wx_check_box) :: box
    type(wx_box_sizer) :: sizer, inner, loose
    type(wx_window) :: parent
    integer :: stat, w, h, i, base
    character(len=*), parameter :: unicode = 'h' // char(195) // char(169) // 'llo ' // &
                                             char(226) // char(156) // char(147)   ! "héllo ✓" in UTF-8

    ! --- before initialization
    frame = wx_frame("too early", stat=stat)
    call check(stat == WX_ERR_NO_APP, 'creating a window before wx_app fails with WX_ERR_NO_APP')
    call check(.not. frame%is_valid(), 'failed creation leaves an invalid wrapper')
    call check(len(wx_last_error()) > 0, 'wx_last_error gives a message')

    app = wx_app()
    app2 = wx_app(stat=stat)
    call check(stat == WX_ERR_STATE, 'second wx_app fails with WX_ERR_STATE')
    call check(.not. app%is_main_loop_running(), 'main loop not running yet')

    base = wx_live_objects()

    ! --- invalid handles
    call button%set_label("x", stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'default-initialized wrapper is an invalid handle')
    call check(index(wx_last_error(), 'null handle') > 0, 'error message names the null handle')

    ! --- frames and strings
    frame = wx_frame("Test frame", width=400, height=300)
    call check(frame%is_valid(), 'frame created')
    call check(frame%get_title() == "Test frame", 'frame title round-trips')
    call frame%set_title(unicode)
    call check(frame%get_title() == unicode, 'non-ASCII UTF-8 title round-trips')
    call frame%set_title("")
    call check(frame%get_title() == "", 'empty title round-trips')
    call frame%get_size(w, h)
    call check(w == 400 .and. h == 300, 'frame size from constructor')
    call frame%set_size(500, 350)
    call frame%get_size(w, h)
    call check(w == 500 .and. h == 350, 'set_size / get_size')
    call check(.not. frame%is_shown(), 'new frame is hidden')

    ! --- children
    panel = wx_panel(frame)
    label = wx_static_text(panel, "Name:")
    button = wx_button(panel, "OK")
    text = wx_text_ctrl(panel, value="initial")
    box = wx_check_box(panel, "Option", checked=.true.)
    call check(panel%child_count() == 4, 'panel has four children')
    call check(button%get_label() == "OK", 'button label')
    call button%set_label(unicode)
    call check(button%get_label() == unicode, 'non-ASCII button label round-trips')
    call check(text%get_value() == "initial", 'text control initial value')
    call text%change_value("changed")
    call check(text%get_value() == "changed", 'change_value')
    call text%append_text("!")
    call check(text%get_value() == "changed!", 'append_text')
    call text%clear()
    call check(text%get_value() == "", 'clear')
    call check(box%get_value(), 'check box created checked')
    call box%set_value(.false.)
    call check(.not. box%get_value(), 'check box unchecked')
    call check(button%is_enabled(), 'button enabled by default')
    call button%disable()
    call check(.not. button%is_enabled(), 'button disabled')
    call button%enable()
    parent = button%get_parent()
    call check(parent == panel, 'get_parent returns the panel')
    call check(.not. (parent == frame), 'get_parent is not the frame')
    parent = frame%get_parent()
    call check(.not. parent%is_valid(), 'a top-level frame has no parent')

    ! wrong type for a call: a static text is not a top-level window
    stale%h = label%h
    call stale%emit_click(stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'calling a button method on a static text fails')

    ! --- sizers
    sizer = wx_box_sizer(wxVERTICAL)
    inner = wx_box_sizer(wxHORIZONTAL)
    call inner%add(button)
    call inner%add_stretch()
    call sizer%add(label, flags=wxALL, border=5)
    call sizer%add(text, proportion=1, flags=ior(wxEXPAND, wxALL), border=5)
    call sizer%add(inner, flags=wxEXPAND)
    call sizer%add_spacer(10)
    call check(sizer%item_count() == 4, 'sizer has four items')
    call sizer%add(inner, stat=stat)
    call check(stat == WX_ERR_STATE, 'a sizer cannot be added twice')
    call panel%set_sizer(sizer, fit=.true.)
    call panel%layout()
    call check(sizer%is_valid() .and. inner%is_valid(), 'sizers valid while owned by a live panel')
    loose = wx_box_sizer(wxVERTICAL)
    call loose%destroy()
    call check(.not. loose%is_valid(), 'an unattached sizer can be destroyed')
    loose = wx_box_sizer(42, stat=stat)
    call check(stat == WX_ERR_ARGUMENT .and. .not. loose%is_valid(), 'bad sizer orientation fails')
    ! replacing the panel's sizer destroys the old one (and its nested sizer)
    loose = wx_box_sizer(wxHORIZONTAL)
    call panel%set_sizer(loose)
    call check(.not. sizer%is_valid() .and. .not. inner%is_valid(), 'replaced sizer tree is invalid')

    ! --- destroying a child window
    call box%destroy()
    call check(.not. box%is_valid(), 'destroyed child is invalid')
    call check(panel%child_count() == 3, 'destroyed child removed from parent')
    call box%set_value(.true., stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'using a destroyed child fails cleanly')

    ! --- destroying the frame invalidates all descendants immediately
    call frame%destroy()
    call check(.not. frame%is_valid(), 'destroyed frame is invalid immediately')
    call app%process_pending()
    call check(.not. panel%is_valid() .and. .not. button%is_valid() .and. &
               .not. label%is_valid() .and. .not. text%is_valid(), 'children invalid after parent destroyed')
    call check(.not. loose%is_valid(), 'sizer of a destroyed window is invalid')
    call check(wx_live_objects() == base, 'no live objects left')

    ! --- child frames die with their parent frame
    frame = wx_frame("parent")
    frame2 = wx_frame("child", parent=frame)
    call check(frame2%get_parent() == frame, 'child frame has its parent')
    call frame%destroy()
    call app%process_pending()
    call check(.not. frame2%is_valid(), 'child frame destroyed with its parent')

    ! --- repeated creation/destruction
    do i = 1, 200
        frame = wx_frame("loop")
        panel = wx_panel(frame)
        button = wx_button(panel, "b")
        call frame%destroy()
    end do
    call app%process_pending()
    call check(wx_live_objects() == base, 'repeated create/destroy leaves no live objects')

    ! --- cleanup
    frame = wx_frame("left over")
    call app%cleanup()
    call check(.not. frame%is_valid(), 'cleanup destroys remaining windows')
    frame = wx_frame("after cleanup", stat=stat)
    call check(stat == WX_ERR_NO_APP, 'no windows after cleanup')

end program test_core

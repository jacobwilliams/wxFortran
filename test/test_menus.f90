!> Menu and status bar tests: building menus, item state, menu events (per
!> id and for any id, check and radio items, submenus), ownership rules,
!> replacing a menu bar, status bar fields, and quitting from a menu inside
!> the event loop. No user interaction needed.
module test_menus_handlers

    use wx
    implicit none

    !> Records menu events.
    type :: menu_log
        integer :: any_calls = 0
        integer :: open_calls = 0
        integer :: menu_calls = 0
        integer :: last_id = 0
        logical :: last_checked = .false.
        type(wx_object) :: last_source
    end type menu_log

    !> State for quitting from a menu inside the loop.
    type :: quit_state
        type(wx_frame) :: frame
        type(wx_menu) :: file
        integer :: quit_calls = 0
    end type quit_state

contains

    !> Any menu event on the frame: record it and let it go on.
    subroutine on_any(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (log => data)
        type is (menu_log)
            log%any_calls = log%any_calls + 1
            log%last_id = event%get_id()
            log%last_checked = event%is_checked()
            log%last_source = event%source()
        end select
        call event%skip()
    end subroutine on_any

    !> The "Open" item only.
    subroutine on_open(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (log => data)
        type is (menu_log)
            log%open_calls = log%open_calls + 1
        end select
        call event%skip()
    end subroutine on_open

    !> Any item, bound on the menu itself (runs before the frame's handlers).
    subroutine on_menu(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (log => data)
        type is (menu_log)
            log%menu_calls = log%menu_calls + 1
        end select
        call event%skip()
    end subroutine on_menu

    !> wxID_EXIT: close the frame, which ends the loop.
    subroutine on_quit(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        logical :: closed
        select type (q => data)
        type is (quit_state)
            q%quit_calls = q%quit_calls + 1
            closed = q%frame%close()
        end select
    end subroutine on_quit

    !> Deferred call: choose File > Quit.
    subroutine choose_quit(data)
        class(*), intent(inout), optional :: data
        select type (q => data)
        type is (quit_state)
            call q%file%emit_select(wxID_EXIT)
        end select
    end subroutine choose_quit

end module test_menus_handlers


!> Runs the menu tests.
program test_menus

    use wx
    use testing
    use test_menus_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame
    type(wx_menu_bar) :: bar, bar2, loose_bar
    type(wx_menu) :: file, view, sub, help, loose
    type(menu_log), target :: log
    type(quit_state), target :: q
    integer :: id_open, id_check, id_radio1, id_radio2, id_sub, id_quit, id_x
    integer :: stat, code, base_handlers, base_objects
    character(len=*), parameter :: tab = achar(9)

    app = wx_app()
    base_handlers = wx_active_handlers()
    base_objects = wx_live_objects()

    ! --- building
    frame = wx_frame("menus")
    bar = wx_menu_bar()
    file = wx_menu()
    view = wx_menu()
    sub = wx_menu()
    id_open = file%append("&Open..."//tab//"Ctrl+O", help="Open a file")
    call file%append_separator()
    id_quit = file%append(id=wxID_EXIT)
    call check(id_quit == wxID_EXIT, 'stock item keeps its id')
    call check(id_open /= wxID_ANY .and. id_open /= id_quit, 'generated item id')
    id_check = view%append("Show &grid", kind=wxITEM_CHECK)
    id_radio1 = view%append("Small", kind=wxITEM_RADIO)
    id_radio2 = view%append("Large", kind=wxITEM_RADIO)
    id_sub = sub%append("Deep item")
    call view%append_submenu(sub, "&More")
    call check(file%item_count() == 3 .and. view%item_count() == 4, 'item counts')
    call bar%append(file, "&File")
    call bar%append(view, "&View")
    call check(bar%menu_count() == 2, 'menu bar has two menus')
    call frame%set_menu_bar(bar)
    call frame%create_status_bar()

    ! --- argument and ownership errors
    id_x = file%append("", stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'empty text needs a stock id')
    id_x = file%append("Again", id=id_open, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'duplicate item id rejected')
    id_x = file%append("Bad", kind=7, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'bad item kind rejected')
    call bar%append(file, "Twice", stat=stat)
    call check(stat == WX_ERR_STATE, 'a menu cannot be appended twice')
    call file%destroy(stat=stat)
    call check(stat == WX_ERR_STATE .and. file%is_valid(), 'an attached menu cannot be destroyed')
    call bar%destroy(stat=stat)
    call check(stat == WX_ERR_STATE .and. bar%is_valid(), 'an attached menu bar cannot be destroyed')
    call view%append_submenu(view, "Self", stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a menu cannot contain itself')
    call file%check(id_open, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a normal item cannot be checked')
    call file%enable(12345, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'unknown item id rejected')

    ! --- item state
    call check(file%get_label(id_open) == "Open...", 'label without mnemonic and accelerator')
    call check(len(file%get_label(wxID_EXIT)) > 0, 'stock item gets a standard label')
    call file%set_label(id_open, "&Load")
    call check(file%get_label(id_open) == "Load", 'set_label')
    call check(file%is_enabled(id_open), 'items enabled by default')
    call file%enable(id_open, .false.)
    call check(.not. file%is_enabled(id_open), 'item disabled')
    call file%emit_select(id_open, stat=stat)
    call check(stat == WX_ERR_STATE, 'a disabled item cannot be selected')
    call file%enable(id_open)
    call check(.not. view%is_checked(id_check), 'check item starts unchecked')
    call check(view%is_checked(id_radio1) .and. .not. view%is_checked(id_radio2), 'first radio item checked')
    call check(view%is_checked(id_sub, stat=stat) .eqv. .false., 'is_checked on a normal item fails')
    call check(stat == WX_ERR_ARGUMENT, '... with WX_ERR_ARGUMENT')

    ! --- events: per id and any id on the frame, and on the menu itself
    call frame%bind(wxEVT_MENU, on_any, data=log)
    call frame%bind(wxEVT_MENU, on_open, data=log, id=id_open)
    call file%bind(wxEVT_MENU, on_menu, data=log)
    call file%emit_select(id_open)
    call check(log%open_calls == 1 .and. log%any_calls == 1, 'per-id and any-id frame handlers called')
    call check(log%menu_calls == 1, 'handler on the menu called')
    call check(log%last_id == id_open, 'event id is the item id')
    call check(log%last_source == file, 'event source is the menu')
    call view%emit_select(id_check)
    call check(log%open_calls == 1 .and. log%any_calls == 2, 'per-id handler not called for other items')
    call check(log%menu_calls == 1, 'a menu''s handler is not called for other menus')
    call check(log%last_checked .and. view%is_checked(id_check), 'check item toggled on, event says checked')
    call view%emit_select(id_check)
    call check(.not. log%last_checked .and. .not. view%is_checked(id_check), 'check item toggled off')
    call view%emit_select(id_radio2)
    call check(view%is_checked(id_radio2) .and. .not. view%is_checked(id_radio1), 'radio selection moves')
    call view%emit_select(id_sub)
    call check(log%last_id == id_sub .and. log%last_source == sub, 'submenu item found and sent from its menu')
    call view%check(id_check)
    call check(view%is_checked(id_check) .and. log%any_calls == 5, 'check() sends no event')

    ! --- status bar
    call frame%set_status_text("x", field=1, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'status field out of range')
    call frame%create_status_bar(2)
    call check(frame%status_field_count() == 2, 'status bar has two fields')
    call frame%set_status_text("Ready")
    call frame%set_status_text("Line 1", field=1)
    call check(frame%get_status_text() == "Ready" .and. frame%get_status_text(1) == "Line 1", &
               'status texts')

    ! --- replacing the menu bar destroys the old one and its menus
    bar2 = wx_menu_bar()
    help = wx_menu()
    id_x = help%append(id=wxID_ABOUT)
    call bar2%append(help, "&Help")
    call frame%set_menu_bar(bar2)
    call check(.not. bar%is_valid() .and. .not. file%is_valid() .and. .not. sub%is_valid(), &
               'old menu bar and its menus destroyed')
    call file%emit_select(id_open, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'using a destroyed menu fails cleanly')
    call frame%set_menu_bar(bar2)
    call check(bar2%is_valid(), 'setting the same menu bar again is harmless')

    ! --- unattached menus and menu bars
    loose = wx_menu()
    call loose%destroy()
    call check(.not. loose%is_valid(), 'an unattached menu can be destroyed')
    loose_bar = wx_menu_bar()
    call loose_bar%destroy()
    call check(.not. loose_bar%is_valid(), 'an unattached menu bar can be destroyed')

    ! --- destroying the frame releases everything
    call frame%destroy()
    call app%process_pending()
    call check(.not. bar2%is_valid() .and. .not. help%is_valid(), 'menus destroyed with the frame')
    call check(wx_active_handlers() == base_handlers, 'menu handlers released')
    call check(wx_live_objects() == base_objects, 'no live objects left')

    ! --- File > Quit inside the event loop closes the frame and ends the loop
    q%frame = wx_frame("quit")
    bar = wx_menu_bar()
    q%file = wx_menu()
    id_x = q%file%append(id=wxID_EXIT)
    call bar%append(q%file, "&File")
    call q%frame%set_menu_bar(bar)
    call q%frame%bind(wxEVT_MENU, on_quit, data=q, id=wxID_EXIT)
    call q%frame%show()
    call wx_call_after(choose_quit, q)
    code = app%run()
    call check(code == 0 .and. q%quit_calls == 1, 'quit handler ran inside the loop')
    call check(.not. q%frame%is_valid(), 'quitting from the menu closed the frame and ended the loop')

    ! --- cleanup deletes unattached menus and menu bars
    loose = wx_menu()
    id_x = loose%append("Item")
    loose_bar = wx_menu_bar()
    call app%cleanup()
    call check(.not. loose%is_valid() .and. .not. loose_bar%is_valid(), 'cleanup deletes unattached menus')

end program test_menus

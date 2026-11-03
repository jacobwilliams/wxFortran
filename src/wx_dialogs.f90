!> Standard modal dialogs: message box, file and directory pickers, text
!> entry, single choice, color picker and the About box.
!>
!> Each dialog blocks until the user answers it (it runs its own event loop:
!> timers and other windows keep working) and must be called on the GUI
!> thread, after `wx_app()`. Functions return `.true.` if the user accepted,
!> `.false.` if they cancelled; `wx_message_box` returns the button chosen.
!>
!> ```fortran
!> if (wx_message_box('Save changes?', 'Editor', ior(wxYES_NO, wxCANCEL)) == wxID_YES) ...
!> if (wx_file_save_dialog(path, wildcard='PNG images (*.png)|*.png')) call canvas%save_png(path)
!> ```
!>
!> ### Testing code that uses dialogs
!>
!> `wx_queue_dialog_answer` scripts the answer of the next dialog, which then
!> returns it at once without being shown. With `wx_set_dialog_test_mode(.true.)`
!> a dialog without a queued answer fails with `WX_ERR_STATE` instead of
!> waiting for a user. `wx_last_dialog` tells what the last dialog showed.
module wx_dialogs

    use iso_c_binding
    use wx_c_core
    use wx_c_dialogs
    use wx_base
    use wx_colors
    use wx_windows, only: wx_window
    implicit none
    private

    public :: wxOK, wxCANCEL, wxYES_NO
    public :: wxICON_INFORMATION, wxICON_WARNING, wxICON_ERROR, wxICON_QUESTION
    public :: wxID_OK, wxID_CANCEL, wxID_YES, wxID_NO
    public :: wx_message_box, wx_file_open_dialog, wx_file_open_multiple_dialog
    public :: wx_file_save_dialog, wx_dir_dialog, wx_text_entry_dialog, wx_choice_dialog
    public :: wx_color_dialog, wx_about_box
    public :: wx_queue_dialog_answer, wx_clear_dialog_answers, wx_queued_dialog_answers
    public :: wx_set_dialog_test_mode, wx_last_dialog

contains

    !> `x`, or `default` if `x` is absent.
    function opt(x, default) result(s)
        character(len=*), intent(in), optional :: x
        character(len=*), intent(in) :: default
        character(len=:), allocatable :: s
        if (present(x)) then
            s = x
        else
            s = default
        end if
    end function opt

    !> The handle of an optional parent window (0 if absent).
    integer(c_int64_t) function parent_handle(parent)
        class(wx_window), intent(in), optional :: parent
        parent_handle = 0
        if (present(parent)) parent_handle = parent%h
    end function parent_handle

    ! -------------------------------------------------------------------------
    ! dialogs

    !> Show `message` with `caption` (default "Message") and return the
    !> button chosen: `wxID_OK`, `wxID_CANCEL`, `wxID_YES` or `wxID_NO`.
    !> `style` combines buttons (`wxOK` (default), `wxOK + wxCANCEL`,
    !> `wxYES_NO`, `wxYES_NO + wxCANCEL`) with an icon (`wxICON_*`).
    integer function wx_message_box(message, caption, style, parent, stat) result(button)
        character(len=*), intent(in) :: message
        character(len=*), intent(in), optional :: caption
        integer, intent(in), optional :: style
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: cap
        integer(c_int) :: st, b
        cap = opt(caption, 'Message')
        st = wxOK
        if (present(style)) st = int(style, c_int)
        b = wxID_CANCEL
        call wx_check(wxf_message_box(parent_handle(parent), message, len(message, c_int), cap, len(cap, c_int), &
                                      st, b), stat)
        button = b
    end function wx_message_box

    !> Choose an existing file to open. `wildcard` filters the files shown:
    !> `'Text files (*.txt)|*.txt|All files (*.*)|*.*'` (default: all files).
    !> `must_exist` (default true) refuses names of missing files.
    logical function wx_file_open_dialog(path, message, wildcard, default_dir, default_file, must_exist, &
                                         parent, stat) result(ok)
        character(len=:), allocatable, intent(out) :: path
        character(len=*), intent(in), optional :: message, wildcard, default_dir, default_file
        logical, intent(in), optional :: must_exist
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        type(wx_string), allocatable :: paths(:)
        integer :: flags
        flags = 1
        if (present(must_exist)) flags = merge(1, 0, must_exist)
        ok = file_dialog(0, paths, opt(message, 'Open file'), opt(wildcard, ''), opt(default_dir, ''), &
                         opt(default_file, ''), flags, parent, stat)
        path = ''
        if (ok) path = paths(1)%s
    end function wx_file_open_dialog

    !> Choose one or more existing files to open (arguments as for
    !> [[wx_file_open_dialog]]).
    logical function wx_file_open_multiple_dialog(paths, message, wildcard, default_dir, parent, stat) result(ok)
        type(wx_string), allocatable, intent(out) :: paths(:)
        character(len=*), intent(in), optional :: message, wildcard, default_dir
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        ok = file_dialog(1, paths, opt(message, 'Open files'), opt(wildcard, ''), opt(default_dir, ''), '', &
                         1, parent, stat)
    end function wx_file_open_multiple_dialog

    !> Choose a file name to save to. `overwrite_prompt` (default true) asks
    !> before replacing an existing file. Note: `wildcard` does not add an
    !> extension to the name typed.
    logical function wx_file_save_dialog(path, message, wildcard, default_dir, default_file, overwrite_prompt, &
                                         parent, stat) result(ok)
        character(len=:), allocatable, intent(out) :: path
        character(len=*), intent(in), optional :: message, wildcard, default_dir, default_file
        logical, intent(in), optional :: overwrite_prompt
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        type(wx_string), allocatable :: paths(:)
        integer :: flags
        flags = 2
        if (present(overwrite_prompt)) flags = merge(2, 0, overwrite_prompt)
        ok = file_dialog(2, paths, opt(message, 'Save file'), opt(wildcard, ''), opt(default_dir, ''), &
                         opt(default_file, ''), flags, parent, stat)
        path = ''
        if (ok) path = paths(1)%s
    end function wx_file_save_dialog

    !> Common part of the file dialogs.
    logical function file_dialog(mode, paths, message, wildcard, dir, file, flags, parent, stat) result(ok)
        integer, intent(in) :: mode, flags
        type(wx_string), allocatable, intent(out) :: paths(:)
        character(len=*), intent(in) :: message, wildcard, dir, file
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        type(c_ptr) :: p
        integer(c_int) :: status, okc, plen
        okc = 0
        plen = 0
        p = c_null_ptr
        status = wxf_file_dialog(parent_handle(parent), int(mode, c_int), message, len(message, c_int), &
                                 dir, len(dir, c_int), file, len(file, c_int), wildcard, len(wildcard, c_int), &
                                 int(flags, c_int), okc, p, plen)
        if (status == WX_OK) then
            paths = wx_take_string_list(status, p, plen, stat)
        else
            allocate(paths(0))
            call wx_check(status, stat)
        end if
        ok = status == WX_OK .and. okc /= 0 .and. size(paths) > 0
    end function file_dialog

    !> Choose a directory. `must_exist` (default false) hides the "new
    !> folder" option on some platforms.
    logical function wx_dir_dialog(path, message, default_path, must_exist, parent, stat) result(ok)
        character(len=:), allocatable, intent(out) :: path
        character(len=*), intent(in), optional :: message, default_path
        logical, intent(in), optional :: must_exist
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: msg, dir
        type(c_ptr) :: p
        integer(c_int) :: status, okc, plen, flags
        msg = opt(message, 'Choose a folder')
        dir = opt(default_path, '')
        flags = 0
        if (present(must_exist)) flags = merge(1_c_int, 0_c_int, must_exist)
        okc = 0
        status = wxf_dir_dialog(parent_handle(parent), msg, len(msg, c_int), dir, len(dir, c_int), flags, &
                                okc, p, plen)
        path = wx_take_string(status, p, plen, stat)
        ok = status == WX_OK .and. okc /= 0
    end function wx_dir_dialog

    !> Ask for a line of text; `value` gets it (initially `default_value`).
    !> `password` hides the typed characters.
    logical function wx_text_entry_dialog(value, message, caption, default_value, password, parent, stat) &
            result(ok)
        character(len=:), allocatable, intent(out) :: value
        character(len=*), intent(in) :: message
        character(len=*), intent(in), optional :: caption, default_value
        logical, intent(in), optional :: password
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: cap, def
        type(c_ptr) :: p
        integer(c_int) :: status, okc, olen, pw
        cap = opt(caption, 'Input')
        def = opt(default_value, '')
        pw = 0
        if (present(password)) pw = wx_int(password)
        okc = 0
        status = wxf_text_entry_dialog(parent_handle(parent), message, len(message, c_int), cap, len(cap, c_int), &
                                       def, len(def, c_int), pw, okc, p, olen)
        value = wx_take_string(status, p, olen, stat)
        ok = status == WX_OK .and. okc /= 0
    end function wx_text_entry_dialog

    !> Choose one of `choices` (trailing blanks are ignored); `index` gets
    !> its position (1-based). `initial` is preselected (default 1).
    logical function wx_choice_dialog(index, message, choices, caption, initial, parent, stat) result(ok)
        integer, intent(out) :: index
        character(len=*), intent(in) :: message
        character(len=*), intent(in) :: choices(:)
        character(len=*), intent(in), optional :: caption
        integer, intent(in), optional :: initial
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: cap, buf(:)
        integer(c_int) :: itemlen, n, status, okc, idx, init
        cap = opt(caption, 'Choose')
        call wx_pack_strings(choices, buf, itemlen, n)
        init = 1
        if (present(initial)) init = int(initial, c_int)
        okc = 0
        idx = 0
        status = wxf_choice_dialog(parent_handle(parent), message, len(message, c_int), cap, len(cap, c_int), &
                                   buf, itemlen, n, init, okc, idx)
        call wx_check(status, stat)
        index = idx
        ok = status == WX_OK .and. okc /= 0
    end function wx_choice_dialog

    !> Choose a color; `color` gets it (initially `initial`, default black).
    logical function wx_color_dialog(color, initial, parent, stat) result(ok)
        type(wx_color), intent(out) :: color
        type(wx_color), intent(in), optional :: initial
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        type(wx_color) :: c0
        integer(c_int) :: status, okc, r, g, b, a
        c0 = wxBLACK
        if (present(initial)) c0 = initial
        okc = 0
        status = wxf_color_dialog(parent_handle(parent), int(c0%r, c_int), int(c0%g, c_int), int(c0%b, c_int), &
                                  int(c0%a, c_int), okc, r, g, b, a)
        call wx_check(status, stat)
        color = c0
        if (status == WX_OK) color = wx_color(r, g, b, a)
        ok = status == WX_OK .and. okc /= 0
    end function wx_color_dialog

    !> The standard About box for the program (on macOS: the native one).
    subroutine wx_about_box(name, version, description, copyright, website, parent, stat)
        character(len=*), intent(in) :: name
        character(len=*), intent(in), optional :: version, description, copyright, website
        class(wx_window), intent(in), optional :: parent
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: v, d, c, w
        v = opt(version, '')
        d = opt(description, '')
        c = opt(copyright, '')
        w = opt(website, '')
        call wx_check(wxf_about_box(parent_handle(parent), name, len(name, c_int), v, len(v, c_int), &
                                    d, len(d, c_int), c, len(c, c_int), w, len(w, c_int)), stat)
    end subroutine wx_about_box

    ! -------------------------------------------------------------------------
    ! scripted answers

    !> Queue the answer of a future dialog (answers are used in order, one
    !> per dialog). `button`: for a message box, the button (default its OK
    !> or Yes); for other dialogs `wxID_CANCEL` cancels. `text` answers a
    !> text entry dialog, `path` or `paths` a file or directory dialog,
    !> `index` a choice dialog, `color` a color dialog. An About box takes
    !> any answer.
    subroutine wx_queue_dialog_answer(button, text, path, paths, index, color, stat)
        integer, intent(in), optional :: button, index
        character(len=*), intent(in), optional :: text, path
        character(len=*), intent(in), optional :: paths(:)
        type(wx_color), intent(in), optional :: color
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: t, buf(:)
        integer(c_int) :: b, idx, itemlen, n, has_color
        type(wx_color) :: c
        b = 0
        if (present(button)) b = int(button, c_int)
        idx = 0
        if (present(index)) idx = int(index, c_int)
        t = opt(text, '')
        if (present(path) .and. present(paths)) then
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'wx_queue_dialog_answer: give path or paths, not both'), stat)
            return
        end if
        if (present(path)) then
            call wx_pack_strings([path], buf, itemlen, n)
        else
            call wx_pack_strings(paths, buf, itemlen, n)
        end if
        has_color = 0
        c = wx_color()
        if (present(color)) then
            has_color = 1
            c = color
        end if
        call wx_check(wxf_dialog_queue_answer(b, t, len(t, c_int), wx_int(present(text)), buf, itemlen, n, idx, &
                                              has_color, int(c%r, c_int), int(c%g, c_int), int(c%b, c_int), &
                                              int(c%a, c_int)), stat)
    end subroutine wx_queue_dialog_answer

    !> Drop all queued answers.
    subroutine wx_clear_dialog_answers()
        integer(c_int) :: status
        status = wxf_dialog_clear_answers()
    end subroutine wx_clear_dialog_answers

    !> Number of queued answers not used yet.
    integer function wx_queued_dialog_answers()
        wx_queued_dialog_answers = wxf_dialog_queued_answers()
    end function wx_queued_dialog_answers

    !> In test mode, a dialog without a queued answer fails with
    !> `WX_ERR_STATE` instead of being shown (so tests cannot hang).
    subroutine wx_set_dialog_test_mode(on)
        logical, intent(in) :: on
        integer(c_int) :: status
        status = wxf_dialog_set_test_mode(wx_int(on))
    end subroutine wx_set_dialog_test_mode

    !> What the last dialog (shown or scripted) displayed: `kind` ("message",
    !> "file open", "file save", "directory", "text entry", "choice", "color"
    !> or "about"), its caption and its message.
    subroutine wx_last_dialog(kind, caption, message)
        character(len=:), allocatable, intent(out), optional :: kind, caption, message
        if (present(kind)) kind = last(1)
        if (present(caption)) caption = last(2)
        if (present(message)) message = last(3)
    contains
        !> One field of the last dialog.
        function last(which) result(s)
            integer, intent(in) :: which
            character(len=:), allocatable :: s
            type(c_ptr) :: p
            integer(c_int) :: len, status
            status = wxf_dialog_last(int(which, c_int), p, len)
            s = wx_take_string(status, p, len)
        end function last
    end subroutine wx_last_dialog

end module wx_dialogs

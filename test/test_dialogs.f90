!> Dialog tests with scripted answers (in dialog test mode, so a dialog
!> without an answer fails instead of waiting for a user): message boxes,
!> file, directory, text, choice and color dialogs, the About box, answer
!> order, and dialogs opened from an event handler. No user interaction needed.
module test_dialogs_handlers

    use wx
    implicit none

contains

    !> Ask a yes/no question from a button handler; store the button.
    subroutine ask(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (integer)
            data = wx_message_box('Proceed?', 'Question', ior(wxYES_NO, wxICON_QUESTION))
        end select
    end subroutine ask

end module test_dialogs_handlers


!> Runs the dialog tests.
program test_dialogs

    use wx
    use testing
    use test_dialogs_handlers
    implicit none

    type(wx_app) :: app
    type(wx_frame) :: frame, dead
    type(wx_button) :: button
    type(wx_color) :: color
    type(wx_string), allocatable :: paths(:)
    character(len=:), allocatable :: path, text, kind, caption, message
    integer :: stat, b, index
    integer, target :: answer
    logical :: ok
    character(len=*), parameter :: unicode = 'h' // char(195) // char(169) // 'llo'   ! "héllo"

    app = wx_app()
    call wx_set_dialog_test_mode(.true.)
    frame = wx_frame('dialogs')

    ! --- test mode: no answer queued, no dialog shown
    b = wx_message_box('Nobody will answer', 'Unanswered', stat=stat)
    call check(stat == WX_ERR_STATE, 'dialog without a queued answer fails in test mode')
    call wx_last_dialog(kind, caption, message)
    call check(kind == 'message' .and. caption == 'Unanswered' .and. message == 'Nobody will answer', &
               'wx_last_dialog records kind, caption and message')

    ! --- message boxes
    call wx_queue_dialog_answer()
    b = wx_message_box('Saved.')
    call check(b == wxID_OK, 'default answer of an OK box is wxID_OK')
    call wx_last_dialog(caption=caption)
    call check(caption == 'Message', 'default caption')
    call wx_queue_dialog_answer()
    b = wx_message_box('Delete?', style=wxYES_NO, parent=frame)
    call check(b == wxID_YES, 'default answer of a Yes/No box is wxID_YES')
    call wx_queue_dialog_answer(button=wxID_NO)
    b = wx_message_box('Delete?', style=ior(wxYES_NO, wxICON_WARNING))
    call check(b == wxID_NO, 'scripted No')
    call wx_queue_dialog_answer(button=wxID_CANCEL)
    b = wx_message_box('Save changes?', style=ior(ior(wxYES_NO, wxCANCEL), wxICON_QUESTION))
    call check(b == wxID_CANCEL, 'scripted Cancel')
    call wx_queue_dialog_answer(button=wxID_CANCEL)
    b = wx_message_box('OK only', stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'an answer the box does not offer is rejected')
    b = wx_message_box('Bad', style=ior(wxOK, wxYES_NO), stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'wxOK and wxYES_NO together are rejected')
    call wx_clear_dialog_answers()

    ! --- file dialogs
    call wx_queue_dialog_answer(path='/tmp/data.txt')
    ok = wx_file_open_dialog(path, wildcard='Text (*.txt)|*.txt', parent=frame)
    call check(ok .and. path == '/tmp/data.txt', 'file open: scripted path')
    call wx_last_dialog(kind)
    call check(kind == 'file open', 'file open dialog kind')
    call wx_queue_dialog_answer(button=wxID_CANCEL)
    ok = wx_file_open_dialog(path)
    call check(.not. ok .and. path == '', 'file open: cancelled')
    call wx_queue_dialog_answer(paths=[character(len=12) :: '/tmp/a.dat', '/tmp/b c.dat'])
    ok = wx_file_open_multiple_dialog(paths)
    call check(ok .and. size(paths) == 2, 'file open multiple: two paths')
    call check(paths(1)%s == '/tmp/a.dat' .and. paths(2)%s == '/tmp/b c.dat', '... trimmed, spaces kept')
    call wx_queue_dialog_answer(paths=[character(len=4) :: 'a', 'b'])
    ok = wx_file_open_dialog(path, stat=stat)
    call check(stat == WX_ERR_ARGUMENT .and. .not. ok, 'several paths for a single-file dialog rejected')
    call wx_queue_dialog_answer(button=wxID_OK)
    ok = wx_file_open_dialog(path, stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'an accepted file dialog needs a path')
    call wx_queue_dialog_answer(path='/tmp/'//unicode//'.png')
    ok = wx_file_save_dialog(path, message='Save the plot', default_file='plot.png')
    call check(ok .and. path == '/tmp/'//unicode//'.png', 'file save: non-ASCII path')
    call wx_last_dialog(kind, caption)
    call check(kind == 'file save' .and. caption == 'Save the plot', 'file save kind and title')
    call wx_queue_dialog_answer(path='/tmp')
    ok = wx_dir_dialog(path, default_path='/')
    call check(ok .and. path == '/tmp', 'directory dialog')

    ! --- text entry
    call wx_queue_dialog_answer(text=unicode)
    ok = wx_text_entry_dialog(text, 'Your name:', default_value='x')
    call check(ok .and. text == unicode, 'text entry: scripted non-ASCII text')
    call wx_queue_dialog_answer(text='')
    ok = wx_text_entry_dialog(text, 'Empty is fine:')
    call check(ok .and. text == '', 'text entry: empty text accepted')
    call wx_queue_dialog_answer(button=wxID_CANCEL)
    ok = wx_text_entry_dialog(text, 'Password:', password=.true.)
    call check(.not. ok, 'text entry: cancelled')
    call wx_queue_dialog_answer()
    ok = wx_text_entry_dialog(text, 'No text queued', stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'an accepted text entry needs text')

    ! --- single choice
    call wx_queue_dialog_answer(index=2)
    ok = wx_choice_dialog(index, 'Pick one', [character(len=6) :: 'red', 'green', 'blue'], initial=3)
    call check(ok .and. index == 2, 'choice dialog: scripted index')
    call wx_queue_dialog_answer(index=4)
    ok = wx_choice_dialog(index, 'Pick one', [character(len=6) :: 'red', 'green', 'blue'], stat=stat)
    call check(stat == WX_ERR_ARGUMENT .and. .not. ok, 'out-of-range choice rejected')
    ok = wx_choice_dialog(index, 'Nothing to choose', [character(len=1) ::], stat=stat)
    call check(stat == WX_ERR_ARGUMENT, 'a choice dialog needs choices')

    ! --- color
    call wx_queue_dialog_answer(color=wx_color(10, 20, 30))
    ok = wx_color_dialog(color, initial=wxRED)
    call check(ok .and. color%r == 10 .and. color%g == 20 .and. color%b == 30, 'color dialog')
    call wx_queue_dialog_answer(button=wxID_CANCEL)
    ok = wx_color_dialog(color, initial=wxRED)
    call check(.not. ok .and. color%r == 255, 'cancelled color dialog keeps the initial color')

    ! --- About box
    call wx_queue_dialog_answer()
    call wx_about_box('wxFortran test', version='0.1', description='Dialogs', copyright='(c) 2026')
    call wx_last_dialog(kind, caption)
    call check(kind == 'about' .and. caption == 'wxFortran test', 'about box')

    ! --- answers are used in order; queue bookkeeping
    call wx_queue_dialog_answer(button=wxID_YES)
    call wx_queue_dialog_answer(button=wxID_NO)
    call check(wx_queued_dialog_answers() == 2, 'two answers queued')
    call check(wx_message_box('1', style=wxYES_NO) == wxID_YES, 'first answer first')
    call check(wx_message_box('2', style=wxYES_NO) == wxID_NO, 'second answer second')
    call check(wx_queued_dialog_answers() == 0, 'answers consumed')
    call wx_queue_dialog_answer()
    call wx_clear_dialog_answers()
    call check(wx_queued_dialog_answers() == 0, 'answers cleared')

    ! --- a dialog from an event handler
    button = wx_button(frame, 'Ask')
    answer = 0
    call button%bind(wxEVT_BUTTON, ask, data=answer)
    call wx_queue_dialog_answer(button=wxID_NO)
    call button%emit_click()
    call check(answer == wxID_NO, 'dialog opened from a handler gets its scripted answer')

    ! --- bad parent
    dead = wx_frame('dead')
    call dead%destroy()
    call wx_queue_dialog_answer()
    b = wx_message_box('x', parent=dead, stat=stat)
    call check(stat == WX_ERR_INVALID_HANDLE, 'destroyed parent rejected')
    call wx_clear_dialog_answers()

    call frame%destroy()
    call app%process_pending()

end program test_dialogs

!> Private `bind(C)` interfaces to the dialogs part of the C++ shim
!> (src/cpp/wxf_dialogs.cpp), and its constants (wxWidgets' own values,
!> checked in the shim).
module wx_c_dialogs

    use iso_c_binding
    implicit none
    private

    ! message box buttons
    integer(c_int), parameter, public :: wxOK = 4              !! an OK button
    integer(c_int), parameter, public :: wxCANCEL = 16         !! a Cancel button
    integer(c_int), parameter, public :: wxYES_NO = 10         !! Yes and No buttons
    ! message box icons
    integer(c_int), parameter, public :: wxICON_INFORMATION = 2048  !! information icon
    integer(c_int), parameter, public :: wxICON_WARNING = 256       !! warning icon
    integer(c_int), parameter, public :: wxICON_ERROR = 512         !! error icon
    integer(c_int), parameter, public :: wxICON_QUESTION = 1024     !! question icon
    ! the button chosen
    integer(c_int), parameter, public :: wxID_OK = 5100        !! OK
    integer(c_int), parameter, public :: wxID_CANCEL = 5101    !! Cancel (or the dialog was closed)
    integer(c_int), parameter, public :: wxID_YES = 5103       !! Yes
    integer(c_int), parameter, public :: wxID_NO = 5104        !! No

    public :: wxf_dialog_queue_answer, wxf_dialog_clear_answers, wxf_dialog_set_test_mode
    public :: wxf_dialog_last, wxf_message_box, wxf_file_dialog, wxf_dir_dialog
    public :: wxf_text_entry_dialog, wxf_choice_dialog, wxf_color_dialog, wxf_about_box
    public :: wxf_dialog_queued_answers

    interface

        !> Queue a scripted dialog answer.
        function wxf_dialog_queue_answer(button, text, len_text, has_text, paths, itemlen_paths, n_paths, index, has_color, red, green, blue, alpha) &
                bind(C, name='wxf_dialog_queue_answer') result(r)
            import :: c_char, c_int
            implicit none
            integer(c_int), value :: button
            character(kind=c_char), intent(in) :: text(*)
            integer(c_int), value :: len_text
            integer(c_int), value :: has_text
            character(kind=c_char), intent(in) :: paths(*)
            integer(c_int), value :: itemlen_paths
            integer(c_int), value :: n_paths
            integer(c_int), value :: index
            integer(c_int), value :: has_color
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            integer(c_int) :: r
        end function wxf_dialog_queue_answer

        !> Drop all queued answers.
        function wxf_dialog_clear_answers() &
                bind(C, name='wxf_dialog_clear_answers') result(r)
            import :: c_int
            implicit none
            integer(c_int) :: r
        end function wxf_dialog_clear_answers

        !> Fail (instead of showing) dialogs without a queued answer.
        function wxf_dialog_set_test_mode(on) &
                bind(C, name='wxf_dialog_set_test_mode') result(r)
            import :: c_int
            implicit none
            integer(c_int), value :: on
            integer(c_int) :: r
        end function wxf_dialog_set_test_mode

        !> The last dialog's kind (1), caption (2) or message (3).
        function wxf_dialog_last(which, s, len) &
                bind(C, name='wxf_dialog_last') result(r)
            import :: c_int, c_ptr
            implicit none
            integer(c_int), value :: which
            type(c_ptr), intent(out) :: s
            integer(c_int), intent(out) :: len
            integer(c_int) :: r
        end function wxf_dialog_last

        !> Show a message box.
        function wxf_message_box(parent, msg, len_msg, cap, len_cap, style, button) &
                bind(C, name='wxf_message_box') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: msg(*)
            integer(c_int), value :: len_msg
            character(kind=c_char), intent(in) :: cap(*)
            integer(c_int), value :: len_cap
            integer(c_int), value :: style
            integer(c_int), intent(out) :: button
            integer(c_int) :: r
        end function wxf_message_box

        !> Show a file open/save dialog.
        function wxf_file_dialog(parent, mode, msg, len_msg, dir, len_dir, file, len_file, wild, len_wild, flags, ok, paths, plen) &
                bind(C, name='wxf_file_dialog') result(r)
            import :: c_char, c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int), value :: mode
            character(kind=c_char), intent(in) :: msg(*)
            integer(c_int), value :: len_msg
            character(kind=c_char), intent(in) :: dir(*)
            integer(c_int), value :: len_dir
            character(kind=c_char), intent(in) :: file(*)
            integer(c_int), value :: len_file
            character(kind=c_char), intent(in) :: wild(*)
            integer(c_int), value :: len_wild
            integer(c_int), value :: flags
            integer(c_int), intent(out) :: ok
            type(c_ptr), intent(out) :: paths
            integer(c_int), intent(out) :: plen
            integer(c_int) :: r
        end function wxf_file_dialog

        !> Show a directory dialog.
        function wxf_dir_dialog(parent, msg, len_msg, dir, len_dir, flags, ok, path, plen) &
                bind(C, name='wxf_dir_dialog') result(r)
            import :: c_char, c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: msg(*)
            integer(c_int), value :: len_msg
            character(kind=c_char), intent(in) :: dir(*)
            integer(c_int), value :: len_dir
            integer(c_int), value :: flags
            integer(c_int), intent(out) :: ok
            type(c_ptr), intent(out) :: path
            integer(c_int), intent(out) :: plen
            integer(c_int) :: r
        end function wxf_dir_dialog

        !> Show a text entry dialog.
        function wxf_text_entry_dialog(parent, msg, len_msg, cap, len_cap, value, len_value, password, ok, out, olen) &
                bind(C, name='wxf_text_entry_dialog') result(r)
            import :: c_char, c_int, c_int64_t, c_ptr
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: msg(*)
            integer(c_int), value :: len_msg
            character(kind=c_char), intent(in) :: cap(*)
            integer(c_int), value :: len_cap
            character(kind=c_char), intent(in) :: value(*)
            integer(c_int), value :: len_value
            integer(c_int), value :: password
            integer(c_int), intent(out) :: ok
            type(c_ptr), intent(out) :: out
            integer(c_int), intent(out) :: olen
            integer(c_int) :: r
        end function wxf_text_entry_dialog

        !> Show a single choice dialog.
        function wxf_choice_dialog(parent, msg, len_msg, cap, len_cap, items, itemlen_items, n_items, initial, ok, index) &
                bind(C, name='wxf_choice_dialog') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: msg(*)
            integer(c_int), value :: len_msg
            character(kind=c_char), intent(in) :: cap(*)
            integer(c_int), value :: len_cap
            character(kind=c_char), intent(in) :: items(*)
            integer(c_int), value :: itemlen_items
            integer(c_int), value :: n_items
            integer(c_int), value :: initial
            integer(c_int), intent(out) :: ok
            integer(c_int), intent(out) :: index
            integer(c_int) :: r
        end function wxf_choice_dialog

        !> Show a color picker.
        function wxf_color_dialog(parent, red, green, blue, alpha, ok, ro, go, bo, ao) &
                bind(C, name='wxf_color_dialog') result(r)
            import :: c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            integer(c_int), value :: red
            integer(c_int), value :: green
            integer(c_int), value :: blue
            integer(c_int), value :: alpha
            integer(c_int), intent(out) :: ok
            integer(c_int), intent(out) :: ro
            integer(c_int), intent(out) :: go
            integer(c_int), intent(out) :: bo
            integer(c_int), intent(out) :: ao
            integer(c_int) :: r
        end function wxf_color_dialog

        !> Show the About box.
        function wxf_about_box(parent, name, len_name, version, len_version, desc, len_desc, copyright, len_copyright, web, len_web) &
                bind(C, name='wxf_about_box') result(r)
            import :: c_char, c_int, c_int64_t
            implicit none
            integer(c_int64_t), value :: parent
            character(kind=c_char), intent(in) :: name(*)
            integer(c_int), value :: len_name
            character(kind=c_char), intent(in) :: version(*)
            integer(c_int), value :: len_version
            character(kind=c_char), intent(in) :: desc(*)
            integer(c_int), value :: len_desc
            character(kind=c_char), intent(in) :: copyright(*)
            integer(c_int), value :: len_copyright
            character(kind=c_char), intent(in) :: web(*)
            integer(c_int), value :: len_web
            integer(c_int) :: r
        end function wxf_about_box

        !> Number of queued answers.
        function wxf_dialog_queued_answers() bind(C, name='wxf_dialog_queued_answers') result(n)
            import :: c_int
            implicit none
            integer(c_int) :: n
        end function wxf_dialog_queued_answers

    end interface

end module wx_c_dialogs

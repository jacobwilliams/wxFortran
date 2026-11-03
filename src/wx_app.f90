!> The application: wxWidgets initialization, the main event loop, shutdown.
!>
!> ```fortran
!> type(wx_app) :: app
!> app = wx_app()          ! initialize wxWidgets (once, before any window)
!> ...create and show windows, bind handlers...
!> stop app%run()          ! run until the last top-level window is closed
!> ```
!>
!> There is one application per program. It must be created, and all GUI
!> calls made, on the main thread.
module wx_app_mod

    use iso_c_binding
    use wx_c_core
    use wx_base
    use wx_events, only: wx_events_install
    implicit none
    private

    !> The wxWidgets application (one per program).
    type, public :: wx_app
        logical, private :: initialized = .false.
    contains
        procedure :: run => wx_app_run
        procedure :: exit_main_loop => wx_app_exit_main_loop
        procedure :: is_main_loop_running => wx_app_is_main_loop_running
        procedure :: process_pending => wx_app_process_pending
        procedure :: set_exit_on_frame_delete => wx_app_set_exit_on_frame_delete
        procedure :: cleanup => wx_app_cleanup
    end type wx_app

    !> Initialize wxWidgets and return the application.
    interface wx_app
        module procedure wx_app_new
    end interface wx_app

contains

    !> Initialize wxWidgets. Fails (`WX_ERR_FAILED`) if no GUI is available,
    !> e.g. no display on Linux, and with `WX_ERR_STATE` if already initialized.
    function wx_app_new(stat) result(app)
        integer, intent(out), optional :: stat
        type(wx_app) :: app
        character(len=256) :: name
        integer :: n
        integer(c_int) :: status
        call get_command_argument(0, name, n)
        n = min(max(n, 0), len(name))
        call wx_events_install()
        status = wxf_app_init(name, int(len_trim(name(1:n)), c_int))
        app%initialized = status == WX_OK
        call wx_check(status, stat)
    end function wx_app_new

    !> Run the main event loop until it exits: when the last top-level window
    !> is deleted (unless disabled with `set_exit_on_frame_delete`), or when
    !> `exit_main_loop` is called. Returns the exit code (0 normally).
    integer function wx_app_run(self, stat)
        class(wx_app), intent(inout) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: code
        code = 0
        call wx_check(wxf_app_run(code), stat)
        wx_app_run = code
    end function wx_app_run

    !> Make the main loop return (after the current event).
    subroutine wx_app_exit_main_loop(self, stat)
        class(wx_app), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_app_exit_main_loop(), stat)
    end subroutine wx_app_exit_main_loop

    !> True while `run` is executing.
    logical function wx_app_is_main_loop_running(self)
        class(wx_app), intent(in) :: self
        wx_app_is_main_loop_running = wx_logical(wxf_app_is_main_loop_running())
    end function wx_app_is_main_loop_running

    !> Process pending events and delete windows scheduled for destruction
    !> (top-level windows are deleted this way, after `destroy` or `close`).
    subroutine wx_app_process_pending(self, stat)
        class(wx_app), intent(inout) :: self
        integer, intent(out), optional :: stat
        call wx_check(wxf_app_process_pending(), stat)
    end subroutine wx_app_process_pending

    !> Whether `run` returns when the last top-level window is deleted
    !> (default: true).
    subroutine wx_app_set_exit_on_frame_delete(self, flag, stat)
        class(wx_app), intent(inout) :: self
        logical, intent(in) :: flag
        integer, intent(out), optional :: stat
        call wx_check(wxf_app_set_exit_on_frame_delete(wx_int(flag)), stat)
    end subroutine wx_app_set_exit_on_frame_delete

    !> Shut wxWidgets down, destroying any remaining windows; every handle
    !> becomes invalid. Optional before the program ends. wxWidgets cannot
    !> be initialized again afterwards in the same program.
    subroutine wx_app_cleanup(self, stat)
        class(wx_app), intent(inout) :: self
        integer, intent(out), optional :: stat
        integer(c_int) :: status
        status = wxf_app_cleanup()
        if (status == WX_OK) self%initialized = .false.
        call wx_check(status, stat)
    end subroutine wx_app_cleanup

end module wx_app_mod

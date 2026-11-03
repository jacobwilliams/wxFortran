!> Base of the wxFortran API: error handling, string conversion, and
!> [[wx_object]], the handle type that every wxWidgets object wrapper extends.
!>
!> ### Error handling
!>
!> Procedures that can fail take an optional `stat` argument. If it is
!> present, it is set to `WX_OK` (0) or a `WX_ERR_*` code, and
!> [[wx_last_error]] gives the message. If it is absent, a failure prints the
!> message and stops the program (`error stop`).
!>
!> ### Handles and lifetime
!>
!> A wrapper holds only a handle: copying it is cheap and makes another
!> reference to the same object. wxWidgets owns the objects: a child window is
!> destroyed with its parent, and the user may close a frame at any time. A
!> handle whose object is gone is invalid (see `is_valid`); using it is an
!> error (`WX_ERR_INVALID_HANDLE`), never a crash. Wrappers have no finalizers:
!> a Fortran variable going out of scope does not destroy the object.
module wx_base

    use iso_c_binding
    use iso_fortran_env, only: error_unit
    use wx_c_core
    implicit none
    private

    public :: WX_OK, WX_ERR_INVALID_HANDLE, WX_ERR_NO_APP, WX_ERR_STATE
    public :: WX_ERR_ARGUMENT, WX_ERR_FAILED, WX_ERR_EXCEPTION
    public :: wx_last_error, wx_live_objects
    public :: wx_check, wx_take_string, wx_borrow_string, wx_int, wx_logical

    !> A reference to a wxWidgets object (or none: a default-initialized
    !> wrapper has handle 0 and is invalid).
    type, public :: wx_object
        integer(c_int64_t) :: h = 0_c_int64_t   !! opaque shim handle (0: no object)
    contains
        procedure :: is_valid => wx_object_is_valid
        procedure :: handle => wx_object_handle
        procedure, private :: wx_object_same
        generic :: operator(==) => wx_object_same
    end type wx_object

contains

    !> True if the object exists (was created and has not been destroyed).
    logical function wx_object_is_valid(self)
        class(wx_object), intent(in) :: self
        wx_object_is_valid = wxf_is_valid(self%h) /= 0
    end function wx_object_is_valid

    !> The opaque handle (useful for logging and comparisons).
    integer(c_int64_t) function wx_object_handle(self)
        class(wx_object), intent(in) :: self
        wx_object_handle = self%h
    end function wx_object_handle

    !> True if both wrappers refer to the same object.
    logical function wx_object_same(a, b)
        class(wx_object), intent(in) :: a, b
        wx_object_same = a%h == b%h .and. a%h /= 0
    end function wx_object_same

    !> The message of the last failed wxFortran call.
    function wx_last_error() result(msg)
        character(len=:), allocatable :: msg
        type(c_ptr) :: p
        integer(c_int) :: len
        p = wxf_last_error(len)
        msg = wx_borrow_string(p, len)
    end function wx_last_error

    !> Number of live objects created through wxFortran (for leak tests).
    integer function wx_live_objects()
        wx_live_objects = wxf_live_count()
    end function wx_live_objects

    !> Report a shim status: store it in `stat` if present, else stop on failure.
    subroutine wx_check(status, stat)
        integer(c_int), intent(in) :: status
        integer, intent(out), optional :: stat
        if (present(stat)) then
            stat = status
        else if (status /= WX_OK) then
            write(error_unit, '(A)') 'wxFortran error: '//wx_last_error()
            error stop 1
        end if
    end subroutine wx_check

    !> Copy `len` bytes of UTF-8 at `p` into a Fortran string (not freed).
    function wx_borrow_string(p, len) result(s)
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: len
        character(len=:), allocatable :: s
        character(kind=c_char), dimension(:), pointer :: buf
        integer :: i
        allocate(character(len=max(len, 0)) :: s)
        if (len <= 0 .or. .not. c_associated(p)) return
        call c_f_pointer(p, buf, [len])
        do i = 1, len
            s(i:i) = buf(i)
        end do
    end function wx_borrow_string

    !> Copy a string returned by the shim (if `status` is `WX_OK`) and free it.
    function wx_take_string(status, p, len, stat) result(s)
        integer(c_int), intent(in) :: status
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: len
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: s
        call wx_check(status, stat)
        if (status == WX_OK) then
            s = wx_borrow_string(p, len)
            call wxf_free(p)
        else
            s = ''
        end if
    end function wx_take_string

    !> Fortran logical to shim boolean (0/1).
    pure elemental integer(c_int) function wx_int(l)
        logical, intent(in) :: l
        wx_int = merge(1_c_int, 0_c_int, l)
    end function wx_int

    !> Shim boolean (0/1) to Fortran logical.
    pure elemental logical function wx_logical(b)
        integer(c_int), intent(in) :: b
        wx_logical = b /= 0
    end function wx_logical

end module wx_base

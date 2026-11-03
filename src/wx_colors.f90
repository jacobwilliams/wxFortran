!> Colors for drawing: [[wx_color]] (8-bit red, green, blue and alpha), named colors,
!> and parsing of `"#rrggbb"` strings.
module wx_colors

    use wx_base, only: wx_check, wx_fail, WX_OK, WX_ERR_ARGUMENT
    implicit none
    private

    public :: wx_color_hex

    !> A color: components 0-255; `a` is the opacity (255: opaque).
    type, public :: wx_color
        integer :: r = 0     !! red
        integer :: g = 0     !! green
        integer :: b = 0     !! blue
        integer :: a = 255   !! alpha (opacity)
    end type wx_color

    type(wx_color), parameter, public :: wxBLACK = wx_color(0, 0, 0, 255)          !! black
    type(wx_color), parameter, public :: wxWHITE = wx_color(255, 255, 255, 255)    !! white
    type(wx_color), parameter, public :: wxRED = wx_color(255, 0, 0, 255)          !! red
    type(wx_color), parameter, public :: wxGREEN = wx_color(0, 255, 0, 255)        !! green
    type(wx_color), parameter, public :: wxBLUE = wx_color(0, 0, 255, 255)         !! blue
    type(wx_color), parameter, public :: wxLIGHT_GRAY = wx_color(211, 211, 211, 255) !! light gray
    type(wx_color), parameter, public :: wxTRANSPARENT = wx_color(0, 0, 0, 0)     !! fully transparent

contains

    !> A color from `"#rrggbb"` or `"#rrggbbaa"` (the `#` is optional);
    !> fails with `WX_ERR_ARGUMENT` (black) for anything else.
    type(wx_color) function wx_color_hex(hex, stat) result(c)
        character(len=*), intent(in) :: hex
        integer, intent(out), optional :: stat
        character(len=:), allocatable :: h
        integer :: v(4), i, n
        logical :: ok
        h = trim(adjustl(hex))
        if (len(h) > 0) then
            if (h(1:1) == '#') h = h(2:)
        end if
        n = len(h) / 2
        ok = (len(h) == 6 .or. len(h) == 8)
        v = [0, 0, 0, 255]
        if (ok) then
            do i = 1, n
                v(i) = hex_byte(h(2*i-1:2*i), ok)
                if (.not. ok) exit
            end do
        end if
        if (ok) then
            c = wx_color(v(1), v(2), v(3), v(4))
            if (present(stat)) stat = WX_OK
        else
            c = wx_color()
            call wx_check(wx_fail(WX_ERR_ARGUMENT, 'not a "#rrggbb" or "#rrggbbaa" color: "'//hex//'"'), stat)
        end if
    end function wx_color_hex

    !> Two hex digits as 0-255; `ok` false if they are not hex digits.
    integer function hex_byte(s, ok)
        character(len=2), intent(in) :: s
        logical, intent(inout) :: ok
        integer :: i, d
        hex_byte = 0
        do i = 1, 2
            d = index('0123456789abcdef', lower(s(i:i))) - 1
            if (d < 0) then
                ok = .false.
                return
            end if
            hex_byte = 16*hex_byte + d
        end do
    end function hex_byte

    !> ASCII lower case of one character.
    pure character function lower(ch)
        character, intent(in) :: ch
        lower = ch
        if (ch >= 'A' .and. ch <= 'Z') lower = achar(iachar(ch) + 32)
    end function lower

end module wx_colors

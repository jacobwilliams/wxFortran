!> Modern Fortran interface to wxWidgets: `use wx` for the whole public API.
!>
!> See [[wx_base]] (errors, handles and lifetime), [[wx_events]] (handlers),
!> [[wx_app_mod]] (application and event loop), [[wx_timers]],
!> [[wx_windows]] (windows and sizers), [[wx_menus]], [[wx_controls]]
!> (frames and controls), [[wx_canvas_mod]], [[wx_graphics_mod]] (drawing)
!> and [[wx_colors]].
module wx

    use wx_base, only: wx_object, wx_last_error, wx_live_objects, &
                       WX_OK, WX_ERR_INVALID_HANDLE, WX_ERR_NO_APP, WX_ERR_STATE, &
                       WX_ERR_ARGUMENT, WX_ERR_FAILED, WX_ERR_EXCEPTION
    use wx_events
    use wx_app_mod
    use wx_timers
    use wx_colors
    use wx_graphics_mod
    use wx_windows
    use wx_menus
    use wx_controls
    use wx_canvas_mod
    implicit none
    public

end module wx

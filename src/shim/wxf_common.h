// Shared definitions for the wxf C ABI shim (C++ side of wxFortran).
//
// Conventions (see README "Language boundary"):
//  * Every exported function is `extern "C"`, returns an int status (WXF_OK on
//    success) unless documented otherwise, and never lets a C++ exception
//    escape: WXF_TRY / WXF_CATCH turn exceptions into WXF_ERR_EXCEPTION.
//  * The message for the last failure on this thread is kept and returned by
//    wxf_last_error().
//  * wxWidgets objects are referred to by 64-bit handles (never reused), not by
//    pointers. A handle whose object has been destroyed is simply invalid.
//  * Strings cross the boundary as (pointer, byte length) pairs of UTF-8 with
//    no terminating NUL. Strings returned to Fortran are malloc'd and released
//    with wxf_free.
#pragma once

#include <wx/wx.h>

#include <cstdint>
#include <string>

#if defined(_WIN32)
#define WXF_API extern "C" __declspec(dllexport)
#else
#define WXF_API extern "C" __attribute__((visibility("default")))
#endif

// Status codes: must match the WX_ERR_* parameters in src/core/wx_c_core.f90.
enum wxf_status : int {
    WXF_OK = 0,
    WXF_ERR_INVALID_HANDLE = 1,   // null, unknown or destroyed object
    WXF_ERR_NO_APP = 2,           // the application has not been initialized
    WXF_ERR_STATE = 3,            // call not allowed in the current state
    WXF_ERR_ARGUMENT = 4,         // invalid argument value
    WXF_ERR_FAILED = 5,           // wxWidgets reported failure
    WXF_ERR_EXCEPTION = 6,        // a C++ exception was caught at the boundary
};

// Event kinds: must match the wxEVT_* parameters in src/core/wx_c_core.f90.
enum wxf_event_kind : int {
    WXF_EVT_BUTTON = 1,
    WXF_EVT_TEXT = 2,
    WXF_EVT_TEXT_ENTER = 3,
    WXF_EVT_CLOSE_WINDOW = 4,
    WXF_EVT_SIZE = 5,
    WXF_EVT_DESTROY = 6,
    WXF_EVT_CHECKBOX = 7,
    WXF_EVT_TIMER = 8,
    WXF_EVT_MENU = 9,
    WXF_EVT_PAINT = 10,         // a wx_canvas needs drawing (wxfEVT_DRAW)
    WXF_EVT_LEFT_DOWN = 11,
    WXF_EVT_LEFT_UP = 12,
    WXF_EVT_RIGHT_DOWN = 13,
    WXF_EVT_MOTION = 14,
    WXF_EVT_MOUSEWHEEL = 15,
    WXF_EVT_KEY_DOWN = 16,
    WXF_EVT_LEFT_DCLICK = 17,
    WXF_EVT_LEAVE_WINDOW = 18,
};

// Modifier key bits: must match WX_MOD_* in src/c/wx_c_core.f90.
enum { WXF_MOD_SHIFT = 1, WXF_MOD_CONTROL = 2, WXF_MOD_ALT = 4 };

// Fortran callbacks: dispatch(slot, event or null, event kind), release(slot).
typedef void (*wxf_dispatch_fn)(int slot, void *event, int kind);
typedef void (*wxf_release_fn)(int slot);

// Record an error message (for wxf_last_error) and return `status`.
int wxf_fail(int status, const std::string &msg);
int wxf_fail_handle(int64_t h);

// Exception barrier for exported functions.
#define WXF_TRY try {
#define WXF_CATCH                                                              \
    }                                                                          \
    catch (const std::exception &e) {                                          \
        return wxf_fail(WXF_ERR_EXCEPTION, std::string("C++ exception: ") + e.what()); \
    }                                                                          \
    catch (...) {                                                              \
        return wxf_fail(WXF_ERR_EXCEPTION, "unknown C++ exception");           \
    }

// ---------------------------------------------------------------------------
// handles

// Register a window and return its new handle (0 if w is null).
int64_t wxf_register(wxWindow *w);

// The live window for handle `h`, or null if the handle is 0, unknown, or the
// window has been destroyed or scheduled for destruction.
wxWindow *wxf_window(int64_t h);

// The handle of a registered window (0 if it was not created through wxf).
int64_t wxf_handle_of(wxWindow *w);

// A live window of type T, or null (also null if the window is another type).
template <class T> T *wxf_get(int64_t h) { return dynamic_cast<T *>(wxf_window(h)); }

// Other event handlers (timers, menus): register, and look up (windows too).
int64_t wxf_register_handler(wxEvtHandler *p);
wxEvtHandler *wxf_handler(int64_t h);
int64_t wxf_handle_of_handler(const wxEvtHandler *p);
template <class T> T *wxf_get_handler(int64_t h) { return dynamic_cast<T *>(wxf_handler(h)); }

// Mark handle `h` dead now (its object is deleted later).
void wxf_mark_dead(int64_t h);

// True while a Fortran event handler is running.
bool wxf_dispatching();

#define WXF_GET_HANDLER(T, var, h)                                             \
    if (!wxf_app_ready()) return wxf_fail(WXF_ERR_NO_APP, "wx_app has not been initialized"); \
    T *var = wxf_get_handler<T>(h);                                            \
    if (!var) return wxf_fail_handle(h)

// Sizers: register, look up (null if dead), and track ownership.
int64_t wxf_register_sizer(wxSizer *s);
wxSizer *wxf_sizer(int64_t h);
int64_t wxf_sizer_owner(int64_t h);
void wxf_sizer_set_owner(int64_t h, int64_t owner);
void wxf_sizer_kill(wxSizer *s);   // mark a sizer deleted by wxWidgets

// True if a wxApp exists and wxEntryStart succeeded.
bool wxf_app_ready();

// Look up handle `h` as a T* into `var`, or return the matching error status.
#define WXF_GET(T, var, h)                                                     \
    if (!wxf_app_ready()) return wxf_fail(WXF_ERR_NO_APP, "wx_app has not been initialized"); \
    T *var = wxf_get<T>(h);                                                    \
    if (!var) return wxf_fail_handle(h)

#define WXF_NEED_APP()                                                         \
    if (!wxf_app_ready()) return wxf_fail(WXF_ERR_NO_APP, "wx_app has not been initialized")

// ---------------------------------------------------------------------------
// strings

inline wxString wxf_str(const char *s, int len) {
    return len > 0 ? wxString::FromUTF8(s, static_cast<size_t>(len)) : wxString();
}

// Return a wxString to Fortran as a malloc'd UTF-8 buffer (released by wxf_free).
void wxf_out_str(const wxString &s, char **out, int *len);

inline int wxf_bool(bool b) { return b ? 1 : 0; }

// C ABI shim over wxTimer.
//
// A timer is its own event handler: bind WXF_EVT_TIMER on its handle. A timer
// with an owner window is deleted with that window; one without an owner must
// be destroyed explicitly (or is deleted by wxf_app_cleanup).

#include "wxf_common.h"

#include <wx/timer.h>
#include <wx/weakref.h>

WXF_API int wxf_timer_create(int64_t owner, int64_t *out) {
    WXF_TRY
    WXF_NEED_APP();
    *out = 0;
    wxWindow *w = nullptr;
    if (owner != 0) {
        w = wxf_window(owner);
        if (!w) return wxf_fail_handle(owner);
    }
    auto *t = new wxTimer();   // its own owner: events go to the timer itself
    *out = wxf_register_handler(t);
    if (w) {
        wxWeakRef<wxTimer> ref(t);
        w->Bind(wxEVT_DESTROY, [ref, w](wxWindowDestroyEvent &ev) {
            if (ev.GetEventObject() == w && ref) delete ref.get();
            ev.Skip();
        });
    }
    return WXF_OK;
    WXF_CATCH
}

// Start (or restart) the timer: every `ms` milliseconds, or once if `one_shot`.
WXF_API int wxf_timer_start(int64_t h, int ms, int one_shot) {
    WXF_TRY
    WXF_GET_HANDLER(wxTimer, t, h);
    if (ms <= 0) return wxf_fail(WXF_ERR_ARGUMENT, "timer interval must be positive (milliseconds)");
    if (!t->Start(ms, one_shot ? wxTIMER_ONE_SHOT : wxTIMER_CONTINUOUS))
        return wxf_fail(WXF_ERR_FAILED, "wxTimer::Start failed");
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_timer_stop(int64_t h) {
    WXF_TRY
    WXF_GET_HANDLER(wxTimer, t, h);
    t->Stop();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_timer_is_running(int64_t h, int *running) {
    WXF_TRY
    WXF_GET_HANDLER(wxTimer, t, h);
    *running = wxf_bool(t->IsRunning());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_timer_get_interval(int64_t h, int *ms) {
    WXF_TRY
    WXF_GET_HANDLER(wxTimer, t, h);
    *ms = t->GetInterval();
    return WXF_OK;
    WXF_CATCH
}

// Stop and delete the timer. From an event handler (possibly this timer's
// own), deletion is deferred to the event loop; the handle is invalid at once.
WXF_API int wxf_timer_destroy(int64_t h) {
    WXF_TRY
    WXF_GET_HANDLER(wxTimer, t, h);
    t->Stop();
    if (wxf_dispatching()) {
        wxf_mark_dead(h);
        wxWeakRef<wxTimer> ref(t);
        wxTheApp->CallAfter([ref]() {
            if (ref) delete ref.get();
        });
    } else {
        delete t;
    }
    return WXF_OK;
    WXF_CATCH
}

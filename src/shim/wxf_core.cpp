// C ABI shim over wxWidgets core: errors, strings, handles, application and
// event loop, event dispatch to Fortran, and the operations shared by all
// windows and sizers.

#include "wxf_common.h"

#include <wx/init.h>
#include <wx/tracker.h>

#include <cstdlib>
#include <cstring>
#include <memory>
#include <unordered_map>
#include <vector>

// ---------------------------------------------------------------------------
// errors

static thread_local std::string wxf_error_message;

int wxf_fail(int status, const std::string &msg) {
    wxf_error_message = msg;
    return status;
}

int wxf_fail_handle(int64_t h) {
    if (h == 0) return wxf_fail(WXF_ERR_INVALID_HANDLE, "null handle (object was never created)");
    return wxf_fail(WXF_ERR_INVALID_HANDLE,
                    "invalid handle " + std::to_string(h) +
                        " (object destroyed, or of the wrong type for this call)");
}

// The message for the last failed call on this thread (borrowed: copy it).
WXF_API const char *wxf_last_error(int *len) {
    *len = static_cast<int>(wxf_error_message.size());
    return wxf_error_message.c_str();
}

WXF_API void wxf_clear_error() { wxf_error_message.clear(); }

// ---------------------------------------------------------------------------
// strings

void wxf_out_str(const wxString &s, char **out, int *len) {
    const wxScopedCharBuffer b = s.utf8_str();
    const size_t n = b.length();
    *len = static_cast<int>(n);
    *out = static_cast<char *>(std::malloc(n + 1));
    std::memcpy(*out, b.data(), n);
    (*out)[n] = '\0';
}

WXF_API void wxf_free(void *p) { std::free(p); }

// ---------------------------------------------------------------------------
// handles
//
// Every object created through the shim gets a handle (a positive 64-bit
// integer, never reused). Windows are tracked with a wxTrackerNode, so their
// entry is removed when wxWidgets deletes them, whoever deletes them (Fortran,
// a parent window, or the user closing the frame). wxEVT_DESTROY marks the
// entry dead slightly earlier, when destruction starts.
//
// Sizers are not trackable: a sizer entry has an owner (the window it is set
// on, or the sizer it was added to) and is alive only while its owner chain is.

namespace {

struct entry {
    wxWindow *win = nullptr;
    wxSizer *sizer = nullptr;
    int64_t owner = 0;     // sizers: owning window/sizer handle (0: unattached)
    bool dead = false;
};

std::unordered_map<int64_t, entry> &table() {
    static auto *t = new std::unordered_map<int64_t, entry>;   // never destroyed
    return *t;
}

std::unordered_map<const void *, int64_t> &reverse() {
    static auto *t = new std::unordered_map<const void *, int64_t>;
    return *t;
}

int64_t next_handle = 0;

// Removes a window's entry when wxWidgets deletes the window.
struct window_tracker : wxTrackerNode {
    int64_t h;
    explicit window_tracker(int64_t h) : h(h) {}
    void OnObjectDestroy() override {
        auto it = table().find(h);
        if (it != table().end()) {
            reverse().erase(it->second.win);
            table().erase(it);
        }
        delete this;
    }
};

bool alive(int64_t h, int depth = 0) {
    auto it = table().find(h);
    if (it == table().end() || it->second.dead) return false;
    const entry &e = it->second;
    if (e.win) {
        // dead if it, or an ancestor, is being deleted or is scheduled for
        // deletion (top-level windows are deleted later, when idle)
        for (wxWindow *w = e.win; w; w = w->GetParent()) {
            if (w->IsBeingDeleted()) return false;
            if (wxTheApp && wxTheApp->IsScheduledForDestruction(w)) return false;
        }
        return true;
    }
    if (e.owner == 0) return true;
    return depth < 1000 && alive(e.owner, depth + 1);
}

}   // namespace

int64_t wxf_register(wxWindow *w) {
    if (!w) return 0;
    const int64_t h = ++next_handle;
    entry e;
    e.win = w;
    table()[h] = e;
    reverse()[w] = h;
    w->AddNode(new window_tracker(h));
    w->Bind(wxEVT_DESTROY, [h, w](wxWindowDestroyEvent &ev) {
        if (ev.GetEventObject() == w) {
            auto it = table().find(h);
            if (it != table().end()) it->second.dead = true;
        }
        ev.Skip();
    });
    return h;
}

wxWindow *wxf_window(int64_t h) {
    if (h <= 0 || !alive(h)) return nullptr;
    return table()[h].win;
}

int64_t wxf_handle_of(wxWindow *w) {
    if (!w) return 0;
    auto it = reverse().find(w);
    return it == reverse().end() ? 0 : it->second;
}

int64_t wxf_register_sizer(wxSizer *s) {
    const int64_t h = ++next_handle;
    entry e;
    e.sizer = s;
    table()[h] = e;
    reverse()[s] = h;
    return h;
}

wxSizer *wxf_sizer(int64_t h) {
    if (h <= 0) return nullptr;
    if (!alive(h)) {
        // forget dead sizers lazily (their memory was released by wxWidgets)
        auto it = table().find(h);
        if (it != table().end() && it->second.sizer) {
            reverse().erase(it->second.sizer);
            table().erase(it);
        }
        return nullptr;
    }
    return table()[h].sizer;
}

int64_t wxf_sizer_owner(int64_t h) {
    auto it = table().find(h);
    return it == table().end() ? 0 : it->second.owner;
}

void wxf_sizer_set_owner(int64_t h, int64_t owner) {
    auto it = table().find(h);
    if (it != table().end()) it->second.owner = owner;
}

void wxf_sizer_kill(wxSizer *s) {
    auto it = reverse().find(s);
    if (it == reverse().end()) return;
    auto e = table().find(it->second);
    if (e != table().end()) e->second.dead = true;
}

// 1 if `h` refers to a live window or sizer, else 0. Never fails.
WXF_API int wxf_is_valid(int64_t h) {
    try {
        return wxf_bool(h > 0 && alive(h));
    } catch (...) {
        return 0;
    }
}

// Number of live registered objects (for tests).
WXF_API int wxf_live_count() {
    int n = 0;
    for (const auto &kv : table())
        if (alive(kv.first)) ++n;
    return n;
}

// ---------------------------------------------------------------------------
// application

namespace {

class wxfApp : public wxApp {
public:
    bool OnInit() override { return true; }   // no command-line parsing
    void Flush() {
        ProcessPendingEvents();
        DeletePendingObjects();
    }
};

bool app_ready = false;
bool loop_running = false;
int app_argc = 1;
char app_name[256] = "wxfortran";
char *app_argv[2] = {app_name, nullptr};

}   // namespace

bool wxf_app_ready() { return app_ready && wxTheApp; }

// Initialize wxWidgets and the application object. `name` (UTF-8) is the
// program name (argv[0]); it may be empty.
WXF_API int wxf_app_init(const char *name, int len) {
    WXF_TRY
    if (app_ready) return wxf_fail(WXF_ERR_STATE, "wx_app is already initialized");
    if (len > 0) {
        const int n = len < 255 ? len : 255;
        std::memcpy(app_name, name, n);
        app_name[n] = '\0';
    }
    app_argc = 1;
    wxApp::SetInstance(new wxfApp);
    if (!wxEntryStart(app_argc, app_argv)) {
        return wxf_fail(WXF_ERR_FAILED, "wxEntryStart failed (is a display available?)");
    }
    if (!wxTheApp || !wxTheApp->CallOnInit()) {
        wxEntryCleanup();
        return wxf_fail(WXF_ERR_FAILED, "wxApp::OnInit failed");
    }
    app_ready = true;
    return WXF_OK;
    WXF_CATCH
}

// Run the main event loop until it exits (the last top-level window is
// closed, or wxf_app_exit_main_loop is called); `code` gets its exit code.
WXF_API int wxf_app_run(int *code) {
    WXF_TRY
    WXF_NEED_APP();
    if (loop_running) return wxf_fail(WXF_ERR_STATE, "the main loop is already running");
    loop_running = true;
    *code = wxTheApp->OnRun();
    loop_running = false;
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_app_exit_main_loop() {
    WXF_TRY
    WXF_NEED_APP();
    wxTheApp->ExitMainLoop();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_app_is_main_loop_running() {
    return wxf_bool(wxf_app_ready() && loop_running);
}

// Process pending events and delete windows scheduled for destruction.
WXF_API int wxf_app_process_pending() {
    WXF_TRY
    WXF_NEED_APP();
    static_cast<wxfApp *>(wxTheApp)->Flush();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_app_set_exit_on_frame_delete(int flag) {
    WXF_TRY
    WXF_NEED_APP();
    wxTheApp->SetExitOnFrameDelete(flag != 0);
    return WXF_OK;
    WXF_CATCH
}

// Shut wxWidgets down: destroys any remaining windows. All handles become invalid.
WXF_API int wxf_app_cleanup() {
    WXF_TRY
    WXF_NEED_APP();
    if (loop_running) return wxf_fail(WXF_ERR_STATE, "cannot clean up while the main loop runs");
    wxTheApp->OnExit();
    wxEntryCleanup();
    app_ready = false;
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// event dispatch to Fortran
//
// A Fortran handler is a "slot" (an integer id into the Fortran slot table).
// Each binding owns its slot through a wxf_slot_data, the wxObject user data
// of the wxWidgets event table entry. wxWidgets deletes it when the handler is
// unbound or the window is destroyed; the slot is then released to Fortran.

static wxf_dispatch_fn wxf_dispatcher = nullptr;
static wxf_release_fn wxf_releaser = nullptr;

WXF_API void wxf_set_dispatcher(wxf_dispatch_fn dispatch, wxf_release_fn release) {
    wxf_dispatcher = dispatch;
    wxf_releaser = release;
}

namespace {

struct binding {
    wxEvtHandler *handler;
    int kind;
    wxObject *data;
};

std::unordered_map<int, binding> &bindings() {
    static auto *m = new std::unordered_map<int, binding>;
    return *m;
}

struct wxf_slot_data : wxObject {
    int slot;
    int kind;
    explicit wxf_slot_data(int slot, int kind) : slot(slot), kind(kind) {}
    ~wxf_slot_data() override {
        bindings().erase(slot);
        if (wxf_releaser) wxf_releaser(slot);
    }
};

// Call f(tag) with the wxEventTypeTag for `kind`; false if the kind is unknown.
template <class F> bool with_event_tag(int kind, F f) {
    switch (kind) {
    case WXF_EVT_BUTTON: f(wxEVT_BUTTON); return true;
    case WXF_EVT_TEXT: f(wxEVT_TEXT); return true;
    case WXF_EVT_TEXT_ENTER: f(wxEVT_TEXT_ENTER); return true;
    case WXF_EVT_CLOSE_WINDOW: f(wxEVT_CLOSE_WINDOW); return true;
    case WXF_EVT_SIZE: f(wxEVT_SIZE); return true;
    case WXF_EVT_DESTROY: f(wxEVT_DESTROY); return true;
    case WXF_EVT_CHECKBOX: f(wxEVT_CHECKBOX); return true;
    default: return false;
    }
}

void on_event(wxEvent &e);

struct current_event {
    wxEvent *event;
    int kind;
};

// Events being dispatched (handlers may nest, e.g. set_value inside a handler).
std::vector<current_event> &event_stack() {
    static auto *v = new std::vector<current_event>;
    return *v;
}

void on_event(wxEvent &e) {
    auto *data = dynamic_cast<wxf_slot_data *>(e.GetEventUserData());
    if (!data || !wxf_dispatcher) {
        e.Skip();
        return;
    }
    // A destroy event is also sent to handlers of the window's children: only
    // report it for the window the handler was bound to.
    if (data->kind == WXF_EVT_DESTROY) {
        e.Skip();
        auto it = bindings().find(data->slot);
        if (it == bindings().end() || e.GetEventObject() != it->second.handler) return;
    }
    event_stack().push_back({&e, data->kind});
    try {
        wxf_dispatcher(data->slot, &e, data->kind);
    } catch (...) {
    }
    event_stack().pop_back();
}

}   // namespace

// Bind Fortran slot `slot` to events of `kind` on window `h`.
WXF_API int wxf_bind(int64_t h, int kind, int slot) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    if (!with_event_tag(kind, [](const auto &) {}))
        return wxf_fail(WXF_ERR_ARGUMENT, "unknown event kind " + std::to_string(kind));
    auto *data = new wxf_slot_data(slot, kind);
    bindings()[slot] = {w, kind, data};
    with_event_tag(kind, [&](const auto &tag) { w->Bind(tag, &on_event, wxID_ANY, wxID_ANY, data); });
    return WXF_OK;
    WXF_CATCH
}

// Unbind the handler that owns `slot` (its slot is released). `found` is 1 if
// it was still bound.
WXF_API int wxf_unbind(int slot, int *found) {
    WXF_TRY
    *found = 0;
    auto it = bindings().find(slot);
    if (it == bindings().end()) return WXF_OK;
    const binding b = it->second;
    // deletes the wxf_slot_data, which erases the entry and releases the slot
    with_event_tag(b.kind, [&](const auto &tag) {
        if (b.handler->Unbind(tag, &on_event, wxID_ANY, wxID_ANY, b.data)) *found = 1;
    });
    return WXF_OK;
    WXF_CATCH
}

namespace {
// Owns a slot for a deferred call; releases it when the call is done or dropped.
struct deferred_slot {
    int slot;
    explicit deferred_slot(int slot) : slot(slot) {}
    ~deferred_slot() {
        if (wxf_releaser) wxf_releaser(slot);
    }
};
}   // namespace

// Call Fortran slot `slot` once, from the event loop, after the current event.
WXF_API int wxf_call_after(int slot) {
    WXF_TRY
    WXF_NEED_APP();
    auto owner = std::make_shared<deferred_slot>(slot);
    wxTheApp->CallAfter([owner]() {
        if (wxf_dispatcher) wxf_dispatcher(owner->slot, nullptr, 0);
    });
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// event accessors: `e` is the event passed to the Fortran handler, valid only
// while the handler runs.

namespace {
// The event, if it is the one (or one of the nested ones) being dispatched.
wxEvent *live_event(void *e) {
    for (const current_event &c : event_stack())
        if (c.event == e) return c.event;
    return nullptr;
}
}   // namespace

#define WXF_EVENT(var, e)                                                      \
    wxEvent *var = live_event(e);                                              \
    if (!var) return wxf_fail(WXF_ERR_STATE, "event used outside of its handler")

WXF_API int wxf_event_skip(void *e, int skip) {
    WXF_TRY
    WXF_EVENT(ev, e);
    ev->Skip(skip != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_event_get_skipped(void *e, int *skipped) {
    WXF_TRY
    WXF_EVENT(ev, e);
    *skipped = wxf_bool(ev->GetSkipped());
    return WXF_OK;
    WXF_CATCH
}

// The handle of the window that generated the event (0 if not a wxf window).
WXF_API int wxf_event_get_source(void *e, int64_t *h) {
    WXF_TRY
    WXF_EVENT(ev, e);
    *h = wxf_handle_of(dynamic_cast<wxWindow *>(ev->GetEventObject()));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_event_get_id(void *e, int *id) {
    WXF_TRY
    WXF_EVENT(ev, e);
    *id = ev->GetId();
    return WXF_OK;
    WXF_CATCH
}

// Command events: the integer value (e.g. 1/0 for a checkbox).
WXF_API int wxf_event_get_int(void *e, int *value) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *c = dynamic_cast<wxCommandEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a command event");
    *value = c->GetInt();
    return WXF_OK;
    WXF_CATCH
}

// Command events: the string value (e.g. the text of a text control).
WXF_API int wxf_event_get_string(void *e, char **s, int *len) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *c = dynamic_cast<wxCommandEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a command event");
    wxf_out_str(c->GetString(), s, len);
    return WXF_OK;
    WXF_CATCH
}

// Close events: 1 if the close can be vetoed.
WXF_API int wxf_event_can_veto(void *e, int *can) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *c = dynamic_cast<wxCloseEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a close event");
    *can = wxf_bool(c->CanVeto());
    return WXF_OK;
    WXF_CATCH
}

// Close events: refuse the close (only if it can be vetoed).
WXF_API int wxf_event_veto(void *e) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *c = dynamic_cast<wxCloseEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a close event");
    if (!c->CanVeto()) return wxf_fail(WXF_ERR_STATE, "this close event cannot be vetoed");
    c->Veto();
    return WXF_OK;
    WXF_CATCH
}

// Size events: the new size.
WXF_API int wxf_event_get_size(void *e, int *width, int *height) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *c = dynamic_cast<wxSizeEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a size event");
    *width = c->GetSize().GetWidth();
    *height = c->GetSize().GetHeight();
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxWindow

// Destroy the window (and its children). Top-level windows are deleted when
// pending events are next processed; their handle is invalid immediately.
WXF_API int wxf_window_destroy(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Destroy();
    return WXF_OK;
    WXF_CATCH
}

// Ask the window to close (sends a close event). `closed` is 0 if vetoed.
WXF_API int wxf_window_close(int64_t h, int force, int *closed) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *closed = wxf_bool(w->Close(force != 0));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_show(int64_t h, int show) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Show(show != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_is_shown(int64_t h, int *shown) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *shown = wxf_bool(w->IsShown());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_enable(int64_t h, int enable) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Enable(enable != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_is_enabled(int64_t h, int *enabled) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *enabled = wxf_bool(w->IsEnabled());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_label(int64_t h, const char *s, int len) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->SetLabel(wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_get_label(int64_t h, char **s, int *len) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxf_out_str(w->GetLabel(), s, len);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_size(int64_t h, int width, int height) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->SetSize(width, height);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_get_size(int64_t h, int *width, int *height) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->GetSize(width, height);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_min_size(int64_t h, int width, int height) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->SetMinSize(wxSize(width, height));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_position(int64_t h, int x, int y) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Move(x, y);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_get_position(int64_t h, int *x, int *y) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->GetPosition(x, y);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_get_parent(int64_t h, int64_t *parent) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *parent = wxf_handle_of(w->GetParent());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_get_id(int64_t h, int *id) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *id = w->GetId();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_focus(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->SetFocus();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_layout(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Layout();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_fit(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Fit();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_center(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Centre();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_tooltip(int64_t h, const char *s, int len) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->SetToolTip(wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

// Number of direct child windows.
WXF_API int wxf_window_child_count(int64_t h, int *n) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *n = static_cast<int>(w->GetChildren().GetCount());
    return WXF_OK;
    WXF_CATCH
}

// Set sizer `s` on window `h`; the window then owns it (and deletes any
// sizer it had before, which becomes invalid). `fit`: also size the window
// to fit the sizer (SetSizerAndFit).
WXF_API int wxf_window_set_sizer(int64_t h, int64_t s, int fit) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxSizer *sizer = wxf_sizer(s);
    if (!sizer) return wxf_fail_handle(s);
    if (wxf_sizer_owner(s) != 0) return wxf_fail(WXF_ERR_STATE, "sizer is already owned by a window or sizer");
    if (wxSizer *old = w->GetSizer()) {
        if (old == sizer) return WXF_OK;
        wxf_sizer_kill(old);
    }
    if (fit) w->SetSizerAndFit(sizer);
    else w->SetSizer(sizer);
    wxf_sizer_set_owner(s, h);
    return WXF_OK;
    WXF_CATCH
}

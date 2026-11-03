// C ABI shim over wxWidgets core: errors, strings, handles, application and
// event loop, event dispatch to Fortran, and the operations shared by all
// windows and sizers.

#include "wxf_common.h"
#include "wxf_graphics.h"

#include <wx/init.h>
#include <wx/notebook.h>
#include <wx/spinctrl.h>
#include <wx/tracker.h>
#include <wx/weakref.h>

#include <cstdio>
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

// Record an error found on the Fortran side; returns `status`.
WXF_API int wxf_set_error(int status, const char *msg, int len) {
    return wxf_fail(status, std::string(msg, static_cast<size_t>(len > 0 ? len : 0)));
}

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

wxArrayString wxf_strings(const char *s, int itemlen, int n) {
    wxArrayString list;
    for (int i = 0; i < n; ++i) {
        const char *item = s + static_cast<size_t>(i) * static_cast<size_t>(itemlen);
        int len = itemlen;
        while (len > 0 && item[len - 1] == ' ') --len;
        list.Add(wxf_str(item, len));
    }
    return list;
}

void wxf_out_strings(const wxArrayString &list, char **out, int *len) {
    std::string all;
    for (const wxString &s : list) {
        all += s.utf8_str().data();
        all += '\0';
    }
    *len = static_cast<int>(all.size());
    *out = static_cast<char *>(std::malloc(all.size() + 1));
    std::memcpy(*out, all.data(), all.size());
    (*out)[all.size()] = '\0';
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
// Other event handlers (timers, menus) are tracked the same way.
//
// Sizers are not trackable: a sizer entry has an owner (the window it is set
// on, or the sizer it was added to) and is alive only while its owner chain is.

namespace {

struct entry {
    wxWindow *win = nullptr;
    wxEvtHandler *evh = nullptr;   // a tracked non-window event handler
    wxSizer *sizer = nullptr;
    wxBitmap *bitmap = nullptr;    // owned (deleted by wxf_delete_bitmap or cleanup)
    const void *key = nullptr;     // its key in reverse()
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

// Removes an entry when wxWidgets deletes the window or event handler.
struct window_tracker : wxTrackerNode {
    int64_t h;
    explicit window_tracker(int64_t h) : h(h) {}
    void OnObjectDestroy() override {
        auto it = table().find(h);
        if (it != table().end()) {
            reverse().erase(it->second.key);
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
        // dead if it, or an ancestor, is being deleted, is scheduled for
        // deletion (top-level windows are deleted later, when idle), or was
        // marked dead (destroyed from an event handler: see wxf_window_destroy)
        for (wxWindow *w = e.win; w; w = w->GetParent()) {
            if (w->IsBeingDeleted()) return false;
            if (wxTheApp && wxTheApp->IsScheduledForDestruction(w)) return false;
            if (w != e.win) {
                auto r = reverse().find(w);
                if (r != reverse().end()) {
                    auto a = table().find(r->second);
                    if (a != table().end() && a->second.dead) return false;
                }
            }
        }
        return true;
    }
    if (e.bitmap) return true;
    if (e.evh) {
        // a timer owned by a window dies with it (as soon as the window is
        // being destroyed, not only when wxWidgets deletes the timer)
        if (e.owner != 0) return depth < 1000 && alive(e.owner, depth + 1);
        // a menu in a menu bar dies with the bar and its frame
        if (auto *m = dynamic_cast<wxMenu *>(e.evh)) {
            while (m->GetParent()) m = m->GetParent();
            if (wxMenuBar *bar = m->GetMenuBar()) {
                const int64_t bh = wxf_handle_of(bar);
                if (bh != 0 && !alive(bh, depth + 1)) return false;
                const int64_t fh = wxf_handle_of(bar->GetFrame());
                if (fh != 0 && !alive(fh, depth + 1)) return false;
            }
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
    e.key = w;
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

int64_t wxf_register_handler(wxEvtHandler *p) {
    if (!p) return 0;
    const int64_t h = ++next_handle;
    entry e;
    e.evh = p;
    e.key = p;
    table()[h] = e;
    reverse()[p] = h;
    p->AddNode(new window_tracker(h));
    return h;
}

wxEvtHandler *wxf_handler(int64_t h) {
    if (h <= 0 || !alive(h)) return nullptr;
    const entry &e = table()[h];
    if (e.win) return e.win;
    return e.evh;
}

int64_t wxf_handle_of_handler(const wxEvtHandler *p) {
    if (!p) return 0;
    auto it = reverse().find(p);
    return it == reverse().end() ? 0 : it->second;
}

void wxf_mark_dead(int64_t h) {
    auto it = table().find(h);
    if (it != table().end()) it->second.dead = true;
}

int64_t wxf_register_bitmap(wxBitmap *b) {
    const int64_t h = ++next_handle;
    entry e;
    e.bitmap = b;
    e.key = b;
    table()[h] = e;
    reverse()[b] = h;
    return h;
}

wxBitmap *wxf_bitmap(int64_t h) {
    if (h <= 0) return nullptr;
    auto it = table().find(h);
    if (it == table().end() || it->second.dead) return nullptr;
    return it->second.bitmap;
}

void wxf_delete_bitmap(int64_t h) {
    auto it = table().find(h);
    if (it == table().end() || !it->second.bitmap) return;
    delete it->second.bitmap;
    reverse().erase(it->second.key);
    table().erase(it);
}

int64_t wxf_register_sizer(wxSizer *s) {
    const int64_t h = ++next_handle;
    entry e;
    e.sizer = s;
    e.key = s;
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

namespace {
// wxWidgets assertion failures would otherwise open a modal dialog: report
// them on stderr (and as the last error) and continue, as wx does after one.
void assert_handler(const wxString &file, int line, const wxString &func, const wxString &cond,
                    const wxString &msg) {
    const wxString text = wxString::Format("wxWidgets assertion failed: %s(%d) in %s(): %s%s%s", file,
                                           line, func, cond, msg.empty() ? "" : ": ", msg);
    std::fprintf(stderr, "%s\n", static_cast<const char *>(text.utf8_str()));
    wxf_fail(WXF_ERR_FAILED, std::string(text.utf8_str()));
}
}   // namespace

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
    wxSetAssertHandler(assert_handler);
    wxApp::SetInstance(new wxfApp);
    if (!wxEntryStart(app_argc, app_argv)) {
        return wxf_fail(WXF_ERR_FAILED, "wxEntryStart failed (is a display available?)");
    }
    if (!wxTheApp || !wxTheApp->CallOnInit()) {
        wxEntryCleanup();
        return wxf_fail(WXF_ERR_FAILED, "wxApp::OnInit failed");
    }
    wxInitAllImageHandlers();   // PNG for saving and loading images
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
    // Delete what wxWidgets would not: timers, menus and menu bars not owned
    // by a window (copy first: deleting erases table entries).
    std::vector<wxEvtHandler *> orphans;
    std::vector<wxMenuBar *> bars;
    std::vector<int64_t> bitmaps;
    for (const auto &kv : table()) {
        const entry &e = kv.second;
        if (e.bitmap) bitmaps.push_back(kv.first);
        if (auto *t = dynamic_cast<wxTimer *>(e.evh)) orphans.push_back(t);
        if (auto *m = dynamic_cast<wxMenu *>(e.evh))
            if (!m->IsAttached() && !m->GetParent()) orphans.push_back(m);
        if (auto *b = dynamic_cast<wxMenuBar *>(e.win))
            if (!b->IsAttached()) bars.push_back(b);
    }
    for (wxEvtHandler *p : orphans) delete p;
    for (int64_t h : bitmaps) wxf_delete_bitmap(h);
    for (wxMenuBar *b : bars) delete b;
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
    int64_t h;   // handle of the window/handler the handler is bound to
    int kind;
    int id;      // window/menu item id the binding is limited to, or wxID_ANY
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
    case WXF_EVT_TIMER: f(wxEVT_TIMER); return true;
    case WXF_EVT_MENU: f(wxEVT_MENU); return true;
    case WXF_EVT_PAINT: f(wxfEVT_DRAW); return true;
    case WXF_EVT_LEFT_DOWN: f(wxEVT_LEFT_DOWN); return true;
    case WXF_EVT_LEFT_UP: f(wxEVT_LEFT_UP); return true;
    case WXF_EVT_RIGHT_DOWN: f(wxEVT_RIGHT_DOWN); return true;
    case WXF_EVT_MOTION: f(wxEVT_MOTION); return true;
    case WXF_EVT_MOUSEWHEEL: f(wxEVT_MOUSEWHEEL); return true;
    case WXF_EVT_KEY_DOWN: f(wxEVT_KEY_DOWN); return true;
    case WXF_EVT_LEFT_DCLICK: f(wxEVT_LEFT_DCLICK); return true;
    case WXF_EVT_LEAVE_WINDOW: f(wxEVT_LEAVE_WINDOW); return true;
    case WXF_EVT_CHOICE: f(wxEVT_CHOICE); return true;
    case WXF_EVT_LISTBOX: f(wxEVT_LISTBOX); return true;
    case WXF_EVT_LISTBOX_DCLICK: f(wxEVT_LISTBOX_DCLICK); return true;
    case WXF_EVT_SLIDER: f(wxEVT_SLIDER); return true;
    case WXF_EVT_SPINCTRL: f(wxEVT_SPINCTRL); return true;
    case WXF_EVT_RADIOBOX: f(wxEVT_RADIOBOX); return true;
    case WXF_EVT_SPINCTRLDOUBLE: f(wxEVT_SPINCTRLDOUBLE); return true;
    case WXF_EVT_NOTEBOOK_PAGE_CHANGED: f(wxEVT_NOTEBOOK_PAGE_CHANGED); return true;
    case WXF_EVT_NOTEBOOK_PAGE_CHANGING: f(wxEVT_NOTEBOOK_PAGE_CHANGING); return true;
    case WXF_EVT_RIGHT_UP: f(wxEVT_RIGHT_UP); return true;
    case WXF_EVT_MOUSE_CAPTURE_LOST: f(wxEVT_MOUSE_CAPTURE_LOST); return true;
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
    auto it = bindings().find(data->slot);
    if (it == bindings().end()) return;
    if (data->kind == WXF_EVT_DESTROY) {
        // A destroy event is also sent to handlers of the window's children:
        // only report it for the window the handler was bound to.
        e.Skip();
        if (e.GetEventObject() != it->second.handler) return;
    } else if (!wxf_handler(it->second.h)) {
        // the window was destroyed (its deletion may be pending): no more
        // events for its handlers
        return;
    }
    // a click gives a canvas the keyboard focus (as default processing would)
    if (data->kind == WXF_EVT_LEFT_DOWN || data->kind == WXF_EVT_RIGHT_DOWN)
        if (auto *c = dynamic_cast<wxfCanvas *>(it->second.handler)) c->SetFocus();
    event_stack().push_back({&e, data->kind});
    try {
        wxf_dispatcher(data->slot, &e, data->kind);
    } catch (...) {
    }
    event_stack().pop_back();
}

}   // namespace

bool wxf_dispatching() { return !event_stack().empty(); }

wxGraphicsContext *wxf_live_graphics(void *gc, wxfDrawEvent **ev) {
    if (!gc) return nullptr;
    for (const current_event &c : event_stack()) {
        auto *d = dynamic_cast<wxfDrawEvent *>(c.event);
        if (d && d->gc == gc) {
            if (ev) *ev = d;
            return d->gc;
        }
    }
    return nullptr;
}

void wxf_dispatch_draw(int slot, wxfDrawEvent &ev) {
    if (!wxf_dispatcher) return;
    event_stack().push_back({&ev, WXF_EVT_PAINT});
    try {
        wxf_dispatcher(slot, &ev, WXF_EVT_PAINT);
    } catch (...) {
    }
    event_stack().pop_back();
}

// Bind Fortran slot `slot` to events of `kind` on window or event handler
// `h`, from the window or menu item `id` only (wxID_ANY: from any).
WXF_API int wxf_bind(int64_t h, int kind, int slot, int id) {
    WXF_TRY
    WXF_NEED_APP();
    wxEvtHandler *w = wxf_handler(h);
    if (!w) return wxf_fail_handle(h);
    if (!with_event_tag(kind, [](const auto &) {}))
        return wxf_fail(WXF_ERR_ARGUMENT, "unknown event kind " + std::to_string(kind));
    if (kind == WXF_EVT_PAINT && !dynamic_cast<wxfCanvas *>(w))
        return wxf_fail(WXF_ERR_ARGUMENT, "paint events are sent only to a wx_canvas");
    auto *data = new wxf_slot_data(slot, kind);
    bindings()[slot] = {w, h, kind, id, data};
    with_event_tag(kind, [&](const auto &tag) { w->Bind(tag, &on_event, id, wxID_ANY, data); });
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
        if (b.handler->Unbind(tag, &on_event, b.id, wxID_ANY, b.data)) *found = 1;
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

// The handle of the window or handler that generated the event (0 if it was
// not created through wxf).
WXF_API int wxf_event_get_source(void *e, int64_t *h) {
    WXF_TRY
    WXF_EVENT(ev, e);
    wxObject *o = ev->GetEventObject();
    *h = wxf_handle_of(dynamic_cast<wxWindow *>(o));
    if (*h == 0) *h = wxf_handle_of_handler(dynamic_cast<wxEvtHandler *>(o));
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

// Choice, list box and radio box events: the item (1-based; 0: none).
WXF_API int wxf_event_get_selection(void *e, int *index) {
    WXF_TRY
    WXF_EVENT(ev, e);
    int sel;
    if (auto *b = dynamic_cast<wxBookCtrlEvent *>(ev)) {
        sel = b->GetSelection();   // the new page (not the command event's int)
    } else {
        auto *c = dynamic_cast<wxCommandEvent *>(ev);
        if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a command event");
        sel = c->GetSelection();
    }
    *index = sel < 0 ? 0 : sel + 1;
    return WXF_OK;
    WXF_CATCH
}

// Real-valued spin control events: the new value.
WXF_API int wxf_event_get_double(void *e, double *value) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *s = dynamic_cast<wxSpinDoubleEvent *>(ev);
    if (!s) return wxf_fail(WXF_ERR_ARGUMENT, "not a real-valued spin control event");
    *value = s->GetValue();
    return WXF_OK;
    WXF_CATCH
}

// Close and "changing" (notify) events: 1 if the change can be vetoed.
WXF_API int wxf_event_can_veto(void *e, int *can) {
    WXF_TRY
    WXF_EVENT(ev, e);
    if (auto *n = dynamic_cast<wxNotifyEvent *>(ev)) {
        *can = 1;
        (void)n;
        return WXF_OK;
    }
    auto *c = dynamic_cast<wxCloseEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a close or notebook page-changing event");
    *can = wxf_bool(c->CanVeto());
    return WXF_OK;
    WXF_CATCH
}

// Close and "changing" events: refuse the change (if it can be vetoed).
WXF_API int wxf_event_veto(void *e) {
    WXF_TRY
    WXF_EVENT(ev, e);
    if (auto *n = dynamic_cast<wxNotifyEvent *>(ev)) {
        n->Veto();
        return WXF_OK;
    }
    auto *c = dynamic_cast<wxCloseEvent *>(ev);
    if (!c) return wxf_fail(WXF_ERR_ARGUMENT, "not a close or notebook page-changing event");
    if (!c->CanVeto()) return wxf_fail(WXF_ERR_STATE, "this close event cannot be vetoed");
    c->Veto();
    return WXF_OK;
    WXF_CATCH
}

// Mouse events: the position in the window, in pixels.
WXF_API int wxf_event_get_position(void *e, int *x, int *y) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *m = dynamic_cast<wxMouseEvent *>(ev);
    if (!m) return wxf_fail(WXF_ERR_ARGUMENT, "not a mouse event");
    *x = m->GetX();
    *y = m->GetY();
    return WXF_OK;
    WXF_CATCH
}

// Mouse wheel events: rotation in notches (positive: away from the user).
WXF_API int wxf_event_get_wheel(void *e, double *steps) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *m = dynamic_cast<wxMouseEvent *>(ev);
    if (!m) return wxf_fail(WXF_ERR_ARGUMENT, "not a mouse event");
    const int delta = m->GetWheelDelta() > 0 ? m->GetWheelDelta() : 120;
    *steps = static_cast<double>(m->GetWheelRotation()) / delta;
    return WXF_OK;
    WXF_CATCH
}

// Mouse events: 1 if the left button is down.
WXF_API int wxf_event_left_is_down(void *e, int *down) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *m = dynamic_cast<wxMouseEvent *>(ev);
    if (!m) return wxf_fail(WXF_ERR_ARGUMENT, "not a mouse event");
    *down = wxf_bool(m->LeftIsDown());
    return WXF_OK;
    WXF_CATCH
}

// Key events: the key code (WXK_* or the upper-case ASCII letter/digit) and
// the Unicode character (0 if none).
WXF_API int wxf_event_get_key(void *e, int *code, int *unicode) {
    WXF_TRY
    WXF_EVENT(ev, e);
    auto *k = dynamic_cast<wxKeyEvent *>(ev);
    if (!k) return wxf_fail(WXF_ERR_ARGUMENT, "not a key event");
    *code = k->GetKeyCode();
    *unicode = static_cast<int>(k->GetUnicodeKey());
    return WXF_OK;
    WXF_CATCH
}

// Mouse and key events: modifier keys held (WXF_MOD_* bits). Control is
// Cmd on macOS.
WXF_API int wxf_event_get_modifiers(void *e, int *mods) {
    WXF_TRY
    WXF_EVENT(ev, e);
    const wxKeyboardState *s = dynamic_cast<wxMouseEvent *>(ev);
    if (!s) s = dynamic_cast<wxKeyEvent *>(ev);
    if (!s) return wxf_fail(WXF_ERR_ARGUMENT, "not a mouse or key event");
    *mods = (s->ShiftDown() ? WXF_MOD_SHIFT : 0) | (s->ControlDown() ? WXF_MOD_CONTROL : 0) |
            (s->AltDown() ? WXF_MOD_ALT : 0);
    return WXF_OK;
    WXF_CATCH
}

// Paint events: the borrowed graphics context and the drawing area size.
WXF_API int wxf_event_get_graphics(void *e, void **gc, double *width, double *height) {
    WXF_TRY
    WXF_EVENT(ev, e);
    *gc = nullptr;
    auto *d = dynamic_cast<wxfDrawEvent *>(ev);
    if (!d) return wxf_fail(WXF_ERR_ARGUMENT, "not a paint event");
    *gc = d->gc;
    *width = d->width;
    *height = d->height;
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
//
// A child window destroyed while an event is being dispatched (from a Fortran
// handler) may be the window processing that event, or one of its parents:
// deleting it now would leave wxWidgets using freed memory when the handler
// returns. It is hidden and its handle invalidated now, and it is deleted from
// the event loop (or the next process_pending).
WXF_API int wxf_window_destroy(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    if (auto *bar = dynamic_cast<wxMenuBar *>(w))
        if (bar->IsAttached())
            return wxf_fail(WXF_ERR_STATE, "menu bar is owned by a frame");
    if (!w->IsTopLevel() && !event_stack().empty()) {
        table()[h].dead = true;
        w->Hide();
        wxWeakRef<wxWindow> ref(w);
        wxTheApp->CallAfter([ref]() {
            if (ref) ref->Destroy();
        });
        return WXF_OK;
    }
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

// Capture the mouse: the window gets all mouse events (e.g. a drag that
// leaves it) until wxf_window_release_mouse, or until the capture is lost
// (WXF_EVT_MOUSE_CAPTURE_LOST, e.g. another application took the focus).
WXF_API int wxf_window_capture_mouse(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    if (w->HasCapture()) return WXF_OK;
    // wxWidgets requires capture-lost events to be handled: a default handler
    // (Fortran handlers bound to the event run first)
    static auto *with_handler = new std::unordered_map<int64_t, bool>;
    if (!(*with_handler)[h]) {
        (*with_handler)[h] = true;
        w->Bind(wxEVT_MOUSE_CAPTURE_LOST, [](wxMouseCaptureLostEvent &) {});
    }
    w->CaptureMouse();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_release_mouse(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    if (w->HasCapture()) w->ReleaseMouse();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_has_capture(int64_t h, int *has) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *has = wxf_bool(w->HasCapture());
    return WXF_OK;
    WXF_CATCH
}

// Cursor shown over the window: must match WX_CURSOR_* in src/c/wx_c_core.f90.
WXF_API int wxf_window_set_cursor(int64_t h, int kind) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxStockCursor c;
    switch (kind) {
    case 0: c = wxCURSOR_ARROW; break;
    case 1: c = wxCURSOR_CROSS; break;
    case 2: c = wxCURSOR_HAND; break;
    case 3: c = wxCURSOR_WAIT; break;
    case 4: c = wxCURSOR_SIZING; break;
    case 5: c = wxCURSOR_IBEAM; break;
    case 6: c = wxCURSOR_MAGNIFIER; break;
    default: return wxf_fail(WXF_ERR_ARGUMENT, "unknown cursor");
    }
    w->SetCursor(wxCursor(c));
    return WXF_OK;
    WXF_CATCH
}

// The busy (wait) cursor for the whole application, nestable.
WXF_API int wxf_begin_busy_cursor() {
    WXF_TRY
    WXF_NEED_APP();
    wxBeginBusyCursor();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_end_busy_cursor() {
    WXF_TRY
    WXF_NEED_APP();
    if (wxIsBusy()) wxEndBusyCursor();
    return WXF_OK;
    WXF_CATCH
}

// Physical pixels per logical pixel (2 on a typical high-DPI screen).
WXF_API int wxf_window_get_content_scale_factor(int64_t h, double *scale) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    *scale = w->GetContentScaleFactor();
    return WXF_OK;
    WXF_CATCH
}

// Repaint the window soon (canvases: their paint handlers run again).
WXF_API int wxf_window_refresh(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->Refresh();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_set_background_color(int64_t h, int r, int g, int b, int a) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->SetBackgroundColour(wxf_color(r, g, b, a));
    w->Refresh();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_window_get_client_size(int64_t h, int *width, int *height) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    w->GetClientSize(width, height);
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

// C ABI shim over wxWidgets windows, controls and sizers.
//
// Creation functions take the parent handle (0 for none, top-level windows
// only), return the new handle in `out`, and register the window so that its
// handle becomes invalid when wxWidgets deletes it. Child windows are owned
// and deleted by their parent.

#include "wxf_common.h"

#include <wx/sizer.h>

#define WXF_PARENT(var, h)                                                     \
    WXF_NEED_APP();                                                            \
    wxWindow *var = wxf_window(h);                                             \
    if (!var) return wxf_fail_handle(h)

// ---------------------------------------------------------------------------
// wxFrame

WXF_API int wxf_frame_create(int64_t parent, const char *title, int len, int width, int height,
                             int64_t *out) {
    WXF_TRY
    WXF_NEED_APP();
    wxWindow *p = nullptr;
    if (parent != 0) {
        p = wxf_window(parent);
        if (!p) return wxf_fail_handle(parent);
    }
    const wxSize size = (width > 0 && height > 0) ? wxSize(width, height) : wxDefaultSize;
    auto *f = new wxFrame(p, wxID_ANY, wxf_str(title, len), wxDefaultPosition, size);
    *out = wxf_register(f);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_frame_set_title(int64_t h, const char *s, int len) {
    WXF_TRY
    WXF_GET(wxTopLevelWindow, w, h);
    w->SetTitle(wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_frame_get_title(int64_t h, char **s, int *len) {
    WXF_TRY
    WXF_GET(wxTopLevelWindow, w, h);
    wxf_out_str(w->GetTitle(), s, len);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxPanel

WXF_API int wxf_panel_create(int64_t parent, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxPanel(p, wxID_ANY));
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxStaticText

WXF_API int wxf_static_text_create(int64_t parent, const char *label, int len, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxStaticText(p, wxID_ANY, wxf_str(label, len)));
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxButton

WXF_API int wxf_button_create(int64_t parent, const char *label, int len, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxButton(p, wxID_ANY, wxf_str(label, len)));
    return WXF_OK;
    WXF_CATCH
}

// Send a button-clicked event to the button's handlers, as a click would.
WXF_API int wxf_button_emit_click(int64_t h) {
    WXF_TRY
    WXF_GET(wxButton, b, h);
    wxCommandEvent ev(wxEVT_BUTTON, b->GetId());
    ev.SetEventObject(b);
    b->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// Queue a button-clicked event: it is delivered by the event loop (or the
// next process_pending), like a real click, not before this returns.
WXF_API int wxf_button_post_click(int64_t h) {
    WXF_TRY
    WXF_GET(wxButton, b, h);
    auto *ev = new wxCommandEvent(wxEVT_BUTTON, b->GetId());
    ev->SetEventObject(b);
    wxQueueEvent(b, ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxTextCtrl

// Style bits: must match WX_TE_* in src/wx_c_widgets.f90.
enum { WXF_TE_MULTILINE = 1, WXF_TE_PROCESS_ENTER = 2, WXF_TE_READONLY = 4, WXF_TE_PASSWORD = 8 };

WXF_API int wxf_text_ctrl_create(int64_t parent, const char *value, int len, int style,
                                 int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    long wx_style = 0;
    if (style & WXF_TE_MULTILINE) wx_style |= wxTE_MULTILINE;
    if (style & WXF_TE_PROCESS_ENTER) wx_style |= wxTE_PROCESS_ENTER;
    if (style & WXF_TE_READONLY) wx_style |= wxTE_READONLY;
    if (style & WXF_TE_PASSWORD) wx_style |= wxTE_PASSWORD;
    *out = wxf_register(new wxTextCtrl(p, wxID_ANY, wxf_str(value, len), wxDefaultPosition,
                                       wxDefaultSize, wx_style));
    return WXF_OK;
    WXF_CATCH
}

// Set the text; `notify` != 0 sends a text-changed event (SetValue), else not
// (ChangeValue).
WXF_API int wxf_text_ctrl_set_value(int64_t h, const char *s, int len, int notify) {
    WXF_TRY
    WXF_GET(wxTextCtrl, t, h);
    if (notify) t->SetValue(wxf_str(s, len));
    else t->ChangeValue(wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_text_ctrl_get_value(int64_t h, char **s, int *len) {
    WXF_TRY
    WXF_GET(wxTextCtrl, t, h);
    wxf_out_str(t->GetValue(), s, len);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_text_ctrl_append(int64_t h, const char *s, int len) {
    WXF_TRY
    WXF_GET(wxTextCtrl, t, h);
    t->AppendText(wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_text_ctrl_clear(int64_t h) {
    WXF_TRY
    WXF_GET(wxTextCtrl, t, h);
    t->Clear();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_text_ctrl_set_editable(int64_t h, int editable) {
    WXF_TRY
    WXF_GET(wxTextCtrl, t, h);
    t->SetEditable(editable != 0);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxCheckBox

WXF_API int wxf_check_box_create(int64_t parent, const char *label, int len, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxCheckBox(p, wxID_ANY, wxf_str(label, len)));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_check_box_set_value(int64_t h, int value) {
    WXF_TRY
    WXF_GET(wxCheckBox, c, h);
    c->SetValue(value != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_check_box_get_value(int64_t h, int *value) {
    WXF_TRY
    WXF_GET(wxCheckBox, c, h);
    *value = wxf_bool(c->GetValue());
    return WXF_OK;
    WXF_CATCH
}

// Toggle the box and send a checkbox event to its handlers, as a click would.
WXF_API int wxf_check_box_emit_click(int64_t h) {
    WXF_TRY
    WXF_GET(wxCheckBox, c, h);
    c->SetValue(!c->GetValue());
    wxCommandEvent ev(wxEVT_CHECKBOX, c->GetId());
    ev.SetEventObject(c);
    ev.SetInt(c->GetValue() ? 1 : 0);
    c->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// sizers
//
// A new sizer is unattached: set it on a window (wxf_window_set_sizer) or add
// it to another sizer, which then own it; or destroy it with
// wxf_sizer_destroy. A sizer handle is valid while its owner chain is alive.

// Item flags: must match WX_* sizer flags in src/wx_c_widgets.f90.
enum {
    WXF_EXPAND = 1, WXF_ALL = 2, WXF_LEFT = 4, WXF_RIGHT = 8, WXF_TOP = 16, WXF_BOTTOM = 32,
    WXF_ALIGN_CENTER = 64, WXF_ALIGN_RIGHT = 128, WXF_ALIGN_BOTTOM = 256,
};

static int sizer_flags(int f) {
    int s = 0;
    if (f & WXF_EXPAND) s |= wxEXPAND;
    if (f & WXF_ALL) s |= wxALL;
    if (f & WXF_LEFT) s |= wxLEFT;
    if (f & WXF_RIGHT) s |= wxRIGHT;
    if (f & WXF_TOP) s |= wxTOP;
    if (f & WXF_BOTTOM) s |= wxBOTTOM;
    if (f & WXF_ALIGN_CENTER) s |= wxALIGN_CENTER;
    if (f & WXF_ALIGN_RIGHT) s |= wxALIGN_RIGHT;
    if (f & WXF_ALIGN_BOTTOM) s |= wxALIGN_BOTTOM;
    return s;
}

#define WXF_SIZER(var, h)                                                      \
    WXF_NEED_APP();                                                            \
    wxSizer *var = wxf_sizer(h);                                               \
    if (!var) return wxf_fail_handle(h)

// orient: 0 horizontal, 1 vertical.
WXF_API int wxf_box_sizer_create(int orient, int64_t *out) {
    WXF_TRY
    WXF_NEED_APP();
    *out = 0;
    if (orient != 0 && orient != 1)
        return wxf_fail(WXF_ERR_ARGUMENT, "box sizer orientation must be wxHORIZONTAL or wxVERTICAL");
    *out = wxf_register_sizer(new wxBoxSizer(orient ? wxVERTICAL : wxHORIZONTAL));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_sizer_add_window(int64_t s, int64_t h, int proportion, int flags, int border) {
    WXF_TRY
    WXF_SIZER(sizer, s);
    wxWindow *w = wxf_window(h);
    if (!w) return wxf_fail_handle(h);
    sizer->Add(w, proportion, sizer_flags(flags), border);
    return WXF_OK;
    WXF_CATCH
}

// Add sizer `child` to `s`, which then owns it.
WXF_API int wxf_sizer_add_sizer(int64_t s, int64_t child, int proportion, int flags, int border) {
    WXF_TRY
    WXF_SIZER(sizer, s);
    wxSizer *c = wxf_sizer(child);
    if (!c) return wxf_fail_handle(child);
    if (c == sizer) return wxf_fail(WXF_ERR_ARGUMENT, "cannot add a sizer to itself");
    if (wxf_sizer_owner(child) != 0) return wxf_fail(WXF_ERR_STATE, "sizer is already owned by a window or sizer");
    sizer->Add(c, proportion, sizer_flags(flags), border);
    wxf_sizer_set_owner(child, s);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_sizer_add_spacer(int64_t s, int size) {
    WXF_TRY
    WXF_SIZER(sizer, s);
    sizer->AddSpacer(size);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_sizer_add_stretch(int64_t s, int proportion) {
    WXF_TRY
    WXF_SIZER(sizer, s);
    sizer->AddStretchSpacer(proportion);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_sizer_item_count(int64_t s, int *n) {
    WXF_TRY
    WXF_SIZER(sizer, s);
    *n = static_cast<int>(sizer->GetItemCount());
    return WXF_OK;
    WXF_CATCH
}

// Delete an unattached sizer (an owned sizer is deleted by its owner).
WXF_API int wxf_sizer_destroy(int64_t s) {
    WXF_TRY
    WXF_SIZER(sizer, s);
    if (wxf_sizer_owner(s) != 0) return wxf_fail(WXF_ERR_STATE, "sizer is owned by a window or sizer");
    wxf_sizer_kill(sizer);
    delete sizer;
    wxf_sizer(s);   // forget the entry
    return WXF_OK;
    WXF_CATCH
}

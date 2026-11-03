// C ABI shim over item and value controls: wxChoice, wxListBox, wxRadioBox
// (lists of strings) and wxSlider, wxSpinCtrl, wxSpinCtrlDouble, wxGauge.
//
// Item indices are 1-based here (0: none), as in the Fortran API.

#include "wxf_common.h"

#include <wx/choice.h>
#include <wx/gauge.h>
#include <wx/listbox.h>
#include <wx/radiobox.h>
#include <wx/slider.h>
#include <wx/spinctrl.h>

#include <cstdlib>

#define WXF_PARENT(var, h)                                                     \
    WXF_NEED_APP();                                                            \
    wxWindow *var = wxf_window(h);                                             \
    if (!var) return wxf_fail_handle(h)

namespace {

// The item container of a list control (choice, list box, radio box), or null.
wxItemContainerImmutable *items_of(wxWindow *w) {
    if (auto *c = dynamic_cast<wxChoice *>(w)) return c;
    if (auto *l = dynamic_cast<wxListBox *>(w)) return l;
    if (auto *r = dynamic_cast<wxRadioBox *>(w)) return r;
    return nullptr;
}

// Its mutable container (choice, list box), or null (radio boxes are fixed).
wxItemContainer *mutable_items_of(wxWindow *w) {
    if (auto *c = dynamic_cast<wxChoice *>(w)) return c;
    if (auto *l = dynamic_cast<wxListBox *>(w)) return l;
    return nullptr;
}

}   // namespace

#define WXF_ITEMS(var, w, h)                                                   \
    WXF_GET(wxWindow, w, h);                                                   \
    wxItemContainerImmutable *var = items_of(w);                               \
    if (!var) return wxf_fail(WXF_ERR_INVALID_HANDLE, "not a choice, list box or radio box")

#define WXF_INDEX(c, i)                                                        \
    if ((i) < 1 || (i) > static_cast<int>((c)->GetCount()))                    \
    return wxf_fail(WXF_ERR_ARGUMENT, "item index " + std::to_string(i) + " out of range")

// ---------------------------------------------------------------------------
// creation

WXF_API int wxf_choice_create(int64_t parent, const char *items, int itemlen, int n, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    auto *c = new wxChoice(p, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxf_strings(items, itemlen, n));
    // the same on every platform: the first item is selected (macOS always
    // shows one; GTK would start with none)
    if (n > 0) c->SetSelection(0);
    *out = wxf_register(c);
    return WXF_OK;
    WXF_CATCH
}

// `multiple` != 0: several items can be selected (wxLB_EXTENDED).
WXF_API int wxf_list_box_create(int64_t parent, const char *items, int itemlen, int n, int multiple,
                                int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxListBox(p, wxID_ANY, wxDefaultPosition, wxDefaultSize,
                                      wxf_strings(items, itemlen, n), multiple ? wxLB_EXTENDED : wxLB_SINGLE));
    return WXF_OK;
    WXF_CATCH
}

// A labeled group of radio buttons, laid out in `major` columns (or rows if
// `by_rows`).
WXF_API int wxf_radio_box_create(int64_t parent, const char *label, int llen, const char *items, int itemlen,
                                 int n, int major, int by_rows, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = 0;
    if (n < 1) return wxf_fail(WXF_ERR_ARGUMENT, "a radio box needs at least one item");
    *out = wxf_register(new wxRadioBox(p, wxID_ANY, wxf_str(label, llen), wxDefaultPosition, wxDefaultSize,
                                       wxf_strings(items, itemlen, n), major > 0 ? major : 1,
                                       by_rows ? wxRA_SPECIFY_ROWS : wxRA_SPECIFY_COLS));
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// items (choice, list box, radio box)

WXF_API int wxf_items_count(int64_t h, int *n) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    *n = static_cast<int>(c->GetCount());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_items_get_string(int64_t h, int i, char **s, int *len) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    WXF_INDEX(c, i);
    wxf_out_str(c->GetString(i - 1), s, len);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_items_set_string(int64_t h, int i, const char *s, int len) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    WXF_INDEX(c, i);
    c->SetString(i - 1, wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

// The selected item (0: none; list boxes with several selected: the first).
WXF_API int wxf_items_get_selection(int64_t h, int *i) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    int sel = c->GetSelection();
    if (auto *l = dynamic_cast<wxListBox *>(w)) {
        if (l->HasMultipleSelection()) {
            wxArrayInt all;
            sel = l->GetSelections(all) > 0 ? all[0] : wxNOT_FOUND;
        }
    }
    *i = sel == wxNOT_FOUND ? 0 : sel + 1;
    return WXF_OK;
    WXF_CATCH
}

// Select item i (no event); 0 clears the selection (not for radio boxes).
WXF_API int wxf_items_set_selection(int64_t h, int i) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    if (i == 0) {
        if (dynamic_cast<wxRadioBox *>(w)) return wxf_fail(WXF_ERR_ARGUMENT, "a radio box always has a selection");
        if (auto *l = dynamic_cast<wxListBox *>(w)) l->DeselectAll();
        else c->SetSelection(wxNOT_FOUND);
        return WXF_OK;
    }
    WXF_INDEX(c, i);
    c->SetSelection(i - 1);
    return WXF_OK;
    WXF_CATCH
}

// Index of the item with text `s` (0: not found).
WXF_API int wxf_items_find(int64_t h, const char *s, int len, int *i) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    const int k = c->FindString(wxf_str(s, len), false);   // case-insensitive
    *i = k == wxNOT_FOUND ? 0 : k + 1;
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_items_append(int64_t h, const char *items, int itemlen, int n) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxItemContainer *c = mutable_items_of(w);
    if (!c) return wxf_fail(WXF_ERR_INVALID_HANDLE, "not a choice or list box");
    if (n > 0) c->Append(wxf_strings(items, itemlen, n));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_items_delete(int64_t h, int i) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxItemContainer *c = mutable_items_of(w);
    if (!c) return wxf_fail(WXF_ERR_INVALID_HANDLE, "not a choice or list box");
    WXF_INDEX(c, i);
    c->Delete(i - 1);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_items_clear(int64_t h) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxItemContainer *c = mutable_items_of(w);
    if (!c) return wxf_fail(WXF_ERR_INVALID_HANDLE, "not a choice or list box");
    c->Clear();
    return WXF_OK;
    WXF_CATCH
}

// Select item i and send the control's selection event, as a click would.
WXF_API int wxf_items_emit_select(int64_t h, int i) {
    WXF_TRY
    WXF_ITEMS(c, w, h);
    WXF_INDEX(c, i);
    wxEventType type;
    if (dynamic_cast<wxChoice *>(w)) type = wxEVT_CHOICE;
    else if (dynamic_cast<wxListBox *>(w)) type = wxEVT_LISTBOX;
    else type = wxEVT_RADIOBOX;
    c->SetSelection(i - 1);
    wxCommandEvent ev(type, w->GetId());
    ev.SetEventObject(w);
    ev.SetInt(i - 1);
    ev.SetString(c->GetString(i - 1));
    if (type == wxEVT_LISTBOX) ev.SetExtraLong(1);   // IsSelection(): selected, not deselected
    w->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// list box selections

// Selected items (1-based) as a malloc'd int array of length n.
WXF_API int wxf_list_box_get_selections(int64_t h, int **sel, int *n) {
    WXF_TRY
    WXF_GET(wxListBox, l, h);
    wxArrayInt all;
    *n = l->GetSelections(all);
    *sel = static_cast<int *>(std::malloc(sizeof(int) * (all.size() + 1)));
    for (size_t k = 0; k < all.size(); ++k) (*sel)[k] = all[k] + 1;
    return WXF_OK;
    WXF_CATCH
}

// Select (or deselect) item i without changing the others (multiple
// selection list boxes) or replacing the selection (single).
WXF_API int wxf_list_box_select(int64_t h, int i, int select) {
    WXF_TRY
    WXF_GET(wxListBox, l, h);
    WXF_INDEX(l, i);
    l->SetSelection(i - 1, select != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_list_box_is_selected(int64_t h, int i, int *selected) {
    WXF_TRY
    WXF_GET(wxListBox, l, h);
    WXF_INDEX(l, i);
    *selected = wxf_bool(l->IsSelected(i - 1));
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// slider

// `vertical`, `labels`: show the min/max/value labels.
WXF_API int wxf_slider_create(int64_t parent, int value, int min, int max, int vertical, int labels,
                              int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = 0;
    if (min > max) return wxf_fail(WXF_ERR_ARGUMENT, "slider minimum is larger than its maximum");
    long style = vertical ? wxSL_VERTICAL : wxSL_HORIZONTAL;
    if (labels) style |= wxSL_LABELS;
    *out = wxf_register(new wxSlider(p, wxID_ANY, value, min, max, wxDefaultPosition, wxDefaultSize, style));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_slider_set_value(int64_t h, int value) {
    WXF_TRY
    WXF_GET(wxSlider, s, h);
    s->SetValue(value);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_slider_get_value(int64_t h, int *value) {
    WXF_TRY
    WXF_GET(wxSlider, s, h);
    *value = s->GetValue();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_slider_set_range(int64_t h, int min, int max) {
    WXF_TRY
    WXF_GET(wxSlider, s, h);
    if (min > max) return wxf_fail(WXF_ERR_ARGUMENT, "slider minimum is larger than its maximum");
    s->SetRange(min, max);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_slider_get_range(int64_t h, int *min, int *max) {
    WXF_TRY
    WXF_GET(wxSlider, s, h);
    *min = s->GetMin();
    *max = s->GetMax();
    return WXF_OK;
    WXF_CATCH
}

// Move the slider and send wxEVT_SLIDER, as dragging it would.
WXF_API int wxf_slider_emit_change(int64_t h, int value) {
    WXF_TRY
    WXF_GET(wxSlider, s, h);
    s->SetValue(value);
    wxCommandEvent ev(wxEVT_SLIDER, s->GetId());
    ev.SetEventObject(s);
    ev.SetInt(s->GetValue());
    s->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// spin controls

WXF_API int wxf_spin_ctrl_create(int64_t parent, int value, int min, int max, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = 0;
    if (min > max) return wxf_fail(WXF_ERR_ARGUMENT, "spin control minimum is larger than its maximum");
    *out = wxf_register(new wxSpinCtrl(p, wxID_ANY, wxEmptyString, wxDefaultPosition, wxDefaultSize,
                                       wxSP_ARROW_KEYS, min, max, value));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_spin_ctrl_set_value(int64_t h, int value) {
    WXF_TRY
    WXF_GET(wxSpinCtrl, s, h);
    s->SetValue(value);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_spin_ctrl_get_value(int64_t h, int *value) {
    WXF_TRY
    WXF_GET(wxSpinCtrl, s, h);
    *value = s->GetValue();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_spin_ctrl_set_range(int64_t h, int min, int max) {
    WXF_TRY
    WXF_GET(wxSpinCtrl, s, h);
    if (min > max) return wxf_fail(WXF_ERR_ARGUMENT, "spin control minimum is larger than its maximum");
    s->SetRange(min, max);
    return WXF_OK;
    WXF_CATCH
}

// Set the value and send wxEVT_SPINCTRL, as the arrows would.
WXF_API int wxf_spin_ctrl_emit_change(int64_t h, int value) {
    WXF_TRY
    WXF_GET(wxSpinCtrl, s, h);
    s->SetValue(value);
    wxSpinEvent ev(wxEVT_SPINCTRL, s->GetId());
    ev.SetEventObject(s);
    ev.SetPosition(s->GetValue());
    s->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// A spin control for real values: `increment` per arrow click, `digits` shown.
WXF_API int wxf_spin_double_create(int64_t parent, double value, double min, double max, double increment,
                                   int digits, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = 0;
    if (min > max) return wxf_fail(WXF_ERR_ARGUMENT, "spin control minimum is larger than its maximum");
    auto *s = new wxSpinCtrlDouble(p, wxID_ANY, wxEmptyString, wxDefaultPosition, wxDefaultSize,
                                   wxSP_ARROW_KEYS, min, max, value, increment > 0 ? increment : 1);
    if (digits >= 0) s->SetDigits(static_cast<unsigned>(digits));
    *out = wxf_register(s);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_spin_double_set_value(int64_t h, double value) {
    WXF_TRY
    WXF_GET(wxSpinCtrlDouble, s, h);
    s->SetValue(value);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_spin_double_get_value(int64_t h, double *value) {
    WXF_TRY
    WXF_GET(wxSpinCtrlDouble, s, h);
    *value = s->GetValue();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_spin_double_set_range(int64_t h, double min, double max) {
    WXF_TRY
    WXF_GET(wxSpinCtrlDouble, s, h);
    if (min > max) return wxf_fail(WXF_ERR_ARGUMENT, "spin control minimum is larger than its maximum");
    s->SetRange(min, max);
    return WXF_OK;
    WXF_CATCH
}

// Set the value and send wxEVT_SPINCTRLDOUBLE.
WXF_API int wxf_spin_double_emit_change(int64_t h, double value) {
    WXF_TRY
    WXF_GET(wxSpinCtrlDouble, s, h);
    s->SetValue(value);
    wxSpinDoubleEvent ev(wxEVT_SPINCTRLDOUBLE, s->GetId(), s->GetValue());
    ev.SetEventObject(s);
    s->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// gauge (progress bar)

WXF_API int wxf_gauge_create(int64_t parent, int range, int vertical, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = 0;
    if (range < 1) return wxf_fail(WXF_ERR_ARGUMENT, "gauge range must be positive");
    *out = wxf_register(new wxGauge(p, wxID_ANY, range, wxDefaultPosition, wxDefaultSize,
                                    vertical ? wxGA_VERTICAL : wxGA_HORIZONTAL));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gauge_set_value(int64_t h, int value) {
    WXF_TRY
    WXF_GET(wxGauge, g, h);
    if (value < 0 || value > g->GetRange())
        return wxf_fail(WXF_ERR_ARGUMENT, "gauge value outside 0..range");
    g->SetValue(value);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gauge_get_value(int64_t h, int *value) {
    WXF_TRY
    WXF_GET(wxGauge, g, h);
    *value = g->GetValue();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gauge_set_range(int64_t h, int range) {
    WXF_TRY
    WXF_GET(wxGauge, g, h);
    if (range < 1) return wxf_fail(WXF_ERR_ARGUMENT, "gauge range must be positive");
    g->SetRange(range);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gauge_get_range(int64_t h, int *range) {
    WXF_TRY
    WXF_GET(wxGauge, g, h);
    *range = g->GetRange();
    return WXF_OK;
    WXF_CATCH
}

// Indeterminate mode: move the bar to show activity.
WXF_API int wxf_gauge_pulse(int64_t h) {
    WXF_TRY
    WXF_GET(wxGauge, g, h);
    g->Pulse();
    return WXF_OK;
    WXF_CATCH
}

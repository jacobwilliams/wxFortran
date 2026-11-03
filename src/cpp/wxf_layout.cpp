// C ABI shim over containers and layout: wxNotebook, wxSplitterWindow, grid
// and static box sizers, the frame toolbar, and wxStaticBitmap / RGB images.
//
// Notebook pages and splitter panes are windows created with the notebook or
// splitter as their parent. Page and tool indices are 1-based (0: none).

#include "wxf_common.h"
#include "wxf_graphics.h"

#include <wx/artprov.h>
#include <wx/notebook.h>
#include <wx/sizer.h>
#include <wx/splitter.h>
#include <wx/statbmp.h>
#include <wx/statbox.h>
#include <wx/toolbar.h>
#include <wx/weakref.h>

#include <cstring>

#define WXF_PARENT(var, h)                                                     \
    WXF_NEED_APP();                                                            \
    wxWindow *var = wxf_window(h);                                             \
    if (!var) return wxf_fail_handle(h)

namespace {

// An image from 8-bit RGB data (w*h*3 bytes, row by row from the top-left).
wxImage rgb_image(const unsigned char *rgb, int w, int h) {
    const size_t n = static_cast<size_t>(w) * static_cast<size_t>(h) * 3;
    auto *data = static_cast<unsigned char *>(std::malloc(n > 0 ? n : 1));   // wxImage frees it
    std::memcpy(data, rgb, n);
    return wxImage(w, h, data);
}

wxBitmapBundle art_or_file(const wxString &art, const wxString &file, int *status) {
    *status = WXF_OK;
    if (!file.empty()) {
        wxLogNull no_log_dialog;
        wxImage img;
        if (!img.LoadFile(file)) {
            *status = wxf_fail(WXF_ERR_FAILED, "could not read image " + std::string(file.utf8_str()));
            return wxBitmapBundle();
        }
        return wxBitmapBundle(wxBitmap(img));
    }
    if (!art.empty()) {
        wxBitmapBundle b = wxArtProvider::GetBitmapBundle(art, wxART_TOOLBAR);
        if (!b.IsOk()) {
            *status = wxf_fail(WXF_ERR_ARGUMENT, "unknown art id " + std::string(art.utf8_str()));
            return wxBitmapBundle();
        }
        return b;
    }
    return wxArtProvider::GetBitmapBundle(wxART_MISSING_IMAGE, wxART_TOOLBAR);
}

}   // namespace

// ---------------------------------------------------------------------------
// wxNotebook

WXF_API int wxf_notebook_create(int64_t parent, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxNotebook(p, wxID_ANY));
    return WXF_OK;
    WXF_CATCH
}

// Add window `page` (a child of the notebook) as a tab labeled `text`.
WXF_API int wxf_notebook_add_page(int64_t h, int64_t page, const char *text, int len, int select) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    wxWindow *w = wxf_window(page);
    if (!w) return wxf_fail_handle(page);
    if (w->GetParent() != nb) return wxf_fail(WXF_ERR_ARGUMENT, "a notebook page must be created with the notebook as its parent");
    if (nb->FindPage(w) != wxNOT_FOUND) return wxf_fail(WXF_ERR_STATE, "window is already a page of this notebook");
    if (!nb->AddPage(w, wxf_str(text, len), select != 0)) return wxf_fail(WXF_ERR_FAILED, "wxNotebook::AddPage failed");
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_notebook_page_count(int64_t h, int *n) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    *n = static_cast<int>(nb->GetPageCount());
    return WXF_OK;
    WXF_CATCH
}

#define WXF_PAGE(nb, i)                                                        \
    if ((i) < 1 || (i) > static_cast<int>((nb)->GetPageCount()))              \
    return wxf_fail(WXF_ERR_ARGUMENT, "page index " + std::to_string(i) + " out of range")

WXF_API int wxf_notebook_get_selection(int64_t h, int *i) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    const int sel = nb->GetSelection();
    *i = sel == wxNOT_FOUND ? 0 : sel + 1;
    return WXF_OK;
    WXF_CATCH
}

// Show page i; `notify` != 0 sends the page-changing/changed events.
WXF_API int wxf_notebook_set_selection(int64_t h, int i, int notify) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    WXF_PAGE(nb, i);
    if (notify) nb->SetSelection(i - 1);
    else nb->ChangeSelection(i - 1);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_notebook_get_page(int64_t h, int i, int64_t *page) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    WXF_PAGE(nb, i);
    *page = wxf_handle_of(nb->GetPage(i - 1));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_notebook_get_page_text(int64_t h, int i, char **s, int *len) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    WXF_PAGE(nb, i);
    wxf_out_str(nb->GetPageText(i - 1), s, len);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_notebook_set_page_text(int64_t h, int i, const char *s, int len) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    WXF_PAGE(nb, i);
    nb->SetPageText(i - 1, wxf_str(s, len));
    return WXF_OK;
    WXF_CATCH
}

// Remove page i and destroy its window.
WXF_API int wxf_notebook_delete_page(int64_t h, int i) {
    WXF_TRY
    WXF_GET(wxNotebook, nb, h);
    WXF_PAGE(nb, i);
    if (wxf_dispatching()) {
        // the page may be handling the event being dispatched: remove it now,
        // destroy it from the event loop (see wxf_window_destroy)
        wxWindow *w = nb->GetPage(i - 1);
        nb->RemovePage(i - 1);
        w->Hide();
        wxf_mark_dead(wxf_handle_of(w));
        wxWeakRef<wxWindow> ref(w);
        wxTheApp->CallAfter([ref]() {
            if (ref) ref->Destroy();
        });
    } else {
        nb->DeletePage(i - 1);
    }
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxSplitterWindow

WXF_API int wxf_splitter_create(int64_t parent, int live, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    long style = wxSP_3D;
    if (live) style |= wxSP_LIVE_UPDATE;
    auto *s = new wxSplitterWindow(p, wxID_ANY, wxDefaultPosition, wxDefaultSize, style);
    s->SetMinimumPaneSize(20);   // panes cannot be dragged away entirely (wx default: 0, unsplits)
    *out = wxf_register(s);
    return WXF_OK;
    WXF_CATCH
}

#define WXF_PANE(var, sp, h)                                                   \
    wxWindow *var = wxf_window(h);                                             \
    if (!var) return wxf_fail_handle(h);                                       \
    if (var->GetParent() != (sp))                                              \
    return wxf_fail(WXF_ERR_ARGUMENT, "a splitter pane must be created with the splitter as its parent")

// Split into two panes: side by side (vertical != 0: a vertical sash) or
// one above the other. `pos`: sash position in pixels (0: middle; negative:
// from the right/bottom).
WXF_API int wxf_splitter_split(int64_t h, int64_t first, int64_t second, int vertical, int pos) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    WXF_PANE(a, sp, first);
    WXF_PANE(b, sp, second);
    if (a == b) return wxf_fail(WXF_ERR_ARGUMENT, "the two panes must be different windows");
    if (sp->IsSplit()) sp->Unsplit();
    const bool ok = vertical ? sp->SplitVertically(a, b, pos) : sp->SplitHorizontally(a, b, pos);
    if (!ok) return wxf_fail(WXF_ERR_FAILED, "wxSplitterWindow split failed");
    return WXF_OK;
    WXF_CATCH
}

// Show only `window` (unsplit).
WXF_API int wxf_splitter_initialize(int64_t h, int64_t window) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    WXF_PANE(w, sp, window);
    if (sp->IsSplit()) sp->Unsplit();
    if (sp->GetWindow1() && sp->GetWindow1() != w) sp->GetWindow1()->Hide();
    sp->Initialize(w);
    return WXF_OK;
    WXF_CATCH
}

// Remove pane `which` (1 or 2) from view (it is hidden, not destroyed).
WXF_API int wxf_splitter_unsplit(int64_t h, int which) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    if (which != 1 && which != 2) return wxf_fail(WXF_ERR_ARGUMENT, "pane must be 1 or 2");
    if (!sp->IsSplit()) return WXF_OK;
    sp->Unsplit(which == 1 ? sp->GetWindow1() : sp->GetWindow2());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_splitter_is_split(int64_t h, int *split) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    *split = wxf_bool(sp->IsSplit());
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_splitter_set_sash_position(int64_t h, int pos) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    sp->SetSashPosition(pos);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_splitter_get_sash_position(int64_t h, int *pos) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    *pos = sp->GetSashPosition();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_splitter_set_minimum_pane_size(int64_t h, int size) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    if (size < 0) return wxf_fail(WXF_ERR_ARGUMENT, "minimum pane size must not be negative");
    sp->SetMinimumPaneSize(size);
    return WXF_OK;
    WXF_CATCH
}

// Share of extra space given to the first pane when resized (0..1).
WXF_API int wxf_splitter_set_sash_gravity(int64_t h, double gravity) {
    WXF_TRY
    WXF_GET(wxSplitterWindow, sp, h);
    if (gravity < 0 || gravity > 1) return wxf_fail(WXF_ERR_ARGUMENT, "sash gravity must be in 0..1");
    sp->SetSashGravity(gravity);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// grid, flex grid and static box sizers

WXF_API int wxf_grid_sizer_create(int rows, int cols, int vgap, int hgap, int flex, int64_t *out) {
    WXF_TRY
    WXF_NEED_APP();
    *out = 0;
    if (cols < 0 || rows < 0 || (cols == 0 && rows == 0))
        return wxf_fail(WXF_ERR_ARGUMENT, "a grid sizer needs a positive number of columns (or rows)");
    wxSizer *s = flex ? static_cast<wxSizer *>(new wxFlexGridSizer(rows, cols, vgap, hgap))
                      : static_cast<wxSizer *>(new wxGridSizer(rows, cols, vgap, hgap));
    *out = wxf_register_sizer(s);
    return WXF_OK;
    WXF_CATCH
}

// Row/column i (1-based) of a flex grid sizer takes a share `proportion` of
// extra space. `col` != 0: a column, else a row.
WXF_API int wxf_flex_grid_add_growable(int64_t h, int i, int proportion, int col) {
    WXF_TRY
    WXF_NEED_APP();
    auto *s = dynamic_cast<wxFlexGridSizer *>(wxf_sizer(h));
    if (!s) return wxf_fail_handle(h);
    if (i < 1) return wxf_fail(WXF_ERR_ARGUMENT, "row/column index must be positive");
    if (col) {
        if (s->GetCols() > 0 && i > s->GetCols()) return wxf_fail(WXF_ERR_ARGUMENT, "column index out of range");
        if (!s->IsColGrowable(i - 1)) s->AddGrowableCol(i - 1, proportion);
    } else {
        if (s->GetRows() > 0 && i > s->GetRows()) return wxf_fail(WXF_ERR_ARGUMENT, "row index out of range");
        if (!s->IsRowGrowable(i - 1)) s->AddGrowableRow(i - 1, proportion);
    }
    return WXF_OK;
    WXF_CATCH
}

// A sizer drawing a labeled box around its items; the box is a child window
// of `parent` (`box` gets its handle: create the items inside it).
WXF_API int wxf_static_box_sizer_create(int orient, int64_t parent, const char *label, int len, int64_t *out,
                                        int64_t *box) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = 0;
    *box = 0;
    if (orient != 0 && orient != 1)
        return wxf_fail(WXF_ERR_ARGUMENT, "orientation must be wxHORIZONTAL or wxVERTICAL");
    auto *s = new wxStaticBoxSizer(orient ? wxVERTICAL : wxHORIZONTAL, p, wxf_str(label, len));
    *out = wxf_register_sizer(s);
    *box = wxf_register(s->GetStaticBox());
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// toolbar

// Give frame `h` a toolbar (`text` != 0: labels under the icons).
WXF_API int wxf_frame_create_tool_bar(int64_t h, int text, int64_t *out) {
    WXF_TRY
    WXF_GET(wxFrame, f, h);
    *out = 0;
    if (f->GetToolBar()) return wxf_fail(WXF_ERR_STATE, "frame already has a toolbar");
    long style = wxTB_HORIZONTAL | wxTB_FLAT;
    if (text) style |= wxTB_TEXT;
    wxToolBar *tb = f->CreateToolBar(style);
    if (!tb) return wxf_fail(WXF_ERR_FAILED, "CreateToolBar failed");
    *out = wxf_register(tb);
    return WXF_OK;
    WXF_CATCH
}

// Add a tool: icon from wxArtProvider id `art` (e.g. "wxART_FILE_OPEN") or
// image file `file`; `kind` 0 normal, 1 check (toggle), 2 radio. `id`:
// wxID_ANY for a new id; `out_id` gets the tool's id.
WXF_API int wxf_tool_bar_add_tool(int64_t h, int id, const char *label, int llen, const char *art, int alen,
                                  const char *file, int flen, const char *help, int hlen, int kind, int *out_id) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    *out_id = 0;
    wxItemKind k;
    switch (kind) {
    case 0: k = wxITEM_NORMAL; break;
    case 1: k = wxITEM_CHECK; break;
    case 2: k = wxITEM_RADIO; break;
    default: return wxf_fail(WXF_ERR_ARGUMENT, "tool kind must be normal, check or radio");
    }
    if (id != wxID_ANY && tb->FindById(id)) return wxf_fail(WXF_ERR_ARGUMENT, "toolbar already has a tool with id " + std::to_string(id));
    int status = WXF_OK;
    const wxBitmapBundle bmp = art_or_file(wxf_str(art, alen), wxf_str(file, flen), &status);
    if (status != WXF_OK) return status;
    const int tool_id = id == wxID_ANY ? wxWindow::NewControlId() : id;
    const wxString help_text = wxf_str(help, hlen);
    wxToolBarToolBase *t = tb->AddTool(tool_id, wxf_str(label, llen), bmp, wxBitmapBundle(), k, help_text, help_text);
    if (!t) return wxf_fail(WXF_ERR_FAILED, "wxToolBar::AddTool failed");
    tb->Realize();
    *out_id = t->GetId();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_tool_bar_add_separator(int64_t h, int stretch) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    if (stretch) tb->AddStretchableSpace();
    else tb->AddSeparator();
    tb->Realize();
    return WXF_OK;
    WXF_CATCH
}

// Add control `window` (created with the toolbar as its parent).
WXF_API int wxf_tool_bar_add_control(int64_t h, int64_t window, const char *label, int len) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    wxControl *c = wxf_get<wxControl>(window);
    if (!c) return wxf_fail_handle(window);
    if (c->GetParent() != tb) return wxf_fail(WXF_ERR_ARGUMENT, "a toolbar control must be created with the toolbar as its parent");
    tb->AddControl(c, wxf_str(label, len));
    tb->Realize();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_tool_bar_tool_count(int64_t h, int *n) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    *n = static_cast<int>(tb->GetToolsCount());
    return WXF_OK;
    WXF_CATCH
}

#define WXF_TOOL(t, tb, id)                                                    \
    wxToolBarToolBase *t = (tb)->FindById(id);                                 \
    if (!t) return wxf_fail(WXF_ERR_ARGUMENT, "no tool with id " + std::to_string(id))

WXF_API int wxf_tool_bar_enable_tool(int64_t h, int id, int enable) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    WXF_TOOL(t, tb, id);
    tb->EnableTool(id, enable != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_tool_bar_is_tool_enabled(int64_t h, int id, int *enabled) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    WXF_TOOL(t, tb, id);
    *enabled = wxf_bool(tb->GetToolEnabled(id));
    return WXF_OK;
    WXF_CATCH
}

// Press (or release) a check/radio tool, without an event.
WXF_API int wxf_tool_bar_toggle_tool(int64_t h, int id, int on) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    WXF_TOOL(t, tb, id);
    if (!t->CanBeToggled()) return wxf_fail(WXF_ERR_ARGUMENT, "tool is not a check or radio tool");
    tb->ToggleTool(id, on != 0);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_tool_bar_get_tool_state(int64_t h, int id, int *on) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    WXF_TOOL(t, tb, id);
    if (!t->CanBeToggled()) return wxf_fail(WXF_ERR_ARGUMENT, "tool is not a check or radio tool");
    *on = wxf_bool(tb->GetToolState(id));
    return WXF_OK;
    WXF_CATCH
}

// Click tool `id` as the user would: toggle a check tool (press a radio
// tool), then send wxEVT_TOOL (= wxEVT_MENU) to the toolbar and its frame.
WXF_API int wxf_tool_bar_emit_click(int64_t h, int id) {
    WXF_TRY
    WXF_GET(wxToolBar, tb, h);
    WXF_TOOL(t, tb, id);
    if (!tb->GetToolEnabled(id)) return wxf_fail(WXF_ERR_STATE, "tool is disabled");
    if (t->CanBeToggled())
        tb->ToggleTool(id, t->GetKind() == wxITEM_RADIO ? true : !tb->GetToolState(id));
    wxCommandEvent ev(wxEVT_TOOL, id);
    ev.SetEventObject(tb);
    if (t->CanBeToggled()) ev.SetInt(tb->GetToolState(id) ? 1 : 0);
    tb->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// wxStaticBitmap

WXF_API int wxf_static_bitmap_create(int64_t parent, int64_t *out) {
    WXF_TRY
    WXF_PARENT(p, parent);
    *out = wxf_register(new wxStaticBitmap(p, wxID_ANY, wxBitmapBundle()));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_static_bitmap_load(int64_t h, const char *path, int len) {
    WXF_TRY
    WXF_GET(wxStaticBitmap, b, h);
    wxLogNull no_log_dialog;
    wxImage img;
    if (!img.LoadFile(wxf_str(path, len)))
        return wxf_fail(WXF_ERR_FAILED, "could not read image " + std::string(wxf_str(path, len).utf8_str()));
    b->SetBitmap(wxBitmap(img));
    b->InvalidateBestSize();
    return WXF_OK;
    WXF_CATCH
}

// Show 8-bit RGB data (w*h*3 bytes, row by row from the top-left).
WXF_API int wxf_static_bitmap_set_rgb(int64_t h, const unsigned char *rgb, int w, int ht) {
    WXF_TRY
    WXF_GET(wxStaticBitmap, b, h);
    if (w <= 0 || ht <= 0) return wxf_fail(WXF_ERR_ARGUMENT, "image size must be positive");
    b->SetBitmap(wxBitmap(rgb_image(rgb, w, ht)));
    b->InvalidateBestSize();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_static_bitmap_get_image_size(int64_t h, int *w, int *ht) {
    WXF_TRY
    WXF_GET(wxStaticBitmap, b, h);
    // logical size: on a high-DPI screen the bitmap may have 2x the pixels
    const wxBitmap bmp = b->GetBitmap();
    const wxSize size = bmp.IsOk() ? bmp.GetLogicalSize() : wxSize(0, 0);
    *w = size.GetWidth();
    *ht = size.GetHeight();
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// images on a graphics context

// Draw RGB data (w*h*3 bytes) scaled into the box (x, y, bw, bh); `smooth`
// != 0 interpolates, else nearest-neighbor (crisp pixels, e.g. heatmaps).
WXF_API int wxf_gc_draw_rgb(void *p, const unsigned char *rgb, int w, int ht, double x, double y, double bw,
                            double bh, int smooth) {
    WXF_TRY
    wxGraphicsContext *gc = wxf_live_graphics(p);
    if (!gc) return wxf_fail(WXF_ERR_STATE, "graphics used outside of its paint handler");
    if (w <= 0 || ht <= 0) return wxf_fail(WXF_ERR_ARGUMENT, "image size must be positive");
    const wxInterpolationQuality old = gc->GetInterpolationQuality();
    gc->SetInterpolationQuality(smooth ? wxINTERPOLATION_GOOD : wxINTERPOLATION_NONE);
    gc->DrawBitmap(wxBitmap(rgb_image(rgb, w, ht)), x, y, bw, bh);
    gc->SetInterpolationQuality(old);
    return WXF_OK;
    WXF_CATCH
}

// Draw an image file scaled into the box (x, y, bw, bh); bw, bh <= 0: its own size.
WXF_API int wxf_gc_draw_image_file(void *p, const char *path, int len, double x, double y, double bw, double bh) {
    WXF_TRY
    wxGraphicsContext *gc = wxf_live_graphics(p);
    if (!gc) return wxf_fail(WXF_ERR_STATE, "graphics used outside of its paint handler");
    wxLogNull no_log_dialog;
    wxImage img;
    if (!img.LoadFile(wxf_str(path, len)))
        return wxf_fail(WXF_ERR_FAILED, "could not read image " + std::string(wxf_str(path, len).utf8_str()));
    if (bw <= 0 || bh <= 0) {
        bw = img.GetWidth();
        bh = img.GetHeight();
    }
    gc->DrawBitmap(wxBitmap(img), x, y, bw, bh);
    return WXF_OK;
    WXF_CATCH
}

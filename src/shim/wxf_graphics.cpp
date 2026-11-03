// C ABI shim for drawing: the canvas window, rendering to PNG, synthetic
// mouse/key events, image loading, and wxGraphicsContext operations.
//
// Graphics contexts are borrowed: Fortran gets one in a WXF_EVT_PAINT handler
// and every operation checks that it belongs to a draw event being
// dispatched, so a context kept past its handler fails cleanly.

#include "wxf_graphics.h"

#include <wx/dcmemory.h>
#include <wx/image.h>

#include <cstdlib>
#include <cstring>
#include <memory>
#include <vector>

wxDEFINE_EVENT(wxfEVT_DRAW, wxfDrawEvent);

// Key codes: must match the WXK_* parameters in src/c/wx_c_core.f90.
static_assert(WXK_BACK == 8 && WXK_TAB == 9 && WXK_RETURN == 13 && WXK_ESCAPE == 27 &&
                  WXK_SPACE == 32 && WXK_DELETE == 127 && WXK_END == 312 && WXK_HOME == 313 &&
                  WXK_LEFT == 314 && WXK_UP == 315 && WXK_RIGHT == 316 && WXK_DOWN == 317 &&
                  WXK_F1 == 340 && WXK_PAGEUP == 366 && WXK_PAGEDOWN == 367,
              "wxWidgets key codes changed: update src/c/wx_c_core.f90");

// Pen styles and font families: must match src/c/wx_c_graphics.f90.
enum { WXF_PEN_SOLID = 0, WXF_PEN_DOT = 1, WXF_PEN_LONG_DASH = 2, WXF_PEN_SHORT_DASH = 3 };
enum { WXF_FONT_DEFAULT = 0, WXF_FONT_SANS = 1, WXF_FONT_SERIF = 2, WXF_FONT_MONO = 3 };

// ---------------------------------------------------------------------------
// canvas

wxfCanvas::wxfCanvas(wxWindow *parent)
    : wxWindow(parent, wxID_ANY, wxDefaultPosition, wxDefaultSize,
               wxFULL_REPAINT_ON_RESIZE | wxWANTS_CHARS) {
    SetBackgroundStyle(wxBG_STYLE_PAINT);   // all painting is done in OnPaint
    SetBackgroundColour(*wxWHITE);
    Bind(wxEVT_PAINT, &wxfCanvas::OnPaint, this);
}

void wxfCanvas::Draw(wxGraphicsContext *gc, double w, double h) {
    wxfDrawEvent ev(wxfEVT_DRAW, GetId());
    ev.SetEventObject(this);
    ev.gc = gc;
    ev.width = w;
    ev.height = h;
    ProcessWindowEvent(ev);
}

void wxfCanvas::OnPaint(wxPaintEvent &) {
    wxPaintDC dc(this);   // required in every paint handler
    dc.SetBackground(wxBrush(GetBackgroundColour()));
    dc.Clear();
    std::unique_ptr<wxGraphicsContext> gc(wxGraphicsContext::Create(dc));
    if (!gc) return;
    int w = 0, h = 0;
    GetClientSize(&w, &h);
    Draw(gc.get(), w, h);
}

WXF_API int wxf_canvas_create(int64_t parent, int64_t *out) {
    WXF_TRY
    WXF_NEED_APP();
    *out = 0;
    wxWindow *p = wxf_window(parent);
    if (!p) return wxf_fail_handle(parent);
    *out = wxf_register(new wxfCanvas(p));
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// PNG output

int wxf_save_png(const wxBitmap &bitmap, const wxString &path) {
    if (!bitmap.IsOk()) return wxf_fail(WXF_ERR_FAILED, "could not create the bitmap");
    wxLogNull no_log_dialog;   // report failure through the status instead
    if (!bitmap.SaveFile(path, wxBITMAP_TYPE_PNG))
        return wxf_fail(WXF_ERR_FAILED, "could not write PNG file " + std::string(path.utf8_str()));
    return WXF_OK;
}

namespace {
// Render with `draw(gc, w, h)` into a w x h bitmap filled with `bg`; save as PNG.
template <class F> int render_to_png(int w, int h, const wxColour &bg, const wxString &path, F draw) {
    if (w <= 0 || h <= 0) return wxf_fail(WXF_ERR_ARGUMENT, "image size must be positive");
    wxBitmap bmp(w, h, 24);
    if (!bmp.IsOk()) return wxf_fail(WXF_ERR_FAILED, "could not create the bitmap");
    {
        wxMemoryDC dc(bmp);
        dc.SetBackground(wxBrush(bg));
        dc.Clear();
        std::unique_ptr<wxGraphicsContext> gc(wxGraphicsContext::Create(dc));
        if (!gc) return wxf_fail(WXF_ERR_FAILED, "could not create a graphics context");
        draw(gc.get(), static_cast<double>(w), static_cast<double>(h));
    }   // the context and DC are released before saving
    return wxf_save_png(bmp, path);
}
}   // namespace

// Draw the canvas (with its paint handlers) into a PNG file of its size.
WXF_API int wxf_canvas_save_png(int64_t h, const char *path, int len) {
    WXF_TRY
    WXF_GET(wxfCanvas, c, h);
    int w = 0, ht = 0;
    c->GetClientSize(&w, &ht);
    return render_to_png(w, ht, c->GetBackgroundColour(), wxf_str(path, len),
                         [c](wxGraphicsContext *gc, double cw, double ch) { c->Draw(gc, cw, ch); });
    WXF_CATCH
}

// Draw with Fortran slot `slot` (called once) into a new PNG file.
WXF_API int wxf_render_png(int w, int h, int r, int g, int b, int a, const char *path, int len,
                           int slot) {
    WXF_TRY
    WXF_NEED_APP();
    return render_to_png(w, h, wxf_color(r, g, b, a), wxf_str(path, len),
                         [slot](wxGraphicsContext *gc, double cw, double ch) {
                             wxfDrawEvent ev(wxfEVT_DRAW, wxID_ANY);
                             ev.gc = gc;
                             ev.width = cw;
                             ev.height = ch;
                             wxf_dispatch_draw(slot, ev);
                         });
    WXF_CATCH
}

// Read a PNG (or other supported image) as 8-bit RGB: `rgb` gets a malloc'd
// array of w*h*3 bytes, row by row from the top-left.
WXF_API int wxf_image_read_rgb(const char *path, int len, int *w, int *h, unsigned char **rgb) {
    WXF_TRY
    WXF_NEED_APP();
    *w = *h = 0;
    *rgb = nullptr;
    wxLogNull no_log_dialog;
    wxImage img;
    if (!img.LoadFile(wxf_str(path, len)))
        return wxf_fail(WXF_ERR_FAILED, "could not read image " + std::string(wxf_str(path, len).utf8_str()));
    *w = img.GetWidth();
    *h = img.GetHeight();
    const size_t n = static_cast<size_t>(*w) * static_cast<size_t>(*h) * 3;
    *rgb = static_cast<unsigned char *>(std::malloc(n > 0 ? n : 1));
    std::memcpy(*rgb, img.GetData(), n);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// synthetic input (tests and automation)

// Send a mouse event of `kind` (WXF_EVT_LEFT_DOWN, ...) at (x, y) to window
// `h`; `wheel` is the rotation in notches (wheel events), `mods` WXF_MOD_* bits.
WXF_API int wxf_window_emit_mouse(int64_t h, int kind, int x, int y, double wheel, int mods) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxEventType type;
    switch (kind) {
    case WXF_EVT_LEFT_DOWN: type = wxEVT_LEFT_DOWN; break;
    case WXF_EVT_LEFT_UP: type = wxEVT_LEFT_UP; break;
    case WXF_EVT_RIGHT_DOWN: type = wxEVT_RIGHT_DOWN; break;
    case WXF_EVT_MOTION: type = wxEVT_MOTION; break;
    case WXF_EVT_MOUSEWHEEL: type = wxEVT_MOUSEWHEEL; break;
    case WXF_EVT_LEFT_DCLICK: type = wxEVT_LEFT_DCLICK; break;
    case WXF_EVT_LEAVE_WINDOW: type = wxEVT_LEAVE_WINDOW; break;
    default: return wxf_fail(WXF_ERR_ARGUMENT, "not a mouse event kind");
    }
    wxMouseEvent ev(type);
    ev.SetEventObject(w);
    ev.SetId(w->GetId());
    ev.SetX(x);
    ev.SetY(y);
    ev.SetShiftDown((mods & WXF_MOD_SHIFT) != 0);
    ev.SetControlDown((mods & WXF_MOD_CONTROL) != 0);
    ev.SetAltDown((mods & WXF_MOD_ALT) != 0);
    ev.SetLeftDown(kind == WXF_EVT_LEFT_DOWN || kind == WXF_EVT_LEFT_DCLICK);
    if (kind == WXF_EVT_MOUSEWHEEL) {
        ev.m_wheelAxis = wxMOUSE_WHEEL_VERTICAL;
        ev.m_wheelDelta = 120;
        ev.m_wheelRotation = static_cast<int>(wheel * 120);
        ev.m_linesPerAction = 3;
    }
    w->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// Send a key-down event with key `code` (and Unicode character `unicode`).
WXF_API int wxf_window_emit_key(int64_t h, int code, int unicode, int mods) {
    WXF_TRY
    WXF_GET(wxWindow, w, h);
    wxKeyEvent ev(wxEVT_KEY_DOWN);
    ev.SetEventObject(w);
    ev.SetId(w->GetId());
    ev.m_keyCode = code;
    ev.m_uniChar = static_cast<wxChar>(unicode);
    ev.SetShiftDown((mods & WXF_MOD_SHIFT) != 0);
    ev.SetControlDown((mods & WXF_MOD_CONTROL) != 0);
    ev.SetAltDown((mods & WXF_MOD_ALT) != 0);
    w->HandleWindowEvent(ev);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// graphics context

#define WXF_GC(var, p)                                                         \
    wxGraphicsContext *var = wxf_live_graphics(p);                             \
    if (!var) return wxf_fail(WXF_ERR_STATE, "graphics used outside of its paint handler")

namespace {
std::vector<wxPoint2DDouble> points(const double *x, const double *y, int n) {
    std::vector<wxPoint2DDouble> p(static_cast<size_t>(n > 0 ? n : 0));
    for (int i = 0; i < n; ++i) p[i] = wxPoint2DDouble(x[i], y[i]);
    return p;
}
}   // namespace

// Outline pen: color, width in pixels, style (WXF_PEN_*); width <= 0: no pen.
WXF_API int wxf_gc_set_pen(void *p, int r, int g, int b, int a, double width, int style) {
    WXF_TRY
    WXF_GC(gc, p);
    if (width <= 0) {
        gc->SetPen(*wxTRANSPARENT_PEN);
        return WXF_OK;
    }
    wxPenStyle st;
    switch (style) {
    case WXF_PEN_SOLID: st = wxPENSTYLE_SOLID; break;
    case WXF_PEN_DOT: st = wxPENSTYLE_DOT; break;
    case WXF_PEN_LONG_DASH: st = wxPENSTYLE_LONG_DASH; break;
    case WXF_PEN_SHORT_DASH: st = wxPENSTYLE_SHORT_DASH; break;
    default: return wxf_fail(WXF_ERR_ARGUMENT, "unknown pen style");
    }
    gc->SetPen(gc->CreatePen(wxGraphicsPenInfo(wxf_color(r, g, b, a)).Width(width).Style(st)));
    return WXF_OK;
    WXF_CATCH
}

// Fill brush: color; `none` != 0: no fill.
WXF_API int wxf_gc_set_brush(void *p, int r, int g, int b, int a, int none) {
    WXF_TRY
    WXF_GC(gc, p);
    if (none) gc->SetBrush(*wxTRANSPARENT_BRUSH);
    else gc->SetBrush(wxBrush(wxf_color(r, g, b, a)));
    return WXF_OK;
    WXF_CATCH
}

// Text font: size in points, family (WXF_FONT_*), bold/italic, and color.
WXF_API int wxf_gc_set_font(void *p, double size, int family, int bold, int italic, int r, int g,
                            int b, int a) {
    WXF_TRY
    WXF_GC(gc, p);
    if (size <= 0) return wxf_fail(WXF_ERR_ARGUMENT, "font size must be positive");
    wxFontFamily fam;
    switch (family) {
    case WXF_FONT_DEFAULT: fam = wxFONTFAMILY_DEFAULT; break;
    case WXF_FONT_SANS: fam = wxFONTFAMILY_SWISS; break;
    case WXF_FONT_SERIF: fam = wxFONTFAMILY_ROMAN; break;
    case WXF_FONT_MONO: fam = wxFONTFAMILY_TELETYPE; break;
    default: return wxf_fail(WXF_ERR_ARGUMENT, "unknown font family");
    }
    wxFont font(wxFontInfo(size).Family(fam).Bold(bold != 0).Italic(italic != 0));
    gc->SetFont(font, wxf_color(r, g, b, a));
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gc_stroke_line(void *p, double x1, double y1, double x2, double y2) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->StrokeLine(x1, y1, x2, y2);
    return WXF_OK;
    WXF_CATCH
}

// A polyline through n points.
WXF_API int wxf_gc_stroke_lines(void *p, const double *x, const double *y, int n) {
    WXF_TRY
    WXF_GC(gc, p);
    if (n < 2) return WXF_OK;
    const auto pts = points(x, y, n);
    gc->StrokeLines(pts.size(), pts.data());
    return WXF_OK;
    WXF_CATCH
}

// A closed polygon, filled with the brush and outlined with the pen.
WXF_API int wxf_gc_draw_polygon(void *p, const double *x, const double *y, int n) {
    WXF_TRY
    WXF_GC(gc, p);
    if (n < 3) return wxf_fail(WXF_ERR_ARGUMENT, "a polygon needs at least 3 points");
    const auto pts = points(x, y, n);
    gc->DrawLines(pts.size(), pts.data());
    return WXF_OK;
    WXF_CATCH
}

// Rectangle (radius > 0: rounded corners), filled and outlined.
WXF_API int wxf_gc_draw_rectangle(void *p, double x, double y, double w, double h, double radius) {
    WXF_TRY
    WXF_GC(gc, p);
    if (radius > 0) gc->DrawRoundedRectangle(x, y, w, h, radius);
    else gc->DrawRectangle(x, y, w, h);
    return WXF_OK;
    WXF_CATCH
}

// Ellipse in the box (x, y, w, h), filled and outlined.
WXF_API int wxf_gc_draw_ellipse(void *p, double x, double y, double w, double h) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->DrawEllipse(x, y, w, h);
    return WXF_OK;
    WXF_CATCH
}

// Text with its top-left corner at (x, y), rotated by `angle` radians
// (counter-clockwise).
WXF_API int wxf_gc_draw_text(void *p, const char *s, int len, double x, double y, double angle) {
    WXF_TRY
    WXF_GC(gc, p);
    if (angle != 0) {
        // rotate about (x, y) explicitly: DrawText's own angle is ignored by
        // some backends. Rotate() is clockwise on screen (y points down).
        gc->PushState();
        gc->Translate(x, y);
        gc->Rotate(-angle);
        gc->DrawText(wxf_str(s, len), 0, 0);
        gc->PopState();
    } else {
        gc->DrawText(wxf_str(s, len), x, y);
    }
    return WXF_OK;
    WXF_CATCH
}

// Size of `s` in the current font.
WXF_API int wxf_gc_get_text_extent(void *p, const char *s, int len, double *w, double *h) {
    WXF_TRY
    WXF_GC(gc, p);
    double descent = 0, leading = 0;
    gc->GetTextExtent(wxf_str(s, len), w, h, &descent, &leading);
    return WXF_OK;
    WXF_CATCH
}

// Restrict drawing to a rectangle (until reset_clip or pop_state).
WXF_API int wxf_gc_clip(void *p, double x, double y, double w, double h) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->Clip(x, y, w, h);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gc_reset_clip(void *p) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->ResetClip();
    return WXF_OK;
    WXF_CATCH
}

// Save / restore the pen, brush, font, clip and transformation.
WXF_API int wxf_gc_push_state(void *p) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->PushState();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gc_pop_state(void *p) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->PopState();
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gc_translate(void *p, double dx, double dy) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->Translate(dx, dy);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gc_scale(void *p, double sx, double sy) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->Scale(sx, sy);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_gc_rotate(void *p, double angle) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->Rotate(angle);
    return WXF_OK;
    WXF_CATCH
}

// Anti-aliasing on (default) or off.
WXF_API int wxf_gc_set_antialias(void *p, int on) {
    WXF_TRY
    WXF_GC(gc, p);
    gc->SetAntialiasMode(on ? wxANTIALIAS_DEFAULT : wxANTIALIAS_NONE);
    return WXF_OK;
    WXF_CATCH
}

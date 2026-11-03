// Drawing: the canvas window and the draw event that carries a graphics
// context to Fortran (shared by wxf_core.cpp and wxf_graphics.cpp).
#pragma once

#include "wxf_common.h"

#include <wx/graphics.h>

// Sent to a canvas's WXF_EVT_PAINT handlers with the graphics context to draw
// on: the window's (when it is painted) or a bitmap's (when it is saved, or
// for wxf_render_png). The context is valid only during the event.
class wxfDrawEvent : public wxEvent {
public:
    wxfDrawEvent(wxEventType type = wxEVT_NULL, int id = 0) : wxEvent(id, type) {}
    wxEvent *Clone() const override { return new wxfDrawEvent(*this); }
    wxGraphicsContext *gc = nullptr;
    double width = 0, height = 0;   // drawing area, in pixels
};

wxDECLARE_EVENT(wxfEVT_DRAW, wxfDrawEvent);

// A window that is painted by Fortran (WXF_EVT_PAINT handlers).
class wxfCanvas : public wxWindow {
public:
    explicit wxfCanvas(wxWindow *parent);
    // Draw with every bound WXF_EVT_PAINT handler on `gc` (w x h pixels).
    void Draw(wxGraphicsContext *gc, double w, double h);

private:
    void OnPaint(wxPaintEvent &);
};

// The graphics context `gc` if it belongs to a draw event being dispatched
// now (`ev` gets that event), else null.
wxGraphicsContext *wxf_live_graphics(void *gc, wxfDrawEvent **ev = nullptr);

// Dispatch a draw event directly to Fortran slot `slot` (offscreen rendering).
void wxf_dispatch_draw(int slot, wxfDrawEvent &ev);

// Saves `bitmap` as PNG at `path`; returns a status.
int wxf_save_png(const wxBitmap &bitmap, const wxString &path);

// wxColour from 0-255 components.
inline wxColour wxf_color(int r, int g, int b, int a) {
    auto c = [](int v) { return static_cast<unsigned char>(v < 0 ? 0 : (v > 255 ? 255 : v)); };
    return wxColour(c(r), c(g), c(b), c(a));
}

// C ABI shim over the standard modal dialogs: message box, file and directory
// pickers, text entry, single choice, color picker, about box.
//
// Scripted answers (for tests and automation): wxf_dialog_queue_answer adds
// an answer; the next dialog takes the oldest one and returns it without
// being shown. In test mode, a dialog with no queued answer fails with
// WXF_ERR_STATE instead of blocking on user input. Every dialog (shown or
// scripted) records its kind, caption and message for wxf_dialog_last.

#include "wxf_common.h"

#include <wx/aboutdlg.h>
#include <wx/choicdlg.h>
#include <wx/colordlg.h>
#include <wx/dirdlg.h>
#include <wx/filedlg.h>
#include <wx/msgdlg.h>
#include <wx/textdlg.h>

#include <deque>
#include <string>
#include <vector>

// Styles and button ids: must match the parameters in src/c/wx_c_dialogs.f90.
static_assert(wxOK == 4 && wxCANCEL == 16 && wxYES == 2 && wxNO == 8 && wxYES_NO == 10 &&
                  wxICON_WARNING == 256 && wxICON_ERROR == 512 && wxICON_QUESTION == 1024 &&
                  wxICON_INFORMATION == 2048 && wxID_OK == 5100 && wxID_CANCEL == 5101 &&
                  wxID_YES == 5103 && wxID_NO == 5104,
              "wxWidgets dialog constants changed: update src/c/wx_c_dialogs.f90");

namespace {

struct answer {
    int button = 0;                   // wxID_*; 0: the default (affirmative) one
    bool has_text = false;
    std::string text;
    std::vector<std::string> paths;
    int index = 0;                    // 1-based choice
    bool has_color = false;
    int r = 0, g = 0, b = 0, a = 255;
};

std::deque<answer> &answers() {
    static auto *q = new std::deque<answer>;
    return *q;
}

bool test_mode = false;
std::string last_kind, last_caption, last_message;

enum class take { show, scripted, failed };

// Record the dialog; take the next scripted answer if there is one.
take next_answer(const char *kind, const wxString &caption, const wxString &message, answer &a,
                 int *status) {
    last_kind = kind;
    last_caption = caption.utf8_str().data();
    last_message = message.utf8_str().data();
    if (!answers().empty()) {
        a = answers().front();
        answers().pop_front();
        return take::scripted;
    }
    if (test_mode) {
        *status = wxf_fail(WXF_ERR_STATE, std::string("no queued answer for the ") + kind +
                                              " dialog (dialog test mode is on)");
        return take::failed;
    }
    return take::show;
}

bool cancelled(const answer &a) { return a.button == wxID_CANCEL || a.button == wxID_NO; }

wxWindow *parent_of(int64_t h) { return h ? wxf_window(h) : nullptr; }

}   // namespace

#define WXF_PARENT_OPT(var, h)                                                 \
    WXF_NEED_APP();                                                            \
    wxWindow *var = parent_of(h);                                              \
    if (h != 0 && !var) return wxf_fail_handle(h)

// ---------------------------------------------------------------------------
// scripted answers

WXF_API int wxf_dialog_queue_answer(int button, const char *text, int tlen, int has_text,
                                    const char *paths, int itemlen, int npaths, int index,
                                    int has_color, int r, int g, int b, int a) {
    WXF_TRY
    answer ans;
    ans.button = button;
    ans.has_text = has_text != 0;
    if (ans.has_text) ans.text.assign(text, static_cast<size_t>(tlen > 0 ? tlen : 0));
    for (const wxString &p : wxf_strings(paths, itemlen, npaths)) ans.paths.push_back(p.utf8_str().data());
    ans.index = index;
    ans.has_color = has_color != 0;
    ans.r = r;
    ans.g = g;
    ans.b = b;
    ans.a = a;
    answers().push_back(ans);
    return WXF_OK;
    WXF_CATCH
}

WXF_API int wxf_dialog_clear_answers() {
    answers().clear();
    return WXF_OK;
}

WXF_API int wxf_dialog_queued_answers() { return static_cast<int>(answers().size()); }

WXF_API int wxf_dialog_set_test_mode(int on) {
    test_mode = on != 0;
    return WXF_OK;
}

// The last dialog's kind (which = 1), caption (2) or message (3).
WXF_API int wxf_dialog_last(int which, char **s, int *len) {
    WXF_TRY
    const std::string &v = which == 1 ? last_kind : (which == 2 ? last_caption : last_message);
    wxf_out_str(wxString::FromUTF8(v.c_str()), s, len);
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// message box

// `style`: wxOK, wxOK|wxCANCEL, wxYES_NO or wxYES_NO|wxCANCEL, plus an icon
// flag. `button` gets wxID_OK, wxID_CANCEL, wxID_YES or wxID_NO.
WXF_API int wxf_message_box(int64_t parent, const char *msg, int mlen, const char *cap, int clen,
                            int style, int *button) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    *button = wxID_CANCEL;
    if (!(style & (wxOK | wxYES_NO))) style |= wxOK;
    if ((style & wxOK) && (style & wxYES_NO))
        return wxf_fail(WXF_ERR_ARGUMENT, "message box style cannot have both wxOK and wxYES_NO");
    const wxString message = wxf_str(msg, mlen), caption = wxf_str(cap, clen);
    answer a;
    int status = WXF_OK;
    switch (next_answer("message", caption, message, a, &status)) {
    case take::failed: return status;
    case take::scripted: {
        int b = a.button ? a.button : ((style & wxOK) ? wxID_OK : wxID_YES);
        const bool offered = (b == wxID_OK && (style & wxOK)) || (b == wxID_CANCEL && (style & wxCANCEL)) ||
                             ((b == wxID_YES || b == wxID_NO) && (style & wxYES_NO));
        if (!offered) return wxf_fail(WXF_ERR_ARGUMENT, "queued answer is not a button of this message box");
        *button = b;
        return WXF_OK;
    }
    case take::show: break;
    }
    wxMessageDialog dlg(p, message, caption, style);
    *button = dlg.ShowModal();
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// file and directory dialogs

// mode: 0 open one file, 1 open several, 2 save. flags: 1 the file must exist
// (open), 2 confirm overwriting (save). `ok` is 0 if cancelled; `paths` gets
// the chosen path(s) as NUL-terminated strings.
WXF_API int wxf_file_dialog(int64_t parent, int mode, const char *msg, int mlen, const char *dir, int dlen,
                            const char *file, int flen, const char *wild, int wlen, int flags, int *ok,
                            char **paths, int *plen) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    *ok = 0;
    wxf_out_strings(wxArrayString(), paths, plen);
    if (mode < 0 || mode > 2) return wxf_fail(WXF_ERR_ARGUMENT, "unknown file dialog mode");
    const wxString message = wxf_str(msg, mlen);
    answer a;
    int status = WXF_OK;
    switch (next_answer(mode == 2 ? "file save" : "file open", message, message, a, &status)) {
    case take::failed: return status;
    case take::scripted: {
        if (cancelled(a)) return WXF_OK;
        if (a.paths.empty()) return wxf_fail(WXF_ERR_ARGUMENT, "queued answer for a file dialog has no path");
        if (mode != 1 && a.paths.size() > 1)
            return wxf_fail(WXF_ERR_ARGUMENT, "queued answer has several paths for a single-file dialog");
        wxArrayString list;
        for (const std::string &s : a.paths) list.Add(wxString::FromUTF8(s.c_str()));
        std::free(*paths);
        wxf_out_strings(list, paths, plen);
        *ok = 1;
        return WXF_OK;
    }
    case take::show: break;
    }
    long style = mode == 2 ? wxFD_SAVE : wxFD_OPEN;
    if (mode == 1) style |= wxFD_MULTIPLE;
    if (mode != 2 && (flags & 1)) style |= wxFD_FILE_MUST_EXIST;
    if (mode == 2 && (flags & 2)) style |= wxFD_OVERWRITE_PROMPT;
    const wxString wildcard = wlen > 0 ? wxf_str(wild, wlen) : wxString(wxFileSelectorDefaultWildcardStr);
    wxFileDialog dlg(p, message, wxf_str(dir, dlen), wxf_str(file, flen), wildcard, style);
    if (dlg.ShowModal() != wxID_OK) return WXF_OK;
    wxArrayString list;
    if (mode == 1) dlg.GetPaths(list);
    else list.Add(dlg.GetPath());
    std::free(*paths);
    wxf_out_strings(list, paths, plen);
    *ok = 1;
    return WXF_OK;
    WXF_CATCH
}

// Choose a directory. flags: 1 it must exist.
WXF_API int wxf_dir_dialog(int64_t parent, const char *msg, int mlen, const char *dir, int dlen, int flags,
                           int *ok, char **path, int *plen) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    *ok = 0;
    wxf_out_str(wxString(), path, plen);
    const wxString message = wxf_str(msg, mlen);
    answer a;
    int status = WXF_OK;
    switch (next_answer("directory", message, message, a, &status)) {
    case take::failed: return status;
    case take::scripted:
        if (cancelled(a)) return WXF_OK;
        if (a.paths.size() != 1) return wxf_fail(WXF_ERR_ARGUMENT, "queued answer for a directory dialog needs one path");
        std::free(*path);
        wxf_out_str(wxString::FromUTF8(a.paths[0].c_str()), path, plen);
        *ok = 1;
        return WXF_OK;
    case take::show: break;
    }
    wxDirDialog dlg(p, message, wxf_str(dir, dlen), wxDD_DEFAULT_STYLE | ((flags & 1) ? wxDD_DIR_MUST_EXIST : 0));
    if (dlg.ShowModal() != wxID_OK) return WXF_OK;
    std::free(*path);
    wxf_out_str(dlg.GetPath(), path, plen);
    *ok = 1;
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// text entry and single choice

WXF_API int wxf_text_entry_dialog(int64_t parent, const char *msg, int mlen, const char *cap, int clen,
                                  const char *value, int vlen, int password, int *ok, char **out, int *olen) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    *ok = 0;
    wxf_out_str(wxString(), out, olen);
    const wxString message = wxf_str(msg, mlen), caption = wxf_str(cap, clen);
    answer a;
    int status = WXF_OK;
    switch (next_answer("text entry", caption, message, a, &status)) {
    case take::failed: return status;
    case take::scripted:
        if (cancelled(a)) return WXF_OK;
        if (!a.has_text) return wxf_fail(WXF_ERR_ARGUMENT, "queued answer for a text entry dialog has no text");
        std::free(*out);
        wxf_out_str(wxString::FromUTF8(a.text.c_str()), out, olen);
        *ok = 1;
        return WXF_OK;
    case take::show: break;
    }
    const long style = wxTextEntryDialogStyle | (password ? wxTE_PASSWORD : 0);
    wxTextEntryDialog dlg(p, message, caption, wxf_str(value, vlen), style);
    if (dlg.ShowModal() != wxID_OK) return WXF_OK;
    std::free(*out);
    wxf_out_str(dlg.GetValue(), out, olen);
    *ok = 1;
    return WXF_OK;
    WXF_CATCH
}

// Choose one of n items; `initial` and `index` are 1-based.
WXF_API int wxf_choice_dialog(int64_t parent, const char *msg, int mlen, const char *cap, int clen,
                              const char *items, int itemlen, int n, int initial, int *ok, int *index) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    *ok = 0;
    *index = 0;
    if (n < 1) return wxf_fail(WXF_ERR_ARGUMENT, "a choice dialog needs at least one item");
    const wxString message = wxf_str(msg, mlen), caption = wxf_str(cap, clen);
    answer a;
    int status = WXF_OK;
    switch (next_answer("choice", caption, message, a, &status)) {
    case take::failed: return status;
    case take::scripted:
        if (cancelled(a)) return WXF_OK;
        if (a.index < 1 || a.index > n)
            return wxf_fail(WXF_ERR_ARGUMENT, "queued answer for a choice dialog needs an index in 1..n");
        *index = a.index;
        *ok = 1;
        return WXF_OK;
    case take::show: break;
    }
    wxSingleChoiceDialog dlg(p, message, caption, wxf_strings(items, itemlen, n));
    if (initial >= 1 && initial <= n) dlg.SetSelection(initial - 1);
    if (dlg.ShowModal() != wxID_OK) return WXF_OK;
    *index = dlg.GetSelection() + 1;
    *ok = 1;
    return WXF_OK;
    WXF_CATCH
}

// ---------------------------------------------------------------------------
// color picker and about box

WXF_API int wxf_color_dialog(int64_t parent, int r, int g, int b, int a, int *ok, int *ro, int *go, int *bo,
                             int *ao) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    *ok = 0;
    *ro = r;
    *go = g;
    *bo = b;
    *ao = a;
    answer ans;
    int status = WXF_OK;
    switch (next_answer("color", wxString(), wxString(), ans, &status)) {
    case take::failed: return status;
    case take::scripted:
        if (cancelled(ans)) return WXF_OK;
        if (!ans.has_color) return wxf_fail(WXF_ERR_ARGUMENT, "queued answer for a color dialog has no color");
        *ro = ans.r;
        *go = ans.g;
        *bo = ans.b;
        *ao = ans.a;
        *ok = 1;
        return WXF_OK;
    case take::show: break;
    }
    wxColourData data;
    data.SetChooseFull(true);
    data.SetColour(wxColour(static_cast<unsigned char>(r), static_cast<unsigned char>(g),
                            static_cast<unsigned char>(b), static_cast<unsigned char>(a)));
    wxColourDialog dlg(p, &data);
    if (dlg.ShowModal() != wxID_OK) return WXF_OK;
    const wxColour c = dlg.GetColourData().GetColour();
    *ro = c.Red();
    *go = c.Green();
    *bo = c.Blue();
    *ao = c.Alpha();
    *ok = 1;
    return WXF_OK;
    WXF_CATCH
}

// The standard "About" box (fields may be empty).
WXF_API int wxf_about_box(int64_t parent, const char *name, int nlen, const char *version, int vlen,
                          const char *desc, int dlen, const char *copyright, int clen, const char *web,
                          int wlen) {
    WXF_TRY
    WXF_PARENT_OPT(p, parent);
    const wxString title = wxf_str(name, nlen);
    answer a;
    int status = WXF_OK;
    switch (next_answer("about", title, wxf_str(desc, dlen), a, &status)) {
    case take::failed: return status;
    case take::scripted: return WXF_OK;
    case take::show: break;
    }
    wxAboutDialogInfo info;
    if (nlen > 0) info.SetName(title);
    if (vlen > 0) info.SetVersion(wxf_str(version, vlen));
    if (dlen > 0) info.SetDescription(wxf_str(desc, dlen));
    if (clen > 0) info.SetCopyright(wxf_str(copyright, clen));
    if (wlen > 0) info.SetWebSite(wxf_str(web, wlen));
    wxAboutBox(info, p);
    return WXF_OK;
    WXF_CATCH
}

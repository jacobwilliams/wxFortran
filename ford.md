---
project: wxFortran
summary: Modern Fortran bindings for wxWidgets
project_github: https://github.com/jacobwilliams/wxFortran
author: Jacob Williams
github: https://github.com/jacobwilliams
predocmark_alt: >
predocmark: <
docmark_alt:
docmark: !
license: MIT
src_dir: ./src
output_dir: ./doc
media_dir: ./media
display: public
         protected
         private
source: true
graph: true
sort: alpha
search: true
---

Modern Fortran bindings for [wxWidgets](https://www.wxwidgets.org): native
desktop GUIs from Fortran, through derived types and type-bound procedures.

![The Mandelbrot example](|media|/mandelbrot.png)

Start with the umbrella module [[wx]] (`use wx`). The main modules are:

* [[wx_base]]: errors (`stat` arguments, `wx_last_error`), handles and lifetime
* [[wx_events]]: event handlers, `bind`, connections, deferred calls
* [[wx_app_mod]]: the application and its event loop
* [[wx_windows]] and [[wx_controls]]: windows, sizers, frames and basic controls
* [[wx_lists]], [[wx_values]] and [[wx_layout]]: more controls, containers, toolbars
* [[wx_menus]], [[wx_dialogs]] and [[wx_timers]]
* [[wx_canvas_mod]], [[wx_graphics_mod]] and [[wx_colors]]: drawing

See the [README](https://github.com/jacobwilliams/wxFortran#readme) for
building, the design contracts, and the examples.

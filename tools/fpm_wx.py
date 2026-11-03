"""Run fpm with the C++ compiler, wxWidgets and linker settings wxFortran needs.

Works in wxFortran itself and in any fpm project that depends on it (run it
from that project's root, e.g. `python build/dependencies/wxfortran/tools/fpm_wx.py build`).

Usage:
    python fpm_wx.py <fpm command> [fpm args...]   e.g. build, test, run --example hello
    python fpm_wx.py --env                         print `export ...` lines; then plain
                                                   `fpm build` works in that shell

Option (anywhere after the fpm command):
    --openmp    compile and link with OpenMP (-fopenmp). Without an explicit
                --profile this also selects `--profile release`: fpm drops
                its default flags when --flag is given without a profile.
                Code using OpenMP only through `!$` lines runs serially
                without this option.

fpm compiles the C++ shim (src/cpp/*.cpp) as part of the wxFortran library.
This script supplies the machine-specific settings through fpm's standard
environment variables, from `wx-config`:
    FPM_CXX       clang++ (macOS) / g++
    FPM_CXXFLAGS  -std=c++17 -fPIC + `wx-config --cxxflags`
    FPM_LDFLAGS   `wx-config --libs core,base` + rpath to the wxWidgets libraries

Override the compilers with FPM_FC / FPM_CXX, and the wx-config program with
WX_CONFIG (e.g. for a system or custom wxWidgets build). FPM_CXXFLAGS and
FPM_LDFLAGS already set in the environment are kept (appended).

On Linux, `test` and `run` also build the gdk-pixbuf loader cache into
build/ and point GTK at it (GDK_PIXBUF_MODULE_FILE): conda packages register
their image loaders (e.g. librsvg's, for SVG theme icons such as radio
button bullets) with install scripts, which pixi does not run.

On Linux without a display (e.g. CI), `test` runs under `xvfb-run` if it is
installed (with NO_AT_BRIDGE=1: there is no accessibility bus to connect
to); set WXF_NO_XVFB=1 to disable this.
"""

import glob
import os
import shlex
import shutil
import subprocess
import sys

CXX_STD = "-std=c++17"
MACOS = sys.platform == "darwin"
LINUX = sys.platform.startswith("linux")
WX_LIBS = "core,base"


def which(*names):
    for n in names:
        if shutil.which(n):
            return n
    sys.exit(f"fpm_wx: none of {names} found on PATH")


def wx_config(*args):
    prog = os.environ.get("WX_CONFIG") or "wx-config"
    try:
        out = subprocess.check_output([prog, *args], text=True)
    except (OSError, subprocess.CalledProcessError):
        sys.exit(f"fpm_wx: `{prog} {' '.join(args)}` failed; install wxWidgets 3.2+ development\n"
                 "        files (e.g. `pixi install`) or set WX_CONFIG to your wx-config")
    return " ".join(out.split())


def lib_dirs(libs):
    return [a[2:] for a in shlex.split(libs) if a.startswith("-L")]


def settings():
    cxx = os.environ.get("FPM_CXX") or (which("clang++") if MACOS else which("g++", "c++"))
    cxxflags = [CXX_STD, "-fPIC", wx_config("--cxxflags")]
    libs = wx_config("--libs", WX_LIBS)
    # fpm puts FPM_LDFLAGS before the objects: on Linux, keep the libraries
    # even if the toolchain links with --as-needed by default
    ldflags = ["-Wl,--no-as-needed", libs] if LINUX else [libs]
    for d in lib_dirs(libs):
        ldflags.append(f"-Wl,-rpath,{d}")
        if LINUX:
            ldflags.append(f"-Wl,-rpath-link,{d}")
    env = {"FPM_CXX": cxx, "FPM_CXXFLAGS": " ".join(cxxflags), "FPM_LDFLAGS": " ".join(ldflags)}
    for key in ("FPM_CXXFLAGS", "FPM_LDFLAGS"):
        extra = os.environ.get(key, "").strip()
        if extra:
            env[key] = f"{env[key]} {extra}"
    return env


def pixbuf_loader_cache():
    """Linux: write a gdk-pixbuf loader cache for the active environment to
    build/ (if missing or older than the loaders); return its path or None."""
    prefix = os.environ.get("CONDA_PREFIX")
    query = shutil.which("gdk-pixbuf-query-loaders")
    if not (LINUX and prefix and query):
        return None
    dirs = glob.glob(os.path.join(prefix, "lib", "gdk-pixbuf-2.0", "*", "loaders"))
    if not dirs:
        return None
    loaders = glob.glob(os.path.join(dirs[0], "*.so"))
    if not loaders:
        return None
    cache = os.path.join(os.getcwd(), "build", "gdk-pixbuf-loaders.cache")
    newest = max(os.path.getmtime(f) for f in loaders)
    if os.path.exists(cache) and os.path.getmtime(cache) >= newest:
        return cache
    try:
        out = subprocess.check_output([query, *loaders], text=True,
                                      env=dict(os.environ, GDK_PIXBUF_MODULEDIR=dirs[0]))
    except (OSError, subprocess.CalledProcessError):
        return None
    # A relocatable gdk-pixbuf writes module paths relative to its prefix
    # (or bin/), which GTK would resolve against the running program: make
    # them absolute.
    bindir = os.path.dirname(os.path.realpath(query))
    lines = []
    for line in out.splitlines():
        s = line.strip()
        if s.startswith('"') and s.endswith('.so"') and not os.path.isabs(s[1:-1]):
            rel = s[1:-1]
            path = os.path.normpath(os.path.join(prefix, rel))
            if not os.path.exists(path):
                path = os.path.normpath(os.path.join(bindir, rel))
            line = '"' + path + '"'
        lines.append(line)
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    with open(cache, "w") as f:
        f.write("\n".join(lines) + "\n")
    return cache


def run(cmd, env=None):
    print("+", " ".join(cmd), flush=True)
    return subprocess.call(cmd, env=env)


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        sys.exit(__doc__)
    env_settings = settings()

    if sys.argv[1] == "--env":
        for k, v in env_settings.items():
            print(f"export {k}={shlex.quote(v)}")
        return

    env = dict(os.environ, **env_settings)
    fc = os.environ.get("FPM_FC") or which("gfortran")
    args = sys.argv[2:]
    if "--openmp" in args:
        args = [a for a in args if a != "--openmp"]
        # --link-flag replaces FPM_LDFLAGS (the wxWidgets libraries): pass both
        omp = ["--flag", "-fopenmp", "--link-flag", f"-fopenmp {env_settings['FPM_LDFLAGS']}"]
        if "--profile" not in args:
            omp = ["--profile", "release", *omp]
        args = [*omp, *args]
    cmd = ["fpm", sys.argv[1], "--compiler", fc, *args]
    if sys.argv[1] in ("test", "run"):
        cache = pixbuf_loader_cache()
        if cache:
            env.setdefault("GDK_PIXBUF_MODULE_FILE", cache)
    headless = LINUX and not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY")
    if sys.argv[1] in ("test", "run") and headless and not os.environ.get("WXF_NO_XVFB"):
        if shutil.which("xvfb-run"):
            cmd = ["xvfb-run", "-a", *cmd]
            env.setdefault("NO_AT_BRIDGE", "1")   # no AT-SPI bus under Xvfb: silence GTK's warning
        else:
            print("fpm_wx: warning: no display and no xvfb-run; GUI programs will fail to start",
                  file=sys.stderr)
    sys.exit(run(cmd, env))


if __name__ == "__main__":
    main()

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

On Linux without a display (e.g. CI), `test` runs under `xvfb-run` if it is
installed; set WXF_NO_XVFB=1 to disable this.
"""

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
    headless = LINUX and not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY")
    if sys.argv[1] in ("test", "run") and headless and not os.environ.get("WXF_NO_XVFB"):
        if shutil.which("xvfb-run"):
            cmd = ["xvfb-run", "-a", *cmd]
        else:
            print("fpm_wx: warning: no display and no xvfb-run; GUI programs will fail to start",
                  file=sys.stderr)
    sys.exit(run(cmd, env))


if __name__ == "__main__":
    main()

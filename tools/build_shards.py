#!/usr/bin/env python3
"""Build dfkup stdlib shards (libdfkup_<name>.<ext> dylibs).

This is the workflow-level replacement of dfkup's old `clue task stdlibs`:
the shard sources live in the stdkups repo (src/stdkups/), and both the
stdlib and dfkup GitHub workflows invoke this script instead of a nimble
task. Local dev too:

    python3 tools/build_shards.py --dfkup-src ../dfkup --out ../dfkup/bin/stdlib

Run from the stdkups checkout (or anywhere; paths are explicit flags).
Requires: python3, nim on PATH (or the choosenim toolchain matching a
given lock's nimVersion). Dependency `--path`s resolve from an optional
clue JSON lock; without one (CI runners never have it) they resolve
from stdkups.nimble via ~/.clue/develop, then ~/.clue/packages.
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))

# (shard name, lowlib module, init proc). Mirrors
# dfkup `stdlib_loader.dfkupStdlibNames` (minus `system`, which stays
# statically linked in the host binary).
STDLIB_MAP = [
    ("json", "libjson", "initJson"),
    ("httpclient", "libhttpclient", "initHttpClient"),
    ("http", "libhttp", "initHttp"),
    ("fswatch", "libfswatch", "initFswatch"),
    ("browser", "libbrowser", "initBrowser"),
    ("yaml", "libyaml", "initYaml"),
    ("strings", "libstrings", "initStrings"),
    ("sequtils", "libsequtils", "initSequtils"),
    ("cli", "libcli", "initCliLib"),
    ("config", "libconfig", "initConfig"),
    ("regex", "libregex", "initRegex"),
    ("toml", "libtoml", "initToml"),
    ("uuid", "libuuid", "initUuid"),
    ("dotenv", "libdotenv", "initDotenv"),
    ("csv", "libcsv", "initCsv"),
    ("bson", "libbson", "initBson"),
    ("colors", "libcolors", "initColors"),
    ("qr", "libqr", "initQr"),
    ("nanoid", "libnanoid", "initNanoId"),
    ("llm", "libllm", "initLlm"),
    ("xml", "libxml", "initXml"),
    ("feed", "libfeed", "initFeed"),
    ("ical", "libical", "initIcal"),
    ("css", "libcss", "initCss"),
    ("svg", "libsvg", "initSvg"),
    ("markdown", "libmarkdown", "initMarkdown"),
    ("strongpwd", "libstrongpwd", "initStrongpwd"),
    ("twofa", "libtwofa", "initTwofa"),
    ("algos", "libalgos", "initAlgos"),
    ("bench", "libbench", "initBench"),
]

BROWSER_CLEANUP = "proc dfkupStdlibCleanup*() =\n    closeAllBrowsers()\n"

# Server callbacks re-enter the host VM through this image's JIT-bridge
# globals; the host pushes its VM after creating it.
HTTP_SETVM = "proc dfkupStdlibSetVm*(vm: pointer) =\n    setHttpHostVm(vm)\n"

# The `conf` command reads the active config back across the dylib
# boundary. Results travel as opaque pointers / cstrings with a global
# holder so no dangling pointer ever crosses the boundary.
CONFIG_EXTRA = """var configLastResult {.global.}: string
proc dfkupConfigTakeActive*(): pointer =
    cast[pointer](peekActiveConfig())
proc dfkupConfigClearActive*() =
    clearActiveConfig()
proc dfkupConfigFindCommand*(cfg: pointer, name: cstring): cstring =
    try:
      configLastResult = findConfigCommand(cast[Value](cfg), $name)
      return configLastResult.cstring
    except CatchableError as e:
      pluginLastErr = e.msg
      return nil
proc dfkupConfigTakeErr*(): cstring =
    pluginLastErr.cstring
"""


def lib_extension() -> str:
    s = platform.system()
    if s == "Darwin":
        return ".dylib"
    if s == "Windows":
        return ".dll"
    return ".so"


def parse_requires(nimble_file: str):
    """(name, op, version) from `requires` lines. op is one of
    >=, ==, >, <=, < or "" (any version)."""
    reqs = []
    with open(nimble_file) as f:
        for line in f:
            line = line.strip()
            if not line.startswith("requires "):
                continue
            dep = line[len("requires "):].strip().strip('"').strip("'")
            if dep == "nim":
                continue
            parts = dep.split()
            if len(parts) == 1:
                reqs.append((parts[0], "", ""))
            elif len(parts) == 2 and parts[0] == "nim":
                continue
            elif len(parts) == 3:
                reqs.append((parts[0], parts[1], parts[2]))
            elif len(parts) == 2:
                reqs.append((parts[0], "", ""))
    return [r for r in reqs if r[0] != "nim"]


def ver_key(v: str):
    """Sort key: HEAD sorts highest, then numeric semver parts."""
    if v == "HEAD":
        return (1,)
    nums = []
    for part in v.split("."):
        try:
            nums.append(int(part))
        except ValueError:
            nums.append(0)
    return (0,) + tuple(nums)


def satisfies(ver: str, op: str, want: str) -> bool:
    if not op:
        return True
    if ver == "HEAD" or want == "HEAD":
        return True
    a, b = ver_key(ver), ver_key(want)
    if op == "==":
        return a == b
    if op == ">=":
        return a >= b
    if op == ">":
        return a > b
    if op == "<=":
        return a <= b
    if op == "<":
        return a < b
    return True


def nimble_src_dir(nimble_file: str) -> str:
    try:
        with open(nimble_file) as f:
            for line in f:
                line = line.strip()
                if line.startswith("srcDir"):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return "src"


def resolve_dep(name: str, op: str, want: str, clue_home: str) -> str:
    """Host src dir for one dependency: develop checkout first (live
    sources, matches local dev), else the newest registry install
    satisfying the constraint (matches CI, where only the registry
    exists)."""
    dev = os.path.join(clue_home, "develop", name)
    if os.path.isdir(dev):
        real = os.path.realpath(dev)
        src = os.path.join(real, nimble_src_dir(
            os.path.join(real, name + ".nimble")))
        if os.path.isdir(src):
            return src
        if os.path.isdir(real):
            return real
    pkgdir = os.path.join(clue_home, "packages", name)
    best = ""
    if os.path.isdir(pkgdir):
        for v in os.listdir(pkgdir):
            if not os.path.isdir(os.path.join(pkgdir, v)):
                continue
            if satisfies(v, op, want) and ver_key(v) > ver_key(best):
                best = v
    if not best:
        raise SystemExit(
            "cannot resolve dependency " + name +
            " (no develop checkout, no registry install in " +
            os.path.join(clue_home, "packages") + ")")
    root = os.path.join(pkgdir, best)
    src = os.path.join(root, nimble_src_dir(
        os.path.join(root, name + ".nimble")))
    return src if os.path.isdir(src) else root


def lock_paths(lock_file: str):
    """Dep src paths + nimVersion from a clue JSON lock (dfkup still
    keeps one locally; CI runners will not have it)."""
    with open(lock_file) as f:
        lock = json.load(f)
    paths = []
    for pkg in lock.get("packages", []):
        p = pkg.get("path", "")
        if p and p not in paths:
            paths.append(p)
    return paths, lock.get("nimVersion", "")


def find_nim(nim_version: str) -> str:
    if nim_version:
        cand = os.path.join(
            os.path.expanduser("~"), ".choosenim", "toolchains",
            "nim-" + nim_version, "bin", "nim")
        if os.path.isfile(cand):
            return cand
    found = shutil.which("nim")
    if found:
        return found
    raise SystemExit("no Nim toolchain found")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lock", default="",
                    help="optional clue JSON lock with resolved dep paths "
                         "(dfkup keeps one locally; takes precedence when "
                         "present). Default resolution: stdkups.nimble "
                         "requires via ~/.clue/develop, then "
                         "~/.clue/packages.")
    ap.add_argument("--nimble", default="",
                    help="nimble file with shard deps "
                         "(default: <stdkups>/stdkups.nimble)")
    ap.add_argument("--stdkups", default=os.path.join(TOOLS_DIR, ".."),
                    help="stdkups checkout (template + src live here)")
    ap.add_argument("--dfkup-src", default="",
                    help="dfkup checkout (provides lang/transformers, "
                         "lang/parser). Default: CWD if it looks like dfkup, "
                         "else <stdkups>/../dfkup.")
    ap.add_argument("--out", default="bin/stdlib",
                    help="output dir for the built shards")
    ap.add_argument("--gen", default="",
                    help="output dir for generated wrappers "
                         "(default: <out>/../stdlib_gen)")
    ap.add_argument("--libs", default="",
                    help="comma-separated subset of shards to build "
                         "(default: all)")
    args = ap.parse_args()

    dfkup_src = args.dfkup_src
    if not dfkup_src:
        if os.path.isfile(os.path.join("src", "lang", "transformers.nim")):
            dfkup_src = os.getcwd()
        else:
            guess = os.path.join(args.stdkups, "..", "dfkup")
            if os.path.isfile(os.path.join(guess, "src", "lang",
                                           "transformers.nim")):
                dfkup_src = os.path.normpath(guess)
    if not dfkup_src or not os.path.isfile(
            os.path.join(dfkup_src, "src", "lang", "transformers.nim")):
        raise SystemExit(
            "dfkup checkout not found (need src/lang/transformers.nim); "
            "pass --dfkup-src")
    dfkup_src = os.path.abspath(dfkup_src)
    stdkups = os.path.abspath(args.stdkups)
    tmpl_file = os.path.join(stdkups, "tools", "stdlib_plugin.tmpl")
    if not os.path.isfile(tmpl_file):
        raise SystemExit("template not found: " + tmpl_file)
    with open(tmpl_file) as f:
        tmpl = f.read()

    lock_file = args.lock
    if not lock_file and os.path.isfile("clue.lock"):
        lock_file = "clue.lock"
    clue_home = os.path.join(os.path.expanduser("~"), ".clue")
    if lock_file:
        paths, nim_version = lock_paths(lock_file)
        if not paths:
            raise SystemExit(
                lock_file + " has no package paths; run `clue install` first")
    else:
        # No lock (CI runners never have one): resolve the shard deps
        # from the nimble requirements, develop checkouts first.
        nimble_file = (args.nimble if args.nimble
                       else os.path.join(stdkups, "stdkups.nimble"))
        paths = []
        for dep_name, op, want in parse_requires(nimble_file):
            p = resolve_dep(dep_name, op, want, clue_home)
            if p not in paths:
                paths.append(p)
        nim_version = ""
    if not paths:
        raise SystemExit("no dependency paths resolved; " +
                         ("check " + lock_file if lock_file else
                          "run `clue install` first"))
    nim_exe = find_nim(nim_version)

    want = None
    if args.libs:
        want = {x.strip() for x in args.libs.split(",") if x.strip()}
    ext = lib_extension()
    out_dir = os.path.abspath(args.out)
    gen_dir = (os.path.abspath(args.gen) if args.gen
               else os.path.normpath(os.path.join(out_dir, "..",
                                                  "stdlib_gen")))
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(gen_dir, exist_ok=True)

    path_args = []
    for p in paths:
        path_args.append("--path:" + p)
    # Host sources (transformers/parser) + shard sources themselves.
    path_args.append("--path:" + os.path.join(dfkup_src, "src"))
    path_args.append("--path:" + os.path.join(stdkups, "src"))

    built = 0
    for name, module, init_proc in STDLIB_MAP:
        if want is not None and name not in want:
            continue
        cleanup = BROWSER_CLEANUP if name == "browser" else ""
        setvm = HTTP_SETVM if name == "http" else ""
        extra = CONFIG_EXTRA if name == "config" else ""
        gen_file = os.path.join(gen_dir, "stdlib_" + name + ".nim")
        with open(gen_file, "w") as f:
            f.write(tmpl.replace("%%NAME%%", name)
                    .replace("%%MODULE%%", module)
                    .replace("%%INIT%%", init_proc)
                    .replace("%%CLEANUP%%", cleanup)
                    .replace("%%SETVM%%", setvm)
                    .replace("%%EXTRA%%", extra))
        out_lib = os.path.join(out_dir, "libdfkup_" + name + ext)
        # Drop any stale lib first: same-second rewrites can otherwise
        # look up-to-date to nim's incremental check and silently skip.
        if os.path.isfile(out_lib):
            os.remove(out_lib)
        # NB: `-d:release`, not `--release` (this toolchain rejects it).
        # `--threads:on --mm:arc` must match the host flags: the heap
        # contract across the dylib boundary is uniform flags on every
        # image (mixed settings fault — region-heap mismatch segfaults,
        # useMalloc breaks dylib init and cross-heap frees abort).
        # ARC (no tracing, pure refcounting) is the boundary-safe
        # collector.
        cmd = ([nim_exe, "c", "--app:lib", "--threads:on", "--mm:arc",
                "-d:release", "--opt:speed",
                "--hints:off", "--verbosity:0",
                "-d:vancodeJitNim", "-d:nimPreviewHashRef",
                "-d:supranimUseGlobalOnRequest"]
               + path_args
               + ["--out:" + out_lib, gen_file])
        print("building libdfkup_" + name + ext + " ...", flush=True)
        subprocess.run(cmd, check=True)
        built += 1

    # Install into the package-manager-owned libraries dir
    # (DFKUP_HOME-aware); the out dir stays the dev fallback.
    lib_home = os.path.join(os.environ.get("DFKUP_HOME",
                                           os.path.join(
                                               os.path.expanduser("~"),
                                               ".dfkup")),
                            "libraries")
    os.makedirs(lib_home, exist_ok=True)
    for name, _, _ in STDLIB_MAP:
        if want is not None and name not in want:
            continue
        shutil.copy2(os.path.join(out_dir, "libdfkup_" + name + ext),
                      os.path.join(lib_home, "libdfkup_" + name + ext))
    print("stdlib shards in " + out_dir + " and " + lib_home)
    return 0


if __name__ == "__main__":
    sys.exit(main())

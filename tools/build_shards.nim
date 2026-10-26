## Build dfkup stdlib shards (libdfkup_<name>.<ext> dylibs).
##
## Workflow-level replacement of dfkup's old `clue task stdlibs`: shard
## sources live in the stdkups repo (src/stdkups/), and both the stdlib
## and dfkup GitHub workflows invoke this program instead of a nimble
## task. Local dev too (plain `nim c -r`, std-only imports):
##
##   nim c -r tools/build_shards.nim --stdkups=. --dfkup-src=../dfkup \
##     --out=../dfkup/bin/stdlib
##
## Dependency `--path`s resolve from an optional clue JSON lock (the
## stdkups checkout's own, never the invoker's); without one they
## resolve from stdkups.nimble, transitively, via ~/.clue/develop,
## then ~/.clue/packages. The dfkup sources resolve from --dfkup-src, a nearby checkout, or the dfkup package itself
## (`clue install dfkup --build`).

import std/[json, os, osproc, strutils]

# (shard name, lowlib module, init proc). Mirrors
# dfkup `stdlib_loader.dfkupStdlibNames` minus the five lowlibs that
# dfkup links into the host binary itself
# (`system`, `json`, `strings`, `sequtils`, `regex`).
const stdlibMap = [
  ("date", "libdate", "initDate"),
  ("locale", "liblocale", "initLocale"),
  ("vcard", "libvcard", "initVcard"),
  ("plist", "libplist", "initPlist"),
  ("fuzzy", "libfuzzy", "initFuzzy"),
  ("diff", "libdiff", "initDiff"),
  ("html", "libhtml", "initHtml"),
  ("path", "libpath", "initPath"),
  ("httpclient", "libhttpclient", "initHttpClient"),
  ("http", "libhttp", "initHttp"),
  ("fswatch", "libfswatch", "initFswatch"),
  ("browser", "libbrowser", "initBrowser"),
  ("yaml", "libyaml", "initYaml"),
  ("cli", "libcli", "initCliLib"),
  ("config", "libconfig", "initConfig"),
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

const browserCleanup = "proc dfkupStdlibCleanup*() =\n    closeAllBrowsers()\n"

# Server callbacks re-enter the host VM through this image's JIT-bridge
# globals; the host pushes its VM after creating it.
const httpSetVm = "proc dfkupStdlibSetVm*(vm: pointer) =\n    setHttpHostVm(vm)\n"

# The `conf` command reads the active config back across the dylib
# boundary. Results travel as opaque pointers / cstrings with a global
# holder so no dangling pointer ever crosses the boundary.
const configExtra = """var configLastResult {.global.}: string
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

proc libExtension(): string =
  when hostOS == "windows":
    ".dll"
  elif hostOS == "macosx":
    ".dylib"
  else:
    ".so"

type Req = tuple[name, op, want: string]

proc parseRequires(nimbleFile: string): seq[Req] =
  ## (name, op, version) from `requires` lines.
  for line in lines(nimbleFile):
    let l = line.strip()
    if not l.startsWith("requires "):
      continue
    let dep = l[len("requires ") .. ^1].strip().strip(chars = {'"', '\''})
    let parts = dep.split()
    if parts.len == 1 and parts[0] != "nim":
      result.add((parts[0], "", ""))
    elif parts.len == 3 and parts[0] != "nim":
      result.add((parts[0], parts[1], parts[2]))

proc cmpVer(a, b: string): int =
  ## HEAD sorts above everything; else numeric per part.
  if a == "HEAD" and b == "HEAD":
    return 0
  if a == "HEAD":
    return 1
  if b == "HEAD":
    return -1
  let ap = a.split('.')
  let bp = b.split('.')
  for i in 0 ..< max(ap.len, bp.len):
    var ai, bi = 0
    if i < ap.len:
      try:
        ai = parseInt(ap[i])
      except ValueError:
        discard
    if i < bp.len:
      try:
        bi = parseInt(bp[i])
      except ValueError:
        discard
    if ai != bi:
      return cmp(ai, bi)
  0

proc satisfies(ver, op, want: string): bool =
  if op.len == 0:
    return true
  if ver == "HEAD" or want == "HEAD":
    return true
  let c = cmpVer(ver, want)
  case op
  of "==": c == 0
  of ">=": c >= 0
  of ">": c > 0
  of "<=": c <= 0
  of "<": c < 0
  else: true

proc nimbleSrcDir(nimbleFile: string): string =
  try:
    for line in lines(nimbleFile):
      let l = line.strip()
      if l.startsWith("srcDir"):
        return l.split("=", 1)[1].strip().strip(chars = {'"', '\''})
  except IOError:
    discard
  "src"

proc depRootAndSrc(name, op, want, clueHome: string): tuple[root, src: string] =
  ## Package root + src dir for one dependency: develop checkout first
  ## (live sources, matches local dev), else the newest registry install
  ## satisfying the constraint (matches CI, where only the registry
  ## exists).
  let dev = clueHome / "develop" / name
  if dirExists(dev):
    let real = expandSymlink(dev)
    let src = real / nimbleSrcDir(real / name & ".nimble")
    if dirExists(src):
      return (real, src)
    if dirExists(real):
      return (real, real)
  let pkgdir = clueHome / "packages" / name
  var best = ""
  if dirExists(pkgdir):
    for kind, p in walkDir(pkgdir):
      if kind != pcDir:
        continue
      let ver = lastPathPart(p)
      if satisfies(ver, op, want) and cmpVer(ver, best) > 0:
        best = ver
  if best.len == 0:
    quit("cannot resolve dependency " & name &
      " (no develop checkout, no registry install in " &
      pkgdir & ")")
  let root = pkgdir / best
  let src = root / nimbleSrcDir(root / name & ".nimble")
  if dirExists(src):
    (root, src)
  else:
    (root, root)

proc resolveDep(name, op, want, clueHome: string): string =
  depRootAndSrc(name, op, want, clueHome).src

proc addDepPaths(name, op, want, clueHome: string,
                 paths: var seq[string], seen: var seq[string]) =
  ## `--path` for one dep plus its transitive closure: each package's
  ## own nimble requires are recursed with their own constraints.
  ## Without this only direct deps land on `--path` and shards fail on
  ## second-level imports (e.g. powpow's `multipart`). `seen` guards
  ## dependency cycles.
  if name in seen:
    return
  seen.add(name)
  # `dfkup` is excluded from the dep --paths: the host sources always
  # come from the explicit dfkup path (see main), so a registry copy
  # can never shadow the intended checkout earlier on --path order.
  if name == "dfkup":
    return
  let (root, src) = depRootAndSrc(name, op, want, clueHome)
  if src notin paths:
    paths.add(src)
  let nimbleF = root / name & ".nimble"
  if fileExists(nimbleF):
    for r in parseRequires(nimbleF):
      addDepPaths(r.name, r.op, r.want, clueHome, paths, seen)

proc lockPaths(lockFile: string): tuple[paths: seq[string], nimVersion: string] =
  ## Dep src paths + nimVersion from a clue JSON lock (dfkup still
  ## keeps one locally; CI runners will not have it).
  let lock = parseJson(readFile(lockFile))
  for pkg in lock["packages"]:
    let p = if pkg.hasKey("path"): pkg["path"].getStr() else: ""
    if p.len > 0 and p notin result.paths:
      result.paths.add(p)
  result.nimVersion = if lock.hasKey("nimVersion"): lock["nimVersion"].getStr()
                      else: ""

proc findNim(nimVersion: string): string =
  if nimVersion.len > 0:
    let cand = getHomeDir() / ".choosenim" / "toolchains" /
      "nim-" & nimVersion / "bin" / "nim"
    if fileExists(cand):
      return cand
  let found = findExe("nim")
  if found.len == 0:
    quit("no Nim toolchain found")
  found

proc runOrQuit(cmd: seq[string]) =
  var p = startProcess(cmd[0], args = cmd[1 .. ^1],
    options = {poParentStreams, poUsePath})
  let code = p.waitForExit()
  p.close()
  if code != 0:
    quit(code)

proc main() =
  var lockFile, nimbleFile, stdkupsDir, dfkupSrc, outDir, genDir = ""
  var libs: seq[string] = @[]
  outDir = "bin" / "stdlib"
  for arg in commandLineParams():
    if arg.startsWith("--lock="):
      lockFile = arg[len("--lock=") .. ^1]
    elif arg.startsWith("--nimble="):
      nimbleFile = arg[len("--nimble=") .. ^1]
    elif arg.startsWith("--stdkups="):
      stdkupsDir = arg[len("--stdkups=") .. ^1]
    elif arg.startsWith("--dfkup-src="):
      dfkupSrc = arg[len("--dfkup-src=") .. ^1]
    elif arg.startsWith("--out="):
      outDir = arg[len("--out=") .. ^1]
    elif arg.startsWith("--gen="):
      genDir = arg[len("--gen=") .. ^1]
    elif arg.startsWith("--libs="):
      for x in arg[len("--libs=") .. ^1].split(','):
        if x.strip().len > 0:
          libs.add(x.strip())
    else:
      quit("unknown argument: " & arg & "\nusage: build_shards " &
        "[--lock=] [--nimble=] [--stdkups=] [--dfkup-src=] [--out=] " &
        "[--gen=] [--libs=a,b]")

  if stdkupsDir.len == 0:
    if fileExists("tools" / "stdlib_plugin.tmpl") and
        dirExists("src" / "stdkups"):
      stdkupsDir = getCurrentDir()
  let clueHome = getHomeDir() / ".clue"
  if dfkupSrc.len == 0:
    if fileExists("src" / "lang" / "transformers.nim") or
        fileExists("lang" / "transformers.nim"):
      dfkupSrc = getCurrentDir()
    elif stdkupsDir.len > 0:
      let guess = stdkupsDir / ".." / "dfkup"
      if fileExists(guess / "src" / "lang" / "transformers.nim") or
          fileExists(guess / "lang" / "transformers.nim"):
        dfkupSrc = guess
  # Normalize the root to the actual --path dir: modern checkouts keep
  # sources under src/, while the published dfkup 0.1.0 lays lang/
  # flat at the package root.
  var dfkupPath = ""
  if dfkupSrc.len > 0:
    if fileExists(dfkupSrc / "src" / "lang" / "transformers.nim"):
      dfkupPath = dfkupSrc / "src"
    elif fileExists(dfkupSrc / "lang" / "transformers.nim"):
      dfkupPath = dfkupSrc
  if dfkupPath.len == 0:
    # No checkout nearby: resolve the dfkup package itself through
    # clue (`clue install dfkup --build` in CI). Develop checkout
    # wins locally, registry install otherwise.
    try:
      let s = resolveDep("dfkup", "", "", clueHome)
      if fileExists(s / "lang" / "transformers.nim"):
        dfkupPath = s
      elif fileExists(s / "src" / "lang" / "transformers.nim"):
        dfkupPath = s / "src"
    except CatchableError:
      discard
  if stdkupsDir.len == 0:
    quit("stdkups checkout not found (need tools/stdlib_plugin.tmpl); " &
      "pass --stdkups")
  if dfkupPath.len == 0:
    quit("dfkup sources not found (need lang/transformers.nim under " &
      "src/ or at the package root); pass --dfkup-src with the " &
      "checkout or installed package root, or run " &
      "`clue install dfkup --build`")
  stdkupsDir = absolutePath(stdkupsDir)
  dfkupPath = absolutePath(dfkupPath)

  let tmplFile = stdkupsDir / "tools" / "stdlib_plugin.tmpl"
  if not fileExists(tmplFile):
    quit("template not found: " & tmplFile)
  let tmpl = readFile(tmplFile)

  # Shard dependencies come from stdkups, so only a stdkups lock is
  # valid here — never the CWD lock of a dfkup checkout invoking the
  # builder with an explicit --stdkups (dfkup has no `requires
  # "stdkups"`, so its lock no longer carries the shard deps and would
  # shadow them with an incomplete --path set).
  if lockFile.len == 0:
    if stdkupsDir.len > 0 and fileExists(stdkupsDir / "clue.lock"):
      lockFile = stdkupsDir / "clue.lock"
    elif stdkupsDir.len == 0 and fileExists("clue.lock"):
      lockFile = "clue.lock"
  var paths: seq[string] = @[]
  var nimVersion = ""
  if lockFile.len > 0:
    (paths, nimVersion) = lockPaths(lockFile)
    if paths.len == 0:
      quit(lockFile & " has no package paths; run `clue install` first")
  else:
    # No lock (CI runners may not have one): resolve the shard deps
    # from the nimble requirements, transitively, develop checkouts
    # first.
    let nimbleF = if nimbleFile.len > 0: nimbleFile
                  else: stdkupsDir / "stdkups.nimble"
    var seen: seq[string] = @[]
    for r in parseRequires(nimbleF):
      addDepPaths(r.name, r.op, r.want, clueHome, paths, seen)
  if paths.len == 0:
    quit("no dependency paths resolved; run `clue install` first")
  let nimExe = findNim(nimVersion)

  let ext = libExtension()
  let outAbs = absolutePath(outDir)
  let genAbs = if genDir.len > 0: absolutePath(genDir)
               else: outAbs / ".." / "stdlib_gen"
  createDir(outAbs)
  createDir(genAbs)

  var pathArgs: seq[string] = @[]
  for p in paths:
    pathArgs.add("--path:" & p)
  # Host sources (transformers/parser) + shard sources themselves.
  pathArgs.add("--path:" & dfkupPath)
  pathArgs.add("--path:" & stdkupsDir / "src")

  for (name, module, initProc) in stdlibMap:
    if libs.len > 0 and name notin libs:
      continue
    let cleanup = if name == "browser": browserCleanup else: ""
    let setvm = if name == "http": httpSetVm else: ""
    let extra = if name == "config": configExtra else: ""
    let genFile = genAbs / "stdlib_" & name & ".nim"
    writeFile(genFile, tmpl.replace("%%NAME%%", name)
      .replace("%%MODULE%%", module).replace("%%INIT%%", initProc)
      .replace("%%CLEANUP%%", cleanup).replace("%%SETVM%%", setvm)
      .replace("%%EXTRA%%", extra))
    let outLib = outAbs / "libdfkup_" & name & ext
    # Drop any stale lib first: same-second rewrites can otherwise
    # look up-to-date to nim's incremental check and silently skip.
    if fileExists(outLib):
      removeFile(outLib)
    # NB: `-d:release`, not `--release` (this toolchain rejects it).
    # `--threads:on --mm:arc` must match the host flags: the heap
    # contract across the dylib boundary is uniform flags on every
    # image (mixed settings fault — region-heap mismatch segfaults,
    # useMalloc breaks dylib init and cross-heap frees abort).
    # ARC (no tracing, pure refcounting) is the boundary-safe
    # collector.
    var cmd = @[nimExe, "c", "--app:lib", "--threads:on", "--mm:arc",
      "-d:release", "--opt:speed",
      "--hints:off", "--verbosity:0",
      "-d:vancodeJitNim", "-d:nimPreviewHashRef",
      "-d:supranimUseGlobalOnRequest"] & pathArgs &
      @["--out:" & outLib, genFile]
    echo "building libdfkup_" & name & ext & " ..."
    stdout.flushFile()
    runOrQuit(cmd)

  # Install into the package-manager-owned libraries dir
  # (DFKUP_HOME-aware); the out dir stays the dev fallback.
  let libHome = getEnv("DFKUP_HOME", getHomeDir() / ".dfkup") / "libraries"
  createDir(libHome)
  for (name, _, _) in stdlibMap:
    if libs.len > 0 and name notin libs:
      continue
    copyFile(outAbs / "libdfkup_" & name & ext,
      libHome / "libdfkup_" & name & ext)
  echo "stdlib shards in " & outAbs & " and " & libHome

main()

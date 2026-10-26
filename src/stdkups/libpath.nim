# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/path` — URL/path parsing for dfkup.

import std/[strutils, options]
import pkg/openparser/path
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc getPath(p: pointer): Path = cast[ptr Path](p)[]

proc initPath*(script: Script, module: Module) =

  script.addProc(module, "parsePath", @[paramDef("s", ttyString)], ttyPointer,
    impl = proc (args: StackView, argc: int): Value =
      let pp = parsePath(args[0].stringVal[])
      let r = new Path
      r[] = pp
      result = initValue(tyPointer, r)
  )

  script.addProc(module, "pathToString", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      result = initValue($pp)
  )

  script.addProc(module, "pathKind", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      result = initValue($pp.kind)
  )

  script.addProc(module, "pathIsAbsolute", @[paramDef("p", ttyPointer)], ttyBool,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      result = initValue(pp.isAbsolute)
  )

  script.addProc(module, "pathSegments", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal:
        result = initValue(pp.segments.join("/"))
      else:
        result = initValue(pp.pathSegments.join("/"))
  )

  script.addProc(module, "pathHost", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal:
        result = initValue("")
      else:
        result = initValue(pp.host)
  )

  script.addProc(module, "pathPort", @[paramDef("p", ttyPointer)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal or pp.port.isNone:
        result = initValue(0'i64)
      else:
        result = initValue(int64(pp.port.get))
  )

  script.addProc(module, "pathQuery", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal:
        result = initValue("")
      else:
        var parts: seq[string]
        for q in pp.query: parts.add(q.key & "=" & q.value)
        result = initValue(parts.join("&"))
  )

  script.addProc(module, "pathFragment", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal or pp.fragment.isNone:
        result = initValue("")
      else:
        result = initValue(pp.fragment.get)
  )

  script.addProc(module, "pathExt", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal:
        if pp.localExt.isSome: result = initValue(pp.localExt.get)
        else: result = initValue("")
      else:
        if pp.ext.isSome: result = initValue(pp.ext.get)
        else: result = initValue("")
  )

  script.addProc(module, "pathScheme", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      if pp.isLocal:
        result = initValue("")
      else:
        result = initValue(pp.scheme)
  )

  script.addProc(module, "pathRaw", @[paramDef("p", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let pp = getPath(args[0].objectVal.foreign.data)
      result = initValue(pp.raw)
  )

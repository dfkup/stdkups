# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/diff` — text diffing for dfkup.

import std/[strutils]
import pkg/openparser/diff
import pkg/openparser/diff/render
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc initDiff*(script: Script, module: Module) =

  script.addProc(module, "diffUnified",
    @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let d = diff(args[0].stringVal[], args[1].stringVal[])
      result = initValue(renderUnified(d))
  )

  script.addProc(module, "diffFile",
    @[paramDef("pathA", ttyString), paramDef("pathB", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let d = diffFile(args[0].stringVal[], args[1].stringVal[])
      result = initValue(renderUnified(d))
  )

  script.addProc(module, "sameText",
    @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyBool,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(sameText(args[0].stringVal[], args[1].stringVal[]))
  )

  script.addProc(module, "diffStats",
    @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let st = diffStats(args[0].stringVal[], args[1].stringVal[])
      result = initValue("added=" & $st.added & " removed=" & $st.removed & " changed=" & $st.changed)
  )

  script.addProc(module, "diffSummary",
    @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let d = diff(args[0].stringVal[], args[1].stringVal[])
      result = initValue(renderSummary(d))
  )

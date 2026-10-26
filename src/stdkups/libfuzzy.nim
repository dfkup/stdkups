# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/fuzzy` — fuzzy string matching for dfkup.

import std/[json, strutils]
import pkg/openparser/fuzzy
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc initFuzzy*(script: Script, module: Module) =

  script.addProc(module, "fuzzyScore",
    @[paramDef("query", ttyString), paramDef("candidate", ttyString)], ttyFloat,
    impl = proc (args: StackView, argc: int): Value =
      let r = fuzzyScore(args[0].stringVal[], args[1].stringVal[])
      result = initValue(float64(r.score))
  )

  script.addProc(module, "fuzzyMatched",
    @[paramDef("query", ttyString), paramDef("candidate", ttyString)], ttyBool,
    impl = proc (args: StackView, argc: int): Value =
      let r = fuzzyScore(args[0].stringVal[], args[1].stringVal[])
      result = initValue(r.matched)
  )

  script.addProc(module, "fuzzyPositions",
    @[paramDef("query", ttyString), paramDef("candidate", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let r = fuzzyScore(args[0].stringVal[], args[1].stringVal[])
      var parts: seq[string]
      for p in r.positions: parts.add($p)
      result = initValue(parts.join(","))
  )

  script.addProc(module, "fuzzySearch",
    @[paramDef("query", ttyString), paramDef("candidates", ttyString)], ttyJson,
    impl = proc (args: StackView, argc: int): Value =
      let query = args[0].stringVal[]
      let cands = args[1].stringVal[].splitLines()
      let res = fuzzySearch(query, cands)
      var arr = newJArray()
      for m in res:
        var o = newJObject()
        o["text"] = %m.text
        o["score"] = %float64(m.score)
        var pos = newJArray()
        for p in m.positions: pos.add(%p)
        o["positions"] = pos
        arr.add(o)
      result = initValue(arr)
  )

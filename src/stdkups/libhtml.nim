# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/html` — HTML parsing for dfkup.

import std/[strutils]
import pkg/openparser/html
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc initHtml*(script: Script, module: Module) =

  script.addProc(module, "parseHtml", @[paramDef("s", ttyString)], ttyPointer,
    impl = proc (args: StackView, argc: int): Value =
      let d = parseHtml(args[0].stringVal[])
      let r = new HtmlDocument
      r[] = d
      result = initValue(tyPointer, r)
  )

  script.addProc(module, "htmlInnerText", @[paramDef("doc", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let r = cast[ptr HtmlDocument](args[0].objectVal.foreign.data)
      result = initValue(innerText(r[]))
  )

# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/locale` — gettext-based localization for dfkup.
##
## Wraps openparser/gettext: load `.mo`/`.po` catalogs and translate
## messages, with plural-form support.

import std/[json, strutils, tables]
import pkg/openparser/gettext/[mo, po]
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc asMo(p: pointer): MoCatalog = cast[MoCatalog](p)
proc asPo(p: pointer): PoCatalog = cast[PoCatalog](p)

proc initLocale*(script: Script, module: Module) =

  #
  # MO catalogs
  #

  script.addProc(module, "openMo", @[paramDef("path", ttyString)], ttyPointer,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(tyPointer, openMoCatalog(args[0].stringVal[]))
  )

  script.addProc(module, "closeMo", @[paramDef("cat", ttyPointer)], ttyVoid,
    impl = proc (args: StackView, argc: int): Value =
      var c = asMo(args[0].objectVal.foreign.data)
      close(c)
  )

  script.addProc(module, "translateMo",
    @[paramDef("cat", ttyPointer), paramDef("msgid", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asMo(args[0].objectVal.foreign.data)
      result = initValue(translate(c, args[1].stringVal[]))
  )

  script.addProc(module, "ntranslateMo",
    @[paramDef("cat", ttyPointer), paramDef("singular", ttyString),
      paramDef("plural", ttyString), paramDef("n", ttyInt)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asMo(args[0].objectVal.foreign.data)
      let cc = compileMo(c)
      result = initValue(ntranslate(cc, args[1].stringVal[], args[2].stringVal[], int(args[3].intVal)))
  )

  script.addProc(module, "pluralIndexMo",
    @[paramDef("cat", ttyPointer), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let c = asMo(args[0].objectVal.foreign.data)
      let cc = compileMo(c)
      result = initValue(int64(pluralIndex(cc, int(args[1].intVal))))
  )

  #
  # PO catalogs
  #

  script.addProc(module, "openPo", @[paramDef("path", ttyString)], ttyPointer,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(tyPointer, openPoCatalog(args[0].stringVal[]))
  )

  script.addProc(module, "closePo", @[paramDef("cat", ttyPointer)], ttyVoid,
    impl = proc (args: StackView, argc: int): Value =
      var c = asPo(args[0].objectVal.foreign.data)
      close(c)
  )

  script.addProc(module, "translatePo",
    @[paramDef("cat", ttyPointer), paramDef("msgid", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asPo(args[0].objectVal.foreign.data)
      let cc = compilePo(c)
      result = initValue(translate(cc, args[1].stringVal[]))
  )

  script.addProc(module, "ntranslatePo",
    @[paramDef("cat", ttyPointer), paramDef("singular", ttyString),
      paramDef("plural", ttyString), paramDef("n", ttyInt)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asPo(args[0].objectVal.foreign.data)
      let cc = compilePo(c)
      result = initValue(ntranslate(cc, args[1].stringVal[], args[2].stringVal[], int(args[3].intVal)))
  )

  script.addProc(module, "poHeaders", @[paramDef("cat", ttyPointer)], ttyJson,
    impl = proc (args: StackView, argc: int): Value =
      let c = asPo(args[0].objectVal.foreign.data)
      var j = newJObject()
      for k, v in parsePoHeaders(c):
        j[k] = %v
      result = initValue(j)
  )

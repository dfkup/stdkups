# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/plist` — Apple property list (XML/binary) parsing for dfkup.

import std/[strutils]
import pkg/openparser/plist
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc initPlist*(script: Script, module: Module) =

  script.addProc(module, "parsePlist", @[paramDef("s", ttyString)], ttyJson,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(parsePlist(args[0].stringVal[]))
  )

  script.addProc(module, "parsePlistFile", @[paramDef("path", ttyString)], ttyJson,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(parsePlistFile(args[0].stringVal[]))
  )

  script.addProc(module, "parseXmlPlist", @[paramDef("s", ttyString)], ttyJson,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(parseXmlPlist(args[0].stringVal[]))
  )

  script.addProc(module, "parseXmlPlistFile", @[paramDef("path", ttyString)], ttyJson,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(parseXmlPlistFile(args[0].stringVal[]))
  )

  script.addProc(module, "toXmlPlist", @[paramDef("node", ttyJson)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(toXmlPlist(args[0].jsonVal))
  )

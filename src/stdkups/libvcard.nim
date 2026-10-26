# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/vcard` — vCard 3.0/4.0 parsing and generation for dfkup.

import std/[strutils, options]
import pkg/openparser/vcard
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc asVCard(p: pointer): VCard = cast[VCard](p)

proc initVcard*(script: Script, module: Module) =

  script.addProc(module, "parseVCard", @[paramDef("s", ttyString)], ttyPointer,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(tyPointer, parseVCard(args[0].stringVal[]))
  )

  script.addProc(module, "toVCard", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      result = initValue($c)
  )

  script.addProc(module, "vcardFn", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      result = initValue(c.fn)
  )

  script.addProc(module, "vcardVersion", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      result = initValue($c.version)
  )

  script.addProc(module, "vcardEmails", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      var parts: seq[string]
      for e in c.emails: parts.add(e.value)
      result = initValue(parts.join(","))
  )

  script.addProc(module, "vcardTels", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      var parts: seq[string]
      for t in c.tels: parts.add(t.value)
      result = initValue(parts.join(","))
  )

  script.addProc(module, "vcardOrg", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      if c.org.isSome:
        result = initValue(c.org.get.name)
      else:
        result = initValue("")
  )

  script.addProc(module, "vcardUid", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      if c.uid.isSome:
        result = initValue(c.uid.get)
      else:
        result = initValue("")
  )

  script.addProc(module, "vcardBday", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      if c.bday.isSome:
        result = initValue(c.bday.get.value)
      else:
        result = initValue("")
  )

  script.addProc(module, "vcardNote", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      if c.note.isSome:
        result = initValue(c.note.get)
      else:
        result = initValue("")
  )

  script.addProc(module, "vcardCategories", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      result = initValue(c.categories.join(","))
  )

  script.addProc(module, "vcardUrls", @[paramDef("card", ttyPointer)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let c = asVCard(args[0].objectVal.foreign.data)
      var parts: seq[string]
      for u in c.urls: parts.add(u.value)
      result = initValue(parts.join(","))
  )

  script.addProc(module, "isVCardDate", @[paramDef("s", ttyString)], ttyBool,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(isVCardDate(args[0].stringVal[]))
  )

  script.addProc(module, "isVCardDateTime", @[paramDef("s", ttyString)], ttyBool,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(isVCardDateTime(args[0].stringVal[]))
  )

  script.addProc(module, "escapeVCardText", @[paramDef("s", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(escapeVCardText(args[0].stringVal[]))
  )

  script.addProc(module, "unescapeVCardText", @[paramDef("s", ttyString)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(unescapeVCardText(args[0].stringVal[]))
  )

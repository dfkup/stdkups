# DFkup - A fast scripting language for cool kids!
#
# (c) 2026 George Lemon | LGPLv3 License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev
#          https://github.com/dfkup/dfkup

## `std/date` — date and time utilities for dfkup.
##
## Built on Nim's `std/times`: a `date` value is an `int64` epoch
## timestamp (seconds since 1970-01-01 00:00:00 UTC).

import std/[strutils, times]
import pkg/vancode/interpreter/[chunk, sym, value]
import pkg/vancode/interpreter/stdlib/[syslib, utils]

proc toTime(t: int64): Time =
  fromUnix(t)

proc toDt(t: int64): DateTime =
  toTime(t).inZone(local())

proc initDate*(script: Script, module: Module) =

  #
  # Now
  #

  script.addProc(module, "now", returnTy = ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(getTime().toUnix())
  )

  script.addProc(module, "nowMs", returnTy = ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(getTime().toUnixFloat() * 1000.0))
  )

  script.addProc(module, "epochTime", returnTy = ttyFloat,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(getTime().toUnixFloat())
  )

  #
  # Construction
  #

  script.addProc(module, "dateTime",
    @[paramDef("year", ttyInt), paramDef("month", ttyInt),
      paramDef("day", ttyInt),
      paramDef("hour", ttyInt, initValue(0)),
      paramDef("minute", ttyInt, initValue(0)),
      paramDef("second", ttyInt, initValue(0))], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let y = int(args[0].intVal)
      let m = int(args[1].intVal)
      let d = int(args[2].intVal)
      let h = int(args[3].intVal)
      let mi = int(args[4].intVal)
      let s = int(args[5].intVal)
      let dt = dateTime(y, Month(m), d, h, mi, s, zone = local())
      result = initValue(dt.toTime().toUnix())
  )

  #
  # Formatting / parsing
  #

  script.addProc(module, "format",
    @[paramDef("t", ttyInt),
      paramDef("fmt", ttyString, initValue("yyyy-MM-dd HH:mm:ss"))],
    ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let t = args[0].intVal
      let fmt = args[1].stringVal[]
      result = initValue(toTime(t).format(fmt, local()))
  )

  script.addProc(module, "formatUtc",
    @[paramDef("t", ttyInt),
      paramDef("fmt", ttyString, initValue("yyyy-MM-dd HH:mm:ss"))],
    ttyString,
    impl = proc (args: StackView, argc: int): Value =
      let t = args[0].intVal
      let fmt = args[1].stringVal[]
      result = initValue(toTime(t).format(fmt, utc()))
  )

  script.addProc(module, "toIso", @[paramDef("t", ttyInt)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(toTime(args[0].intVal).format("yyyy-MM-dd'T'HH:mm:ss", utc()) & "Z")
  )

  script.addProc(module, "parse",
    @[paramDef("s", ttyString), paramDef("fmt", ttyString)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      let fmt = args[1].stringVal[]
      let dt = parse(s, fmt, local())
      result = initValue(dt.toTime().toUnix())
  )

  script.addProc(module, "parseUtc",
    @[paramDef("s", ttyString), paramDef("fmt", ttyString)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      let fmt = args[1].stringVal[]
      let dt = parse(s, fmt, utc())
      result = initValue(dt.toTime().toUnix())
  )

  #
  # Components (local time)
  #

  script.addProc(module, "year", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).year))
  )

  script.addProc(module, "month", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).month.ord))
  )

  script.addProc(module, "day", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).monthday))
  )

  script.addProc(module, "hour", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).hour))
  )

  script.addProc(module, "minute", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).minute))
  )

  script.addProc(module, "second", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).second))
  )

  script.addProc(module, "weekday", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).weekday.ord))
  )

  script.addProc(module, "yearday", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(toDt(args[0].intVal).yearday))
  )

  script.addProc(module, "monthName", @[paramDef("t", ttyInt)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue($toDt(args[0].intVal).month)
  )

  script.addProc(module, "weekdayName", @[paramDef("t", ttyInt)], ttyString,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue($toDt(args[0].intVal).weekday)
  )

  #
  # Predicates / helpers
  #

  script.addProc(module, "isLeapYear", @[paramDef("year", ttyInt)], ttyBool,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(isLeapYear(int(args[0].intVal)))
  )

  script.addProc(module, "daysInMonth",
    @[paramDef("year", ttyInt), paramDef("month", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(int64(getDaysInMonth(Month(int(args[1].intVal)),
        int(args[0].intVal))))
  )

  script.addProc(module, "startOfDay", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let dt = toDt(args[0].intVal)
      let s = dateTime(dt.year, dt.month, dt.monthday, 0, 0, 0, zone = local())
      result = initValue(s.toTime().toUnix())
  )

  script.addProc(module, "startOfMonth", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let dt = toDt(args[0].intVal)
      let s = dateTime(dt.year, dt.month, 1, 0, 0, 0, zone = local())
      result = initValue(s.toTime().toUnix())
  )

  script.addProc(module, "startOfYear", @[paramDef("t", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let dt = toDt(args[0].intVal)
      let s = dateTime(dt.year, mJan, 1, 0, 0, 0, zone = local())
      result = initValue(s.toTime().toUnix())
  )

  #
  # Arithmetic
  #

  script.addProc(module, "addSeconds",
    @[paramDef("t", ttyInt), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(args[0].intVal + args[1].intVal)
  )

  script.addProc(module, "addMinutes",
    @[paramDef("t", ttyInt), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(args[0].intVal + args[1].intVal * 60)
  )

  script.addProc(module, "addHours",
    @[paramDef("t", ttyInt), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(args[0].intVal + args[1].intVal * 3600)
  )

  script.addProc(module, "addDays",
    @[paramDef("t", ttyInt), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(args[0].intVal + args[1].intVal * 86400)
  )

  script.addProc(module, "addMonths",
    @[paramDef("t", ttyInt), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let dt = toDt(args[0].intVal)
      let ti = initTimeInterval(months = int(args[1].intVal))
      let ndt = dt + ti
      result = initValue(ndt.toTime().toUnix())
  )

  script.addProc(module, "addYears",
    @[paramDef("t", ttyInt), paramDef("n", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      let dt = toDt(args[0].intVal)
      let ti = initTimeInterval(years = int(args[1].intVal))
      let ndt = dt + ti
      result = initValue(ndt.toTime().toUnix())
  )

  script.addProc(module, "diff",
    @[paramDef("a", ttyInt), paramDef("b", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue(args[0].intVal - args[1].intVal)
  )

  script.addProc(module, "diffDays",
    @[paramDef("a", ttyInt), paramDef("b", ttyInt)], ttyInt,
    impl = proc (args: StackView, argc: int): Value =
      result = initValue((args[0].intVal - args[1].intVal) div 86400)
  )

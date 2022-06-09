import std/[strformat, options, tables, macros]

import toml_serialization
import toml_serialization/value_ops

export value_ops except len

type
  TomlArray* = seq[TomlValueRef]
  TomlTables* = seq[TomlTableRef]

proc newTInt*(val: int64 = default int64): TomlValueRef = 
  TomlValueRef(kind: TomlKind.Int, intVal: val)

proc newTFloat*(val: float64 = default float64): TomlValueRef = 
  TomlValueRef(kind: TomlKind.Float, floatVal: val)

proc newTBool*(val: bool = default bool): TomlValueRef = 
  TomlValueRef(kind: TomlKind.Bool, boolVal: val)

proc newTDateTime*(val: TomlDateTime = default TomlDateTime): TomlValueRef = 
  TomlValueRef(kind: TomlKind.DateTime, dateTime: val)

proc newTString*(val: string = default string): TomlValueRef = 
  TomlValueRef(kind: TomlKind.String, stringVal: val)

proc newTArray*(val: openArray[TomlValueRef] = default TomlArray): TomlValueRef = 
  TomlValueRef(kind: TomlKind.Array, arrayVal: @val)

proc newTTables*(val: openArray[TomlTableRef] = default TomlTables): TomlValueRef = 
  TomlValueRef(kind: TomlKind.Tables, tablesVal: @val)

proc newTTable*(val: TomlTableRef = new TomlTableRef): TomlValueRef = 
  TomlValueRef(kind: TomlKind.Table, tableVal: val)

proc newTTable*(pairs: openArray[(string, TomlValueRef)]): TomlValueRef = 
  result = newTTable()

  for key, val in pairs.items:
    result[key] = val

proc newTNode*(val: int64): TomlValueRef = 
  newTInt(val)

proc newTNode*(val: float64): TomlValueRef = 
  newTFloat(val)

proc newTNode*(val: bool): TomlValueRef = 
  newTBool(val)

proc newTNode*(val: TomlDateTime): TomlValueRef = 
  newTDateTime(val)

proc newTNode*(val: string): TomlValueRef = 
  newTString(val)

proc newTNode*(val: TomlArray): TomlValueRef = 
  newTArray(val)

proc newTNode*(val: TomlTables): TomlValueRef = 
  newTTables(val)

proc newTNode*(val: TomlTableRef): TomlValueRef = 
  newTTable(val)

proc newTNode*(val: openArray[(string, TomlValueRef)]): TomlValueRef = 
  newTTable(val)

proc newTNode*(val: TomlValueRef): TomlValueRef = val

proc getInt*(node: TomlValueRef): int64 = 
  assert node.kind == TomlKind.Int
  node.intVal

proc getFloat*(node: TomlValueRef): float64 = 
  assert node.kind == TomlKind.Float
  node.floatVal

proc getBool*(node: TomlValueRef): bool = 
  assert node.kind == TomlKind.Bool
  node.boolVal

proc getDateTime*(node: TomlValueRef): TomlDateTime = 
  assert node.kind == TomlKind.DateTime
  node.dateTime

proc getString*(node: TomlValueRef): string = 
  assert node.kind == TomlKind.String
  node.stringVal

proc getArray*(node: TomlValueRef): TomlArray = 
  assert node.kind == TomlKind.Array
  node.arrayVal

proc getTables*(node: TomlValueRef): TomlTables = 
  assert node.kind == TomlKind.Tables
  node.tablesVal

proc getTable*(node: TomlValueRef): TomlTableRef = 
  assert node.kind == TomlKind.Table
  node.tableVal

macro toToml*(obj: untyped): TomlValueRef =
  ## Converts the given object into a `PrefsNode` if possible
  ## - Arrays are converted into sequences
  ## - `{key: val, ..}` are converted to ordered tables.
  runnableExamples:
    let data = toToml({
      "num": 10,
      floating: 10.23,
      users: @["a", 1, false],
      names: [],
      keybindings: {:},
      scheme: {
        background: "#000000",
        font: "UbuntuMono"
      }
    })

  case obj.kind
  of nnkTableConstr, nnkCurly: # Object {key: val, ...} or {:} or {}
    if obj.len == 0: return newCall("newTTable")
    result = newNimNode(nnkTableConstr)

    for pair in obj:
      pair.expectKind(nnkExprColonExpr) # Expects key:val
      case pair[0].kind
      of nnkStrLit:
        result.add nnkExprColonExpr.newTree(pair[0], newCall("toToml", pair[1]))
      of nnkIdent:
        result.add nnkExprColonExpr.newTree(pair[0].toStrLit, newCall("toToml", pair[1]))
      else:
        raise newException(ValueError, &"Invalid key {pair[0].repr}, it must be a string or a valid identifier")

    result = newCall("newTTable", result)
  of nnkBracket: # Array [ele, ...]
    if obj.len == 0: return newCall("newTArray")
    result = newNimNode(nnkBracket)

    for ele in obj:
      result.add newCall("toToml", ele)

    result = newCall("newTArray", result)
  elif obj.kind == nnkPrefix and obj[0].repr == "@": # Sequence @[ele, ...]
    result = newCall("toToml", obj[1])
  else:
    result = newCall("newTNode", obj)

proc `[]=`*(obj: TomlValueRef, index: int, val: TomlValueRef) =
  assert obj.kind == TomlKind.Array

  obj.arrayVal[index] = val

proc `[]=`*[T: not TomlValueRef](obj: TomlValueRef, index: int, val: T) =
  assert obj.kind == TomlKind.Array

  obj.arrayVal[index] = val.newTNode()

proc `[]=`*[T: not TomlValueRef](obj: TomlValueRef, key: string, val: T) =
  obj[key] = newTNode(val)

proc `{}=`*[T: not TomlValueRef](node: TomlValueRef, keys: varargs[string], value: T) =
  node{keys} = newTNode(value)

proc `$`*(time: TomlTime): string = 
  &"{time.hour:02}:{time.minute:02}:{time.second:02}.{time.subsecond}"

proc `$`*(date: TomlDate): string = 
  &"{date.year:04}-{date.month:02}-{date.day:02}"

proc `$`*(zone: TomlTimeZone): string = 
  if zone.hourShift == 0 and zone.minuteShift == 0:
    return "Z"

  result.add if zone.positiveShift: "+" else: "-"
  result.add &"{zone.hourShift:02}:{zone.minuteShift:02}"

proc `$`*(datetime: TomlDateTime): string = 
  assert datetime.date.isSome
  
  result.add $datetime.date.get()
  
  if datetime.time.isSome:
    result.add "T"
    result.add $datetime.time.get()
    if datetime.zone.isSome:
      result.add $datetime.zone.get()

proc `$`*(node: TomlValueRef): string

proc `$`*(node: TomlValue): string = 
  case node.kind
  of TomlKind.Int:
    result = $node.intVal
  of TomlKind.Float:
    result = $node.floatVal
  of TomlKind.Bool:
    result = $node.boolVal
  of TomlKind.DateTime:
    result = $node.dateTime
  of TomlKind.String:
    result.addQuoted node.stringVal
  of TomlKind.Array:
    result = $node.arrayVal:
  of TomlKind.Tables:
    result = $node.tablesVal
  of TomlKind.Table, TomlKind.InlineTable:
    result = $node.tableVal

proc `$`*(node: TomlValueRef): string = 
  if node.isNil:
    "nil"
  else:
    $node[]

proc `==`*[T: not TomlValueRef](node: TomlValueRef, val: T): bool = 
  node == val.newTNode()

proc tDateTime*(date: Option[TomlDate] = none(TomlDate), time: Option[TomlTime] = none(TomlTime), zone: Option[TomlTimeZone] = none(TomlTimeZone)): TomlDateTime = 
  TomlDateTime(date: date, time: time, zone: zone)

proc tDateTime*(source: string): TomlDateTime = 
  Toml.decode(&"datetime = {source}", TomlDateTime, "datetime")

proc tDate*(year: range[0..9999] = 0, month: range[1..12] = 1, day: range[1..31] = 1): TomlDate = 
  TomlDate(year: year, month: month, day: day)

proc tDate*(source: string): TomlDate = 
  Toml.decode(&"date = {source}", TomlDate, "date")

proc tTime*(hour: range[0..23] = 0, minute: range[0..59], second: range[0..60], subsecond: int = 0): TomlTime = 
  TomlTime(hour: hour, minute: minute, second: second, subsecond: subsecond)

proc tTime*(source: string): TomlTime = 
  Toml.decode(&"time = {source}", TomlTime, "time")

proc tTimeZone*(positiveShift = false, hourShift, minuteShift: int = 0): TomlTimeZone = 
  TomlTimeZone(positiveShift: positiveShift, hourShift: hourShift, minuteShift: minuteShift)

proc len*(node: TomlValueRef): int = 
  assert node.kind in {TomlKind.Array, TomlKind.Tables, TomlKind.Table}

  case node.kind
  of TomlKind.Array:
    result = node.arrayVal.len
  of TomlKind.Tables:
    result = node.tablesVal.len
  of TomlKind.Table:
    result = node.tableVal.len
  else: discard

proc add*(node: TomlValueRef, table: TomlTableRef) = 
  assert node.kind == TomlKind.Tables

  node.tablesVal.add(table)

proc add*(node: TomlValueRef, val: TomlValueRef) = 
  assert node.kind == TomlKind.Array

  node.arrayVal.add(val)

proc add*[T: not TomlValueRef](node: TomlValueRef, val: T) = 
  assert node.kind == TomlKind.Array

  node.arrayVal.add(val.newTNode())

proc delete*(node: TomlValueRef, index: int) = 
  assert node.kind in {TomlKind.Array, TomlKind.Tables}

  case node.kind:
  of TomlKind.Array:
    node.arrayVal.delete(index)
  of TomlKind.Tables:
    node.tablesVal.delete(index)
  else: discard

proc contains*[T: not TomlValueRef](node: TomlValueRef, val: T): bool =
  assert node.kind == TomlKind.Array
  val.newTNode() in node

proc hasKey*(node: TomlValueRef, keys: varargs[string]): bool = 
  ## Traverses the node and checks if the given key exists.
  assert node.kind == TomlKind.Table

  var table = node
  for key in keys:
    if key notin table:
      return false

    table = table[key]

  result = true

iterator items*(node: TomlValueRef): TomlValueRef = 
  assert node.kind in {TomlKind.Array, TomlKind.Tables}

  case node.kind
  of TomlKind.Array:
    for ele in node.arrayVal: yield ele
  of TomlKind.Tables:
    for table in node.tablesVal: yield table.newTTable()
  else: discard

iterator pairs*(node: TomlValueRef): (string, TomlValueRef) = 
  assert node.kind == TomlKind.Table

  for key, val in node.tableVal:
    yield (key, val)

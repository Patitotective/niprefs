import std/[macros, tables]

type
  PSeqParam* = openArray[PrefsNode] ## Used for as the parameter for sequence type
  PSeqType* = seq[PrefsNode] ## Prefs sequence type
  PObjectType* = OrderedTable[string, PrefsNode] ## Prefs ordered table type

  PrefsNKind* = enum ## Valid node kinds for PrefsNode
    PEmpty,          # Default
    PInt,
    PNil,
    PSeq,
    PBool,
    PChar,
    PFloat,
    PObject,
    PString,

  PrefsNode* = ref PrefsNodeObj ## Reference to PrefsNodeObj
  PrefsNodeObj* = object ## Object variant
    case kind*: PrefsNKind
    of PInt:
      intV*: int
    of PNil:
      discard
    of PSeq:
      seqV*: PSeqType
    of PBool:
      boolV*: bool
    of PChar:
      charV*: char
    of PEmpty:
      discard
    of PFloat:
      floatV*: float
    of PObject:
      objectV*: PObjectType
    of PString:
      stringV*: string

proc isNil*(node: PrefsNode): bool =
  ## Check if a `PrefsNode` is `nil`.

  node.kind == PNil

proc isEmpty*(node: PrefsNode): bool =
  ## Check if a `PrefsNode` is `empty`.
  node.kind == PEmpty

proc getInt*(node: PrefsNode): int =
  ## Get the `intV` field from a `PrefsNode`.
  node.intV

proc getSeq*(node: PrefsNode): PSeqType =
  ## Get the `seqV` field from a `PrefsNode`.
  node.seqV

proc getBool*(node: PrefsNode): bool =
  ## Get the `boolV` field from a `PrefsNode`.
  node.boolV

proc getChar*(node: PrefsNode): char =
  ## Get the `charV` field from a `PrefsNode`.
  node.charV

proc getFloat*(node: PrefsNode): float =
  ## Get the `floatV` field from a `PrefsNode`.
  node.floatV

proc getObject*(node: PrefsNode): PObjectType =
  ## Get the `objectV` field from a `PrefsNode`.
  node.objectV

proc getString*(node: PrefsNode): string =
  ## Get the `stringV` field from a `PrefsNode`.
  node.stringV

proc newPInt*(val: int = default int): PrefsNode =
  ## Create a new PrefsNode of `PInt` kind.
  PrefsNode(kind: PInt, intV: val)

proc newPNil*(): PrefsNode =
  ## Create a new PrefsNode of `PNil` kind.
  PrefsNode(kind: PNil)

proc newPSeq*(val: PSeqParam = default PSeqType): PrefsNode =
  ## Create a new PrefsNode of `PSeq` kind.
  PrefsNode(kind: PSeq, seqV: @val)

proc newPBool*(val: bool = default bool): PrefsNode =
  ## Create a new PrefsNode of `PBool` kind.
  PrefsNode(kind: PBool, boolV: val)

proc newPChar*(val: char = default char): PrefsNode =
  ## Create a new PrefsNode of `PChar` kind.
  PrefsNode(kind: PChar, charV: val)

proc newPChar*(val: string = default string, start: Natural = 0): PrefsNode =
  ## Create a new PrefsNode of `PChar` kind from the `start` index of `val`.
  PrefsNode(kind: PChar, charV: val[start])

proc newPEmpty*(): PrefsNode =
  ## Create a new PrefsNode of `PEmpty` kind.
  PrefsNode(kind: PEmpty)

proc newPFloat*(val: float = default float): PrefsNode =
  ## Create a new PrefsNode of `PFloat` kind.
  PrefsNode(kind: PFloat, floatV: val)

proc newPObject*(val: PObjectType = default PObjectType): PrefsNode =
  ## Create a new PrefsNode of `PObject` kind.
  PrefsNode(kind: PObject, objectV: val)

proc newPString*(val: string = default string): PrefsNode =
  ## Create a new PrefsNode of `PString` kind.
  PrefsNode(kind: PString, stringV: val)

proc newPNode*(obj: int): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPInt(obj)

proc newPNode*(obj: PSeqParam): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPSeq(obj)

proc newPNode*(obj: bool): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPBool(obj)

proc newPNode*(obj: char): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPChar(obj)

proc newPNode*(obj: float): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPFloat(obj)

proc newPNode*(obj: PObjectType): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPObject(obj)

proc newPNode*(obj: string): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPString(obj)

macro toPrefs*(obj: untyped): PrefsNode =
  ## Converts the given object into a `PrefsNode` if possible
  ## - Arrays are converted into sequences
  ## - `{key: val, ..}` are converted to ordered tables.
  ## **Example:**
  ##
  ## .. code-block:: Nim
  ##   var table = toPrefs({
  ##     "lang": "es",
  ##     "dark": true,
  ##     "users": @[],
  ##     "names": [],
  ##     "keybindings": {: },
  ##     "scheme": {
  ##       "background": "#000000",
  ##       "font": "UbuntuMono"
  ##     }
  ##   }).getObject()

  case obj.kind
  of nnkTableConstr: # Object {key: val, ...} or {:}
    if obj.len == 0: return newCall("newPObject")
    result = newNimNode(nnkTableConstr)

    for i in obj:
      i.expectKind(nnkExprColonExpr) # Expects key:val
      result.add nnkExprColonExpr.newTree(i[0], newCall("toPrefs", i[1]))

    result = newCall("newPObject", newCall(bindSym"toOrderedTable", result))
  of nnkCurly: # Empty object {}
    obj.expectLen(0)
    result = newCall("newPObject")
  of nnkNilLit: # nil
    result = newCall("newPNil")
  of nnkBracket: # Array [ele, ...]
    if obj.len == 0: return newCall("newPSeq")
    result = newNimNode(nnkBracket)

    for i in obj:
      result.add newCall("toPrefs", i)

    result = newCall("newPSeq", result)
  elif obj.kind == nnkPrefix and obj[0].repr == "@": # Sequence @[ele, ...]
    if obj[1].len == 0: return newCall("newPSeq")
    result = newNimNode(nnkBracket)

    for i in obj[1]:
      result.add newCall("toPrefs", i)

    result = newCall("newPSeq", result)
  else:
    result = newCall("newPNode", obj)

proc `==`*(node1: PrefsNode, node2: PrefsNode): bool =
  ## Checks if two nodes of the same kind have the same value

  assert node1.kind == node2.kind

  case node1.kind:
  of PInt:
    result = node1.getInt() == node2.getInt()
  of PNil:
    result = true
  of PSeq:
    result = node1.getSeq() == node2.getSeq()
  of PBool:
    result = node1.getBool() == node2.getBool()
  of PChar:
    result = node1.getChar() == node2.getChar()
  of PEmpty:
    result = true
  of PFloat:
    result = node1.getFloat() == node2.getFloat()
  of PObject:
    result = node1.getObject() == node2.getObject()
  of PString:
    result = node1.getString() == node2.getString()

proc `==`*[T: not PrefsNode](node1: PrefsNode, node2: T): bool =
  ## Checks if two nodes of the same kind have the same value
  ##
  ## Converts `node2` to `PrefsNode` using `newPNode`.

  node1 == newPnode(node2)

proc `$`*(node: PrefsNode): string =
  ## Return the value of the node as a string.
  case node.kind:
  of PInt:
    result = $node.getInt()
  of PNil:
    result = "nil"
  of PSeq:
    result = $node.getSeq()
  of PBool:
    result = $node.getBool()
  of PChar:
    result.addQuoted(node.getChar())
  of PEmpty:
    result = "PEmpty"
  of PFloat:
    result = $node.getFloat()
  of PObject:
    result = $node.getObject()
  of PString:
    result.addQuoted(node.getString())

proc `[]`*(node: var PrefsNode, key: string): var PrefsNode =
  ## Access to the value of `key` in `node.objectV`. The value can be modified.
  node.objectV[key]

proc `[]`*(node: PrefsNode, key: string): PrefsNode =
  ## Access to the value of `key` in `node.objectV`.
  node.objectV[key]

proc `[]`*(node: PrefsNode, index: int): PrefsNode =
  ## Access to `index` in `node.seqV`.
  node.seqV[index]

proc `[]`*(node: PrefsNode, index: BackwardsIndex): PrefsNode =
  ## Access to `index` in `node.seqV`.
  node.seqV[index]

proc `[]=`*[T: not PrefsNode](node: var PrefsNode, key: string, val: T) =
  ## Change the value of the key in node's table
  ## The given value is converted to PrefsNode` with `newPNode`

  runnableExamples:
    var table = toPrefs {"lang": "en"}
    table["lang"] = "es"

  node.objectV[key] = newPNode(val)

proc `[]=`*(node: var PrefsNode, key: string, val: PrefsNode) =
  ## Change the value of the key in node's table

  runnableExamples:
    var table = toPrefs {"lang": "en"}
    table["users"] = toPrefs @["ElegantBeef", "Patitotective"]

  node.objectV[key] = val

proc del*(node: var PrefsNode, key: string) = 
  ## Delete `key` from `node.objectV`.

  node.objectV.del(key)

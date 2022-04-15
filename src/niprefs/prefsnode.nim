import std/[strutils, macros, tables]

type
  PSeqParam* = openArray[PrefsNode] ## Used for as the parameter for sequence type
  PSeqType* = seq[PrefsNode] ## Prefs sequence type
  PObjectType* = OrderedTable[string, PrefsNode] ## Prefs ordered table type

  PrefsKind* = enum ## Valid node kinds for PrefsNode
    PEmpty,          # Default
    PInt,
    PNil,
    PSeq,
    PBool,
    PChar,
    PFloat,
    PObject,
    PString,
    PCharSet,
    PByteSet,

  PrefsNode* = ref PrefsNodeObj ## Reference to PrefsNodeObj
  PrefsNodeObj* = object ## Object variant
    case kind*: PrefsKind
    of PEmpty, PNil:
      discard
    of PInt:
      intV*: int
    of PSeq:
      seqV*: PSeqType
    of PBool:
      boolV*: bool
    of PChar:
      charV*: char
    of PFloat:
      floatV*: float
    of PObject:
      objectV*: PObjectType
    of PString:
      stringV*: string
    of PCharSet:
      charSetV*: set[char]
    of PByteSet:
      byteSetV*: set[byte]

proc isEmpty*(node: PrefsNode): bool =
  ## Check if a `PrefsNode` is `empty`.
  node.kind == PEmpty

proc isNil*(node: PrefsNode): bool =
  ## Check if a `PrefsNode` is `nil`.

  node.kind == PNil

proc getInt*(node: PrefsNode): int =
  ## Get the `intV` field from `node`.
  node.intV

proc getSeq*(node: PrefsNode): PSeqType =
  ## Get the `seqV` field from `node`.
  node.seqV

proc getBool*(node: PrefsNode): bool =
  ## Get the `boolV` field from `node`.
  node.boolV

proc getChar*(node: PrefsNode): char =
  ## Get the `charV` field from `node`.
  node.charV

proc getFloat*(node: PrefsNode): float =
  ## Get the `floatV` field from `node`.
  node.floatV

proc getObject*(node: PrefsNode): PObjectType =
  ## Get the `objectV` field from `node`.
  node.objectV

proc getString*(node: PrefsNode): string =
  ## Get the `stringV` field from `node`.
  node.stringV

proc getCharSet*(node: PrefsNode): set[char] = 
  ## Get the `charSetV` field from `node`.
  node.charSetV

proc getByteSet*(node: PrefsNode): set[byte] = 
  ## Get the `byteSet` field from `node`.
  node.byteSetV

proc getInt*(node: var PrefsNode): var int =
  ## Get the `intV` field from a `PrefsNode`.
  node.intV

proc getSeq*(node: var PrefsNode): var PSeqType =
  ## Get the `seqV` field from a `PrefsNode`.
  node.seqV

proc getBool*(node: var PrefsNode): var bool =
  ## Get the `boolV` field from a `PrefsNode`.
  node.boolV

proc getChar*(node: var PrefsNode): var char =
  ## Get the `charV` field from a `PrefsNode`.
  node.charV

proc getFloat*(node: var PrefsNode): var float =
  ## Get the `floatV` field from a `PrefsNode`.
  node.floatV

proc getObject*(node: var PrefsNode): var PObjectType =
  ## Get the `objectV` field from a `PrefsNode`.
  node.objectV

proc getString*(node: var PrefsNode): var string =
  ## Get the `stringV` field from a `PrefsNode`.
  node.stringV

proc getCharSet*(node: var PrefsNode): var set[char] = 
  ## Get the `charSetV` field from `node`.
  node.charSetV

proc getByteSet*(node: var PrefsNode): var set[byte] = 
  ## Get the `byteSet` field from `node`.
  node.byteSetV

proc newPEmpty*(): PrefsNode =
  ## Create a new PrefsNode of `PEmpty` kind.
  PrefsNode(kind: PEmpty)

proc newPNil*(): PrefsNode =
  ## Create a new PrefsNode of `PNil` kind.
  PrefsNode(kind: PNil)

proc newPInt*(val: int = default int): PrefsNode =
  ## Create a new PrefsNode of `PInt` kind.
  PrefsNode(kind: PInt, intV: val)

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

proc newPFloat*(val: float = default float): PrefsNode =
  ## Create a new PrefsNode of `PFloat` kind.
  PrefsNode(kind: PFloat, floatV: val)

proc newPObject*(val: PObjectType = default PObjectType): PrefsNode =
  ## Create a new PrefsNode of `PObject` kind.
  PrefsNode(kind: PObject, objectV: val)

proc newPString*(val: string = default string): PrefsNode =
  ## Create a new PrefsNode of `PString` kind.
  PrefsNode(kind: PString, stringV: val)

proc newPCharSet*(val: set[char] = default set[char]): PrefsNode = 
  ## Create a new PrefsNode of `PCharSet` kind.
  PrefsNode(kind: PCharSet, charSetV: val)

proc newPByteSet*(val: set[byte] = default set[byte]): PrefsNode = 
  ## Create a new PrefsNode of `PCharSet` kind.
  PrefsNode(kind: PByteSet, byteSetV: val)

proc newPByteSet*[T: not byte](val: set[T]): PrefsNode = 
  newPByteSet(cast[ptr set[byte]](val.unsafeAddr)[])

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

proc newPNode*(obj: set[char]): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPCharSet(obj)

proc newPNode*(obj: set[byte]): PrefsNode =
  ## Create a new PrefsNode from `obj`.
  newPByteSet(obj)

macro toPrefs*(obj: untyped): PrefsNode =
  ## Converts the given object into a `PrefsNode` if possible
  ## - Arrays are converted into sequences
  ## - `{key: val, ..}` are converted to ordered tables.
  runnableExamples:
    let config = toPrefs({
      "lang": "es",
      "dark": true,
      range: {'a'..'z'},
      numRange: {0..255},
      users: @[],
      names: [],
      keybindings: {:},
      scheme: {
        background: "#000000",
        font: "UbuntuMono"
      }
    })

  case obj.kind
  of nnkTableConstr: # Object {key: val, ...} or {:}
    if obj.len == 0: return newCall("newPObject")
    result = newNimNode(nnkTableConstr)

    for i in obj:
      i.expectKind(nnkExprColonExpr) # Expects key:val
      if i[0].kind == nnkStrLit:
        result.add nnkExprColonExpr.newTree(i[0].strVal.nimIdentNormalize().newStrLitNode(), newCall("toPrefs", i[1]))
      elif i[0].kind == nnkIdent:
        result.add nnkExprColonExpr.newTree(i[0].toStrLit.strVal.nimIdentNormalize().newStrLitNode(), newCall("toPrefs", i[1]))

    result = newCall("newPObject", newCall(bindSym"toOrderedTable", result))
  of nnkCurly: # Set {a, b..c} or {}
    if obj.len == 0: raise newException(ValueError, "Ambiguous set, use newPCharSet() or newPByteSet()")
   
    case obj[0].kind
    of nnkCharLit:
      result = newCall("newPCharSet", obj)
    of nnkIntLit, nnkUInt8Lit:
      result = newCall("newPByteSet", obj)
    of nnkInfix:
      case obj[0][1].kind
      of nnkCharLit:
        result = newCall("newPCharSet", obj)
      of nnkIntLit, nnkUInt8Lit:
        result = newCall("newPByteSet", obj)      
      else: raise newException(ValueError, "Expected char, int or byte, got " & $obj[0][1].kind)
    else: raise newException(ValueError, "Expected char, range, int or byte, got " & $obj[0].kind)
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
  of PCharSet:
    result = node1.getCharSet() == node2.getCharSet()
  of PByteSet:
    result = node1.getByteSet() == node2.getByteSet()

proc `==`*[T: not PrefsNode](node1: PrefsNode, node2: T): bool =
  ## Checks if two nodes of the same kind have the same value
  ##
  ## Converts `node2` to `PrefsNode` using `newPNode`.

  node1 == newPnode(node2)

proc `$`*(node: PrefsNode): string =
  ## Return the value of the node as a string.

  case node.kind:
  of PEmpty:
    result = "PEmpty"
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
  of PFloat:
    result = $node.getFloat()
  of PObject:
    result = $node.getObject()
  of PString:
    result.addQuoted(node.getString())
  of PCharSet:
    if node.getCharSet().len == 0:
      result = "{c}"
    else:
      result = $node.getCharSet()
  of PByteSet:
    if node.getByteSet().len == 0:
      result = "{b}"
    else:
      result = $node.getByteSet()

proc `[]`*(node: var PrefsNode, key: string): var PrefsNode =
  ## Access to the value of `key` in `node.obj°ectV`. The value can be modified.
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

proc `[]=`*[T: not PrefsNode](node: var PrefsNode, index: int, val: T) = 
  ## Change the value at `index` in `node.seqV` for `val`.
  ## The given value is converted to `PrefsNode` with `newPNode`

  node.seqV[index] = val.newPNode()

proc `[]=`*(node: var PrefsNode, index: int, val: PrefsNode) = 
  ## Change the value at `index` in `node.seqV` for `val`.

  node.seqV[index] = val

proc `[]=`*[T: not PrefsNode](node: var PrefsNode, key: string, val: T) =
  ## Change the value of the key in node's table
  ## The given value is converted to `PrefsNode` with `newPNode`

  runnableExamples:
    var table = toPrefs {"lang": "en"}
    table["lang"] = "es"

  node.objectV[key] = val.newPNode()

proc `[]=`*(node: var PrefsNode, key: string, val: PrefsNode) =
  ## Change the value of the key in node's table

  runnableExamples:
    var table = toPrefs {"lang": "en"}
    table["users"] = toPrefs @["ElegantBeef", "Patitotective"]

  node.objectV[key] = val

proc len*(node: var PrefsNode): int = 
  case node.kind
  of PSeq:
    node.getSeq().len
  of PObject:
    node.getObject().len
  of PCharSet:
    node.getCharSet().len
  of PByteSet:
    node.getByteSet().len
  else:
    raise newException(ValueError, "Invalid procedure len for PrefsNode of kind " & $node.kind)

proc del*(node: var PrefsNode, key: string) = 
  ## Delete `key` from `node.objectV`.

  node.objectV.del(key)

proc delete*(node: var PrefsNode, i: Natural) = 
  ## Delete the element at `i` from `node.seqV`.

  node.seqV.delete(i)

proc deleted*(node: var PrefsNode, i: Natural): PrefsNode = 
  ## Returns `node` with `i` index deleted from `node.seqV`. 
  runnableExamples:
    var node = toPrefs([1, 2, 3])
    assert node.deleted(0) == toPrefs([2, 3])

  result = node
  result.seqV.delete(i)

proc add*[T: not PrefsNode](node: var PrefsNode, val: T) = 
  ## Add `node` to `node.seqV`
  node.seqV.add val.newPNode()

proc add*(node: var PrefsNode, val: PrefsNode) = 
  ## Add `node` to `node.seqV`
  node.seqV.add val

proc added*[T: not PrefsNode](node: var PrefsNode, val: T): PrefsNode = 
  ## Returns `node` with `val` added to `node.seqV`.
  result = node
  result.seqV.add val.newPNode()

proc added*(node: var PrefsNode, val: PrefsNode): PrefsNode = 
  ## Returns `node` with `val` added to `node.seqV`.
  result = node
  result.seqV.add val

proc contains*(node: PrefsNode, key: string): bool =
  node.getObject().contains(key)

proc contains*(node: PrefsNode, ele: char): bool =
  node.getCharSet().contains(ele)

proc contains*(node: PrefsNode, ele: byte): bool =
  node.getByteSet().contains(ele)

proc card*(node: PrefsNode): int = 
  case node.kind
  of PCharSet:
    node.getCharSet().card
  of PByteSet:
    node.getByteSet().card
  else:
    raise newException(ValueError, "Invalid procedure card for PrefsNode of kind " & $node.kind)

proc incl*(node: var PrefsNode, ele: char) = 
  node.getCharSet().incl ele

proc excl*(node: var PrefsNode, ele: char) = 
  node.getCharSet().excl ele

iterator items*(node: PrefsNode): PrefsNode = 
  for i in node.getSeq():
    yield i

iterator pairs*(node: PrefsNode): (string, PrefsNode) = 
  for k, v in node.getObject():
    yield (k, v)

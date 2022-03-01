import std/[strutils, strformat, sequtils, options, tables]
import npeg, npeg/codegen
import lexer, escaper

type
  PNestData = ref object
    inside*: bool
    child*: PrefsNode
    parent*: Option[PNestData]

  PParseData = object
    table*: PObjectType
    indentStack*: seq[int]
    objData*: PNestData
    seqData*: PNestData

proc initPNestData(inside: bool = false, child: PrefsNode = newPEmpty(),
    parent: Option[PNestData] = PNestData.none): PNestData =
  PNestData(inside: inside, child: child, parent: parent)

proc initPParseData(table: PObjectType = default PObjectType,
    seqData: PNestData = initPNestData(),
    objData: PNestData = initPNestData()
  ): PParseData =
  PParseData(table: table, indentStack: @[0], objData: objData,
      seqData: seqData)

#[
proc `$`(data: PNestData): string =
  &"inside={data.inside}\nchild={data.child}\nparent={data.parent.isSome}"

proc `$`(data: PParseData): string =
  &"table={data.table}\nindentStack={data.indentStack}\nobjData=>\n{indent($data.objData, 2)}\nseqData=>\n{indent($data.seqData, 2)}"
]#

proc `[]=`(data: var PParseData, key: string, val: PrefsNode) =
  data.table[key] = val

proc `==`(token: PToken, kind: PTokenKind): bool = token.kind == kind

proc `top`[A](list: openArray[A]): A =
  list[^1]

proc `top`[K, V](table: OrderedTable[K, V]): tuple[key: K, val: V] =
  (key: table.keys.toSeq[^1], val: table[table.keys.toSeq[^1]])

proc `top=`[K, V](table: var OrderedTable[K, V], val: V) =
  table[table.top.key] = val

proc `top`(data: PParseData): tuple[key: string, val: PrefsNode] =
  data.table.top

proc removeTypeSuf(num: string): string =
  result = num

  let idx = num.find('\'')
  if idx > -1:
    result = num[0..<idx]

proc parseInt(lexeme: string, kind: PTokenKind): PrefsNode =
  var lexeme = lexeme.removeTypeSuf()
  var num: int

  let negative = if lexeme.startsWith('-'): true else: false
  lexeme.removePrefix('-')

  if lexeme.len <= 1:
    num = lexeme.parseInt()
  else:
    case lexeme[0..1]
    of "0b": # Bin
      num = lexeme.parseBinInt()
    of "0x": # Hex
      num = lexeme.parseHexInt()
    of "0o": # Oct
      num = lexeme.parseOctInt()
    else:
      num = lexeme.parseInt()

  if negative:
    num = -num

  result = num.newPInt()

proc parseFloat(lexeme: string, kind: PTokenKind): PrefsNode =
  var lexeme = lexeme.removeTypeSuf()

  let negative = if lexeme.startsWith('-'): true else: false
  lexeme.removePrefix('-')

  if lexeme.len <= 1:
    result = lexeme.parseFloat().newPFloat()
  else:
    var num: float

    case lexeme[0..1]
    of "0b": # Bin
      num = cast[float](lexeme.parseBinInt)
    of "0x": # Hex
      num = cast[float](lexeme.parseHexInt)
    of "0o": # Oct
      num = cast[float](lexeme.parseOctInt)
    else:
      num = lexeme.parseFloat()

    if negative:
      num = -num

    result = num.newPFloat()

proc parseVal(token: PToken): PrefsNode =
  case token.kind
  of DEC, BIN, OCT, HEX:
    result = token.lexeme.parseInt(token.kind)
  of FLOAT, FLOAT32, FLOAT64:
    result = token.lexeme.parseFloat(token.kind)
  of BOOL:
    result = token.lexeme.parseBool().newPBool()
  of CHAR:
    result = token.lexeme[1..^2].parseEscapedChar().newPChar()
  of STRING:
    result = token.lexeme[1..^2].parseEscaped().newPString()
  of RAWSTRING:
    result = token.lexeme[2..^2].newPString()
  of EMPTYOBJ:
    result = newPObject()
  else:
    echo &"Unkown token {token.lexeme} of {token.kind}"
    result = newPEmpty()

proc addToTable(data: var PParseData, key: string, val: PrefsNode) =
  let key = key.strip()

  if data.objData.inside:
    data.objData.child[key] = val
  else:
    data[key] = val

proc addToTable(data: var PParseData, key: string, val: PToken) =
  if val.kind == SEQOPEN:
    data.addToTable(key, data.seqData.child)
  else:
    data.addToTable(key, parseVal(val))

proc closeSeq(data: var PParseData) =
  if data.seqData.parent.isSome:
    data.seqData.parent.get().child.seqV.add data.seqData.child
    data.seqData = data.seqData.parent.get()
    data.seqData.inside = true
  else:
    data.seqData.inside = false

proc closeObj(data: var PParseData) =
  if data.objData.parent.isSome:
    data.objData.parent.get().child.objectV.top = data.objData.child
    data.objData = data.objData.parent.get()
    data.objData.inside = true
  else:
    data.objData.inside = false
    data.addToTable(data.top.key, data.objData.child)

proc indOut(data: var PParseData, ind: int, pos: PTokenPos) =
  for i in countdown(data.indentStack.high, 0):
    if ind < data.indentStack[i]:
      data.closeObj()
      data.indentStack.pop()
    elif ind == data.indentStack[i]:
      break
    else:
      raise newException(SyntaxError, &"Invalid indentation at {pos.line}:{pos.col} (#{pos.idx}), found {ind}, expected {data.indentStack[i]} or {data.indentStack[i+1]}")

let parser = peg(content, PToken, data: PParseData):
  spaced(rule) <- *[INDEN] * rule * *[INDEN]

  content <- *token
  token <- ?[INDEN] * [NL] | obj | pair
  
  endLn <- [NL] | "":
    if ($0).kind notin [NL, EOF]:
      let lexeme = ($0).lexeme
      let pos = ($0).pos
      raise newException(SyntaxError, &"Expected new line or end of the file at {pos.line}:{pos.col} (#{pos.idx}), found \"{lexeme}\"")

  pair <- indSame * >[KEY] * spaced(sep) * >(val | E"value") * endLn:
    data.addToTable(($1).lexeme, $2)

  objOpen <- indSame * >[KEY] * spaced(sep) * [GREATER]:
    data.addToTable(($1).lexeme, newPObject())

  obj <- objOpen * ([NL] | E"new line") * *[NL] * (
      indIn | E"indentation in") * (+token | E"one or more pairs")

  indSame <- [INDEN] | "":
    var ind = ($0).lexeme.len
    if ($0).kind == KEY: # A KEY would mean zero indentation
      ind = 0
    elif ($0).kind != INDEN: # Otherwise is invalid
      fail

    if ind < data.indentStack.top: # Object close
      data.indOut(ind, ($0).pos)

    elif ind != data.indentStack.top:
      let pos = ($0).pos
      raise newException(SyntaxError, &"Invalid indentation at {pos.line}:{pos.col} (#{pos.idx}), found {ind}, expected {data.indentStack.top}")

  indIn <- &[INDEN]:
    validate ($0).lexeme.len > data.indentStack.top
    data.indentStack.add ($0).lexeme.len

    if data.objData.inside:
      data.objData.parent = initPNestData(parent = data.objData.parent, child = data.objData.child).some

    data.objData.inside = true
    data.objData.child = newPObject()

  sep <- [EQUAL] | E"separator '='"
  seqOpen <- [SEQOPEN]:
    if data.seqData.inside:
      data.seqData.parent = initPNestData(parent = data.seqData.parent, child = data.seqData.child).some

    data.seqData.child = newPSeq()
    data.seqData.inside = true

  seqClose <- [SEQCLOSE] | E"sequence close":
    data.closeSeq()

  seqVal <- val:
    if ($0).kind != SEQOPEN:
      data.seqData.child.seqV.add parseVal($0)

  SEQ <- seqOpen * *seqVal * seqClose

  val <- [NIL] | [BOOL] | [CHAR] | [OBJECT] | [EMPTYOBJ] | [STRING] | [
      RAWSTRING] | [DEC] | [HEX] | [BIN] | [OCT] | [FLOAT] | [FLOAT32] | [
          FLOAT64] | SEQ

proc parsePrefs*(tokens: seq[PToken]): PObjectType =
  var data = initPParseData()
  var output: MatchResult[PToken]

  try:
    output = parser.match(tokens, data)
  except NPegException as error:
    let pos = tokens[error.matchLen].pos
    raise newException(SyntaxError, getCurrentExceptionMsg() &
        fmt" (line: {pos.line}, col: {pos.col})")

  while data.objData.inside: # Unterminated object
    data.closeObj()

  result = data.table

  if not output.ok:
    let pos = tokens[output.matchLen].pos
    raise newException(SyntaxError, &"Error while parsing at {pos.line}:{pos.col} (#{pos.idx}), parsed table: {result}")

proc parsePrefs*(source: string): PObjectType =
  ## Parse a string as a NiPrefs file.
  parsePrefs(source.scanPrefs().stack)

proc readPrefs*(path: string): PObjectType =
  ## Read a file and parse it.
  parsePrefs(path.scanPrefsFile().stack)

import std/[strutils, strformat, sequtils, options, tables]
import npeg, npeg/codegen
import lexer, escaper

type
  PNestData = ref object ## Data used to parse nested (structured) data types.
    inside*: bool
    child*: PrefsNode
    parent*: Option[PNestData]

  PParseData = object ## Data used when parsing.
    table*: PObjectType
    indentStack*: seq[int]
    objData*: PNestData
    tableData*: seq[PrefsNode]
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
  &"table={data.table}\nindentStack={data.indentStack}\ntableData={data.tableData}\nobjData=>\n{indent($data.objData, 2)}\nseqData=>\n{indent($data.seqData, 2)}"
]#

template `top`(data: PParseData): tuple[key: string, val: PrefsNode] =
  ## Alias for `data.table.top`.
  data.table.top

template `top`[A](list: openArray[A]): A =
  ## Top (last element) of an openArray.
  list[^1]

proc `==`(token: PToken, kind: PTokenKind): bool = token.kind == kind

proc `top`[K, V](table: OrderedTable[K, V]): tuple[key: K, val: V] =
  ## Get the last key and value from an ordered table.
  let lastKey = table.keys.toSeq[^1]
  (key: lastKey, val: table[lastKey])

proc `top=`[K, V](table: var OrderedTable[K, V], val: V) =
  ## Change the last key of an ordered table.
  table[table.top.key] = val

proc removeTypeSuf(num: string): string =
  ## Remove the type suffix from a string.
  result = num

  let idx = num.find('\'')
  if idx > -1:
    result = num[0..<idx]

proc parseInt(lexeme: string, kind: PTokenKind): PrefsNode =
  ## Parse an string representation of an integer.

  var
    lexeme = lexeme.removeTypeSuf()
    num: int

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
  ## Parse an string representation of a float.
  
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
  ## Parses a token to get an actual PrefsNode.

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
  else:
    raise newException(SyntaxError, &"Unkown token {token.lexeme} of {token.kind} at {token.pos}")

proc add(data: var PParseData, key: string, val: PrefsNode) =
  ## Add key an val to `data.table` or to `data.objData.child` depending on `data.objData.inside`.
  let key = key.strip()

  if data.objData.inside:
    data.objData.child[key] = val
  else:
    data.table[key] = val

proc add(data: var PParseData, key: string, val: PToken) =
  ## Same as [add](#add%2CPParseData%2Cstring%2CPrefsNode) but calling [parseVal](#parseVal%2CPToken) on `val`.

  var value: PrefsNode
  case val.kind
  of SEQOPEN:
    value = data.seqData.child
  of TABLEOPEN:
    value = data.tableData.pop()
  else:
    value = parseVal(val)

  data.add(key, value)

proc addToTable(data: var PParseData, key: string, val: PrefsNode) = 
  let key = key.strip()
  data.tableData.top.objectV[key] = val

proc addToTable(data: var PParseData, key: string, val: PToken) = 
  var value: PrefsNode
  case val.kind
  of SEQOPEN:
    value = data.seqData.child
  of TABLEOPEN:
    value = data.tableData.pop()
  else:
    value = parseVal(val)

  data.addToTable(key, value)

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
    data.add(data.top.key, data.objData.child)

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
  items(rule) <- ?(rule * *([COMMA] * rule) * ?[COMMA])
  invalidVal <- &1:
    let token = $0
    raise newException(SyntaxError, &"Expected value at {token.pos.line}:{token.pos.col} found \"{token.lexeme}\"")

  content <- *token
  token <- ?[INDEN] * [NL] | obj | pair
  key <- [KEY]
  sep <- [EQUAL] | E"separator '='"
  endLn <- [NL] | &1:
    if ($0).kind notin [NL, EOF]:
      let lexeme = ($0).lexeme
      let pos = ($0).pos
      raise newException(SyntaxError, &"Expected new line or end of the file at {pos.line}:{pos.col} (#{pos.idx}), found \"{lexeme}\"")

  pair <- indSame * >key * spaced(sep) * (>val | invalidVal) * endLn:
    data.add(($1).lexeme, $2)

  objOpen <- indSame * >key * spaced(sep) * [GREATER]:
    data.add(($1).lexeme, newPObject())

  obj <- objOpen * ([NL] | E"new line") * *[NL] * (
      indIn | E"indentation in") * (+token | E"one or more pairs")

  indSame <- [INDEN] | &1:
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

  emptyTable <- [TABLEOPEN] * ?[COLON] * [TABLECLOSE]:
    data.tableData.add newPObject()

  tableOpen <- [TABLEOPEN]:
    data.tableData.add newPObject()

  tableClose <- [TABLECLOSE]  
  tableVal <- val | invalidVal
  tablePair <- >[STRING] * ([COLON] | E"colon") * >tableVal:
    let key = ($1).lexeme[1..^2].parseEscaped()

    if ($2).kind == TABLEOPEN:
      data.addToTable(key, data.tableData.pop())
    else:
      data.addToTable(key, $2)

  table <- tableOpen * items(tablePair) * tableClose
  seqOpen <- [SEQOPEN]:
    if data.seqData.inside:
      data.seqData.parent = initPNestData(parent = data.seqData.parent, child = data.seqData.child).some

    data.seqData.child = newPSeq()
    data.seqData.inside = true

  seqClose <- [SEQCLOSE] | E"sequence close":
    data.closeSeq()

  seqVal <- val | E"value":
    if ($0).kind == TABLEOPEN:
      data.seqData.child.seqV.add data.tableData.pop()
    elif ($0).kind != SEQOPEN:
      data.seqData.child.seqV.add parseVal($0)
  
  SEQ <- seqOpen * items(seqVal) * seqClose

  val <- [NIL] | [BOOL] | [CHAR] | [OBJECT] | [STRING] | [
      RAWSTRING] | [DEC] | [HEX] | [BIN] | [OCT] | [FLOAT] | [FLOAT32] | [
          FLOAT64] | SEQ | emptyTable | table

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
  runnableExamples:
    import niprefs
    import std/strutils

    let text = """
    #NiPrefs
    lang="en"
    dark=true
    """.dedent()

    assert text.parsePrefs() == toPrefs({"lang": "en", "dark": true}).getObject()

  parsePrefs(source.scanPrefs().stack)

proc readPrefs*(path: string): PObjectType =
  ## Read a file and parse it.
  
  parsePrefs(path.scanPrefsFile().stack)

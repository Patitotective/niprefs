import std/[strutils, strformat, sequtils, options, tables]
import npeg, npeg/codegen
import lexer, escaper

type
  PParseData = object ## Data used when parsing.
    table*: PObjectType
    indentStack*: seq[int]
    inObj*: bool
    tableData*: seq[PrefsNode]
    seqData*: seq[PrefsNode]
    inSet*: PrefsKind # PEmpty meaning no
    charSetData*: set[char]
    byteSetData*: set[byte]

proc initPParseData(table: PObjectType = default PObjectType): PParseData =
  PParseData(table: table, indentStack: @[0])

# proc `$`(data: PParseData): string =
#   &"table={data.table}\nindentStack={data.indentStack}\nseqData={data.seqData}\ntableData={data.tableData}\ninObj={data.inObj}"

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
  ## 13f -> 13
  ## 69'd64 -> 69

  for i in num:
    if i.isDigit() or i == '-' or i == '.':
      result.add i
    else:
      break

proc parseInt(token: PToken): PrefsNode =
  ## Parse an string representation of an integer.

  var
    lex = token.lex.removeTypeSuf()
    num: int

  let negative = if lex.startsWith('-'): true else: false
  lex.removePrefix('-')

  if lex.len <= 1:
    num = lex.parseInt()
  else:
    case lex[0..1]
    of "0b": # Bin
      num = lex.parseBinInt()
    of "0x": # Hex
      num = lex.parseHexInt()
    of "0o": # Oct
      num = lex.parseOctInt()
    else:
      num = lex.parseInt()

  if negative:
    num = -num

  result = num.newPInt()

proc parseFloat(token: PToken): PrefsNode =
  ## Parse an string representation of a float.
  
  var lex = token.lex.removeTypeSuf()

  let negative = if lex.startsWith('-'): true else: false
  lex.removePrefix('-')

  if lex.len <= 1:
    result = lex.parseFloat().newPFloat()
  else:
    var num: float

    case lex[0..1]
    of "0b": # Bin
      num = cast[float](lex.parseBinInt)
    of "0x": # Hex
      num = cast[float](lex.parseHexInt)
    of "0o": # Oct
      num = cast[float](lex.parseOctInt)
    else:
      num = lex.parseFloat()

    if negative:
      num = -num

    result = num.newPFloat()

proc parseVal(token: PToken): PrefsNode =
  ## Parses a token to get an actual PrefsNode.

  case token.kind
  of DEC, BIN, OCT, HEX:
    result = token.parseInt()
  of FLOAT, FLOAT32, FLOAT64:
    result = token.parseFloat()
  of BOOL:
    result = token.lex.parseBool().newPBool()
  of CHAR:
    result = token.lex[1..^2].parseEscapedChar().newPChar()
  of STRING:
    result = token.lex[1..^2].parseEscaped().newPString()
  of RAWSTRING:
    result = token.lex[2..^2].newPString()
  else:
    raise newException(SyntaxError, &"Unkown token {token.lex} of {token.kind} at {token.pos}")

proc add(data: var PParseData, key: string, val: PrefsNode) =
  ## Add key an val to `data.table` or to `data.tableData.child` depending on `data.tableData.inside`.
  let key = key.strip()

  if data.inObj:
    data.tableData.top[key] = val
  else:
    data.table[key] = val

proc add(data: var PParseData, key: string, val: PToken) =
  ## Same as [add](#add%2CPParseData%2Cstring%2CPrefsNode) but calling [parseVal](#parseVal%2CPToken) on `val`.
  var value: PrefsNode
  case val.kind
  of SEQOPEN:
    value = data.seqData.pop()
  of CURLYOPEN:
    if data.inSet == PCharSet:
      value = data.charSetData.newPCharSet()
      data.charSetData = {}
    elif data.inSet == PByteSet:
      value = data.byteSetData.newPByteSet()
      data.byteSetData = {}
    else:
      value = data.tableData.pop()
    data.inSet = PEmpty
  else:
    value = parseVal(val)

  data.add(key, value)

proc addToTable(data: var PParseData, key: string, val: PToken) = 
  let key = key.strip()
  var toAdd: PrefsNode

  case val.kind
  of SEQOPEN:
    toAdd = data.seqData.pop()
  of CURLYOPEN:
    toAdd = data.tableData.pop()
  else:
    toAdd = parseVal(val)

  data.tableData.top.objectV[key] = toAdd

proc addToSeq(data: var PParseData, val: PToken) = 
  var toAdd: PrefsNode
  case val.kind
  of SEQOPEN:
    toAdd = data.seqData.pop()
  of CURLYOPEN:
    if data.inSet == PCharSet:
      toAdd = data.charSetData.newPCharSet()
      data.charSetData = {}
    elif data.inSet == PByteSet:
      toAdd = data.byteSetData.newPByteSet()
      data.byteSetData = {}
    else:
      toAdd = data.tableData.pop()
    data.inSet = PEmpty
  else:
    toAdd = parseVal(val)

  data.seqData.top.seqV.add toAdd

proc closeObj(data: var PParseData) =
  if data.tableData.len >= 2:
    data.tableData[^2].objectV.top = data.tableData.pop()
  else:
    data.inObj = false
    data.add(data.top.key, data.tableData.pop())

proc indenOut(data: var PParseData, ind: int, pos: PTokenPos) =
  for i in countdown(data.indentStack.high, 0):
    if ind < data.indentStack[i]:
      data.closeObj()
      data.indentStack.pop()
    elif ind == data.indentStack[i]:
      break
    else:
      raise newException(SyntaxError, &"Invalid indentation at {pos.line}:{pos.col} (#{pos.idx}), found {ind}, expected {data.indentStack[i]} or {data.indentStack[i+1]}")

const parser = peg(content, PToken, data: PParseData):
  spaced(rule) <- *[SPACE] * rule * *[SPACE]
  items(rule) <- ?spaced(rule * *(spaced([COMMA]) * spaced(rule)) * ?spaced([COMMA]))
  invalidVal <- &1:
    let token = $0
    raise newException(SyntaxError, &"Expected value at {token.pos.line}:{token.pos.col} found \"{token.lex}\"")

  content <- *token
  token <- ?[SPACE] * [NL] | obj | pair

  sep <- [EQUAL] | E"separator ="
  endLn <- [NL] | &1:
    if ($0).kind notin [NL, EOF]:
      let
        lex = ($0).lex
        pos = ($0).pos
      raise newException(SyntaxError, &"Expected new line or end of the file at {pos.line}:{pos.col} (#{pos.idx}), found \"{lex}\"")

  pair <- indSame * (>[IDEN] | E"key") * spaced(sep) * (>val | invalidVal) * endLn:
    data.add(($1).lex, $2)

  # Objects
  objOpen <- indSame * >[IDEN] * spaced(sep) * [GREATER]:
    data.add(($1).lex, newPObject())

  obj <- objOpen * ([NL] | E"new line") * *[NL] * (
      indIn | E"indentation in") * (+token | E"one or more pairs")

  indSame <- [SPACE] | &1:
    var ind = ($0).lex.len
    if ($0).kind == IDEN: # A KEY would mean zero indentation
      ind = 0
    elif ($0).kind != SPACE: # Otherwise is invalid
      fail

    if ind < data.indentStack.top: # Object close
      data.indenOut(ind, ($0).pos)
    
    elif ind != data.indentStack.top: # Error
      let pos = ($0).pos
      raise newException(SyntaxError, &"Invalid indentation at {pos.line}:{pos.col} (#{pos.idx}), found {ind}, expected {data.indentStack.top}")

  indIn <- &[SPACE]:
    validate ($0).lex.len > data.indentStack.top
    data.indentStack.add ($0).lex.len

    data.inObj = true
    data.tableData.add newPObject()

  # Sets
  emtpySetErr <- [CURLYOPEN] * [CURLYCLOSE]:
    raise newException(SyntaxError, "Ambiguous set, use {c} (PCharSet) or {b} (PByteSet)")

  emtpySet <- [CURLYOPEN] * >spaced([IDEN]) * [CURLYCLOSE]:
    if ($1).lex == "c":
      data.inSet = PCharSet
    elif ($1).lex == "b":
      data.inSet = PByteSet
    else:
      let
        lex = ($1).lex
        pos = ($1).pos

      raise newException(SyntaxError, &"Expected 'c' (PCharSet) or 'b' (PByteSet), got \"{lex}\" at {pos.line}:{pos.col}")

  charRange <- >[CHAR] * [DOT] * [DOT] * >[CHAR]:
    data.charSetData.incl {($1).lex[1..^2].parseEscapedChar()..($2).lex[1..^2].parseEscapedChar()}

  charSetV <- [CHAR]:
    data.charSetData.incl ($0).lex[1..^2].parseEscapedChar()

  charSet <- [CURLYOPEN] * items(charRange | charSetV) * [CURLYCLOSE]:
    data.inSet = PCharSet

  byteV <- [DEC] | [HEX] | [BIN] | [OCT]

  byteRange <- >byteV * [DOT] * [DOT] * >byteV:
    data.byteSetData.incl {parseInt($1).getInt().byte .. parseInt($2).getInt().byte}

  byteSetV <- byteV:
    data.byteSetData.incl parseInt($0).getInt().byte

  byteSet <- [CURLYOPEN] * items(byteRange | byteSetV) * [CURLYCLOSE]:
    data.inSet = PByteSet

  # Tables
  emptyTable <- [CURLYOPEN] * [COLON] * [CURLYCLOSE]:
    data.tableData.add newPObject()

  CURLYOPEN <- [CURLYOPEN]:
    data.tableData.add newPObject()

  tableVal <- val | invalidVal
  tablePair <- >[STRING] * spaced([COLON] | E"colon") * >tableVal:
    let key = ($1).lex[1..^2]
    data.addToTable(key, $2)

  table <- CURLYOPEN * items(tablePair) * ([CURLYCLOSE] | E"table close")

  # Sequences
  emptySeq <- [SEQOPEN] * [SEQCLOSE]:
    data.seqData.add newPSeq()

  seqOpen <- [SEQOPEN]:
    data.seqData.add newPSeq()

  seqClose <- [SEQCLOSE] | E"sequence close"
  seqVal <- val:
    data.addToSeq $0

  SEQ <- seqOpen * items(seqVal) * seqClose

  val <- [NIL] | [BOOL] | [CHAR] | [STRING] | [
      RAWSTRING] | [DEC] | [HEX] | [BIN] | [OCT] | [FLOAT] | [FLOAT32] | [
          FLOAT64] | emptySeq | SEQ | emtpySetErr | emtpySet | charSet | byteSet | emptyTable | table

proc parsePrefs*(tokens: seq[PToken]): PObjectType =
  var data = initPParseData()
  var output: MatchResult[PToken]

  try:
    output = parser.match(tokens, data)
  except NPegException as error:
    let pos = tokens[error.matchLen].pos
    raise newException(SyntaxError, getCurrentExceptionMsg() &
        fmt" (line: {pos.line}, col: {pos.col})")

  while data.inObj: # Unterminated object
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

import std/[strutils, strformat, parseutils, sequtils, options]
import npeg
import prefsnode, escaper

type
  SyntaxError* = object of ValueError

  PNestData = ref object
    parent*: Option[PNestData]
    child*: PrefsNode

  PParseData = object
    table*: PObjectType
    indentLevel*: int
    inObj*: bool
    inSeq*: bool
    objData*: PNestData
    seqData*: PNestData

const
  commentChar* = '#'                   ## The character to comment with.
  firstLine* = &"{commentChar}NiPrefs" ## First line when writing a *prefs* file.
  sepChar* = '=' ## The character used to separate a key-val pair when writing a *prefs* file.
  endChar* = '\n'                      ## The character to end a key-val pair.
  continueChar* = '>'                  ## The character used to indicate a nested table.
  indentChar* = ' '.repeat 2           ## The character used to indent.
  keyPathSep* = '/'                    ## The character to separate a *key path*.
  invalidKeyChars* = [sepChar, commentChar, continueChar,
      keyPathSep]                      ## Invalid characters to use in a key.
  autoGenKeys* = true                  ## Auto generate keys when accessing to a nested table.

proc initPNestData(parent: Option[PNestData] = none(PNestData),
    child: PrefsNode): PNestData =
  PNestData(parent: parent, child: child)

proc initPParseData(table: PObjectType = default PObjectType,
    pseqdata: PNestData = initPNestData(child = newPSeq()),
    pobjdata: PNestData = initPNestData(child = newPObject())
  ): PParseData =
  PParseData(table: table, indentLevel: 0, inObj: false, inSeq: false,
      objData: pobjdata, seqData: pseqdata)

proc checkKey*(key: string) =
  ## Raises an exception if `key` contains any of the `invalidKeyChars`.
  if invalidKeyChars.anyIt(it in key):
    raise newException(KeyError, &"Invalid key \"{key}\" (it must not contain {invalidKeyChars})")

proc removeTypeSuf(str: var string) =
  ## Gets the type suffix in the string, returns it and removes it from `str`
  ## Nothing happens if `'` wasn't fount
  let indx = str.find('\'')
  if indx > -1:
    # echo str[indx..<str.len]
    str = str[0..<indx]

template top[K, V](table: OrderedTable[K, V]): tuple[key: K, val: V] =
  (key: table.keys.toSeq[^1], val: table[table.keys.toSeq[^1]])

template `top=`[K, V](table: OrderedTable[K, V], val: V) = table[
    table.keys.toSeq[^1]] = val

proc addToTable(data: var PParseData, node: PrefsNode) =
  if data.inSeq:
    data.seqData.child.seqV.add node
  elif data.inObj:
    data.objData.child.objectV.top = node
  else:
    data.table.top = node

grammar "number":
  minus <- '-'
  octdigit <- {'0'..'7'}
  bindigit <- {'0'..'1'}
  nums <- Digit * *(?'_' * Digit)
  exponent <- i"e" * ('+' | '-') * nums

  iSuffix <- i"i" * ("8" |
      "16" | "32" | "64")
  uSuffix <- i"u" * ?("8" |
      "16" | "32" | "64")
  typeSuffix <- '\'' * (uSuffix | iSuffix)
  f32Suffix <- i"f" * ?"32"
  f64Suffix <- i"f64" | i"d"
  fSuffix <- f32Suffix | f64Suffix

  Hex <- ?minus * '0' * i"x" * Xdigit * *(?'_' * Xdigit):
    var num: int
    discard parseHex($0, num)
    data.addToTable newPInt(num)

  Dec <- ?minus * nums
  Oct <- ?minus * '0' * 'o' * octdigit * *(?'_' * octdigit)
  Bin <- ?minus * '0' * i"b" * bindigit * *(?'_' * bindigit)

  Float <- ?minus * nums * (('.' * nums * ?exponent) | exponent)

  Float32 <- Hex * '\'' * f32Suffix |
    (Float | Oct | Bin | Dec) * '\'' * f32Suffix

  Float64 <- Hex * '\'' * f64Suffix |
    (Float | Oct | Bin | Dec) * '\'' * f64Suffix

grammar "str":
  escapeSeq <- 'r' | 'c' | 'n' | 'l' | 'f' | 't' | 'v' | '\\' | '"' | '\'' | +Digit |
    'a' | 'b' | 'e' | ('x' * Xdigit[2])
  escape <- '\\' * ('p' | escapeSeq | ('u' * Xdigit[4]) | ('u' * '{' * +Xdigit * '}'))
  escapeChar <- '\\' * escapeSeq
  charBody <- escapeChar | {0..255}
  strBody <- ?escape * *( +( {'\x20'..'\xff'} - {'"'} - {'\\'}) * *escape)
  rawStrBody <- *( +( {'\x20'..'\xff'} - {'"'}) | "\"\"")

let parser = peg("start", data: PParseData):
  newLine <- '\n'
  S <- Space - newLine
  sepChar <- '='
  commentChar <- '#'
  continueChar <- '>'
  indentChar <- ' ' | '\t'
  comment <- commentChar * *(1 - newLine):
    echo $0

  emptyLn <- *S * ?comment * newLine
  endLn <- *S * ?comment * (newLine | !1)

  pnil <- "nil":
    data.addToTable newPNil()

  spaced(rule) <- *S * rule * *S
  isolated(rule) <- *emptyLn * rule * *emptyLn
  commented(rule) <- rule * *S * ?comment

  pbool <- "true" | "false":
    data.addToTable newPBool(parseBool($0))

  pint <- (number.Hex | number.Bin | number.Oct | number.Dec) *
      ?number.typeSuffix: # To avoid conflicts with pfloat
    var num: int
    var str = $0 # Int string

    let negative = str.startsWith('-')
    str.removePrefix('-')

    str.removeTypeSuf()

    if str.startsWith("0b"):
      num = str.parseBinInt()
    elif str.startsWith("0x"):
      num = str.parseHexInt()
    elif str.startsWith("0o"):
      num = str.parseOctInt()
    else:
      num = str.parseInt()

    if negative:
      num = 0 - num

    data.addToTable newPInt(num)

  pfloat <- number.Float | number.Float32 | number.Float64:
    var num: float
    var str = $0 # Float string

    let negative = str.startsWith('-')
    str.removePrefix('-')

    str.removeTypeSuf()

    if str.startsWith("0b"):
      num = cast[float](str.parseBinInt)
    elif str.startsWith("0x"):
      num = cast[float](str.parseHexInt)
    elif str.startsWith("0o"):
      num = cast[float](str.parseOctInt)
    else:
      num = str.parseFloat()

    if negative:
      num = -num

    data.addToTable newPFloat(num)

  pchar <- '\'' * >str.charBody * '\'':
    data.addToTable newPChar(parseEscaped($1))

  pstring <- '"' * >str.strBody * '"':
    data.addToTable newPString(parseEscaped($1))

  prawstring <- i"r" * '"' * >str.rawStrBody * '"':
    data.addToTable newPString($1)

  # Sequences
  pseqOpen <- ?'@' * '[':
    if data.inSeq:
      data.seqData.parent = initPNestData(parent = data.seqData.parent,
          child = data.seqData.child).some()

    data.inSeq = true
    data.seqData.child = newPSeq()

  pseqClose <- ']' | E"sequence close ]":
    if data.seqData.parent.isSome:
      data.seqData.parent.get().child.seqV.add(data.seqData.child)
      data.seqData = data.seqData.parent.get()
    else:
      data.inSeq = false
      data.addToTable data.seqData.child

  seqItems <- val * *(*S * ',' * *S * val) * ?','
  pseq <- pseqOpen * *S * ?seqItems * *S * pseqClose

  # Objects
  indIn <- *indentChar:
    if len($0) <= data.indentLevel:
      let offset = @0
      let indentLevel = len($0)
      raise newException(SyntaxError, &"Invalid indentation-in at #{offset}, expected an indentation greater than {data.indentLevel} but got {indentLevel}")

    echo "Indentation in ", data.indentLevel, " -> ", len($0)

    data.indentLevel = len($0)

    if data.inObj:
      data.objData.parent = initPNestData(parent = data.objData.parent,
          child = data.objData.child).some()

    data.inObj = true
    data.objData.child = newPObject()

  indSame <- *indentChar:
    validate len($0) == data.indentLevel
    echo "Indentation same ", data.indentLevel
    #[
    if len($0) != data.indentLevel:
      let offset = @0
      let indentLevel = len($0)
      raise newException(SyntaxError, &"Invalid indentation at #{offset}, expected {data.indentLevel} but got {indentLevel}")
    ]#

  indOut <- *indentChar:
    validate len($0) <= data.indentLevel
    echo "Indentation out ", data.indentLevel, " -> ", len($0)

    data.indentLevel = len($0)
    echo data

    if data.objData.parent.isSome:
      data.objData.parent.get().child.objectV.top = data.objData.child
      data.objData = data.objData.parent.get()
    else:
      data.inObj = false
      data.addToTable data.objData.child

  pobject <- commented(continueChar) * +emptyLn * &indIn * content * &((
      emptyLn | !1) * indOut)

  pemtpyobj <- '{' * *S * ?':' * *S * '}':
    data.addToTable newPObject()

  key <- +(1 - (sepChar | newLine)):
    let key = strip($0)
    checkKey(key)

    if data.inObj:
      data.objData.child[key] = newPEmpty()
    else:
      data.table[key] = newPEmpty()

  val <- pfloat | pint | pnil | pseq | pbool |
      pchar | prawstring | pstring | pemtpyobj |
      E"one of float, int, nil, sequence, bool, char, string or object"

  pair <- indSame * key * spaced(sepChar | E"separator =") * (
      pobject | commented(val) * endLn)

  content <- (*emptyLn * pair)
  start <- content * !1

proc parsePrefs*(str: string): PObjectType =
  ## Parse the given string as *Prefs* format.
  ## Any variation of int or float (uint, int8, float32, etc.) is implicitly converted to int and float, respectly.

  var data = initPParseData()
  let output = parser.match(str.strip(), data)
  result = data.table

  if not output.ok:
    raise newException(SyntaxError, &"Error while parsing {output}, parsed table: {result}")

proc readPrefs*(path: string): PObjectType =
  ## Reads the file at `path` and parses it.
  parsePrefs(readFile(path))

echo readPrefs("prefs.niprefs")

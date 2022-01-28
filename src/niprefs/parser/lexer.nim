import std/[strutils, strformat]
import npeg

type
  PValKind = enum
    NIL       # nil
    BOOL      # true or false
    CHAR      # 'a'
    OBJECT
    EMPTYOBJ  # {:} or {}
    STRING    # "hello"
    RAWSTRING # r"hello"

    DEC,      # Decimal int
    HEX,      # Hex int (0x)
    BIN,      # Bin int (0b)
    OCT,      # Oct int (0o)

    FLOAT,
    FLOAT32,
    FLOAT64

  PTokenKind = enum
    NL       # New line \n
    SEP      # =
    SEQOPEN  # @[ or [
    SEQCLOSE # ]

    KEY
    VAL
    GREATER  # >
    INDEN
    INDIN
    INDOUT

    EOF      # End Of File

  PToken = object
    case kind*: PTokenKind
    of VAL:
      valKind: PValKind
    else:
      discard

    lexeme*: string
    pos*: tuple[line: int, col: int, idx: int]

  PLexer = object
    ok*: bool # Successful
    matchLen*: int
    matchMax*: int
    stack*: seq[PToken]
    source*: string
    indentLevel*: int
    # lines*: seq[string] # Each element represents the length of each line

proc getPos(str: string, idx: int): tuple[line: int, col: int, idx: int] =
  ## Get the line:col position of `idx` in `str` adn returns a tuple with the line, col, idx.

  # Split the lines until `idx`
  let lines = str[0..<idx].splitLines(keepEol = true)
  result = (lines.len, lines[^1].len+1, idx+1)

proc `$`(lexer: PLexer): string =
  result.add &"{lexer.ok} {lexer.matchLen}/{lexer.matchMax}\n"

  for token in lexer.stack:
    result.add &"{token.lexeme.escape} "

    case token.kind
    of VAL:
      result.add &"{token.kind} ({token.valKind})"
    else:
      result.add &"{token.kind}"

    result.add &" at {token.pos.line}:{token.pos.col} (#{token.pos.idx})\n"

proc addToken(lexer: var PLexer, kind: PTokenKind, lexeme: string, idx: int) =
  let pos = lexer.source.getPos(idx)
  # echo &"{lexeme} of {kind} at {pos.line}:{pos.col}"
  lexer.stack.add PToken(kind: kind, lexeme: lexeme, pos: pos)

proc addToken(lexer: var PLexer, kind: PValKind, lexeme: string, idx: int) =
  let pos = lexer.source.getPos(idx)
  # echo &"{lexeme} of {kind} at {pos.line}:{pos.col}"
  lexer.stack.add PToken(kind: VAL, valKind: kind, lexeme: lexeme,
      pos: pos)

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
  # fSuffix <- f32Suffix | f64Suffix

  Hex <- ?minus * '0' * i"x" * Xdigit * *(?'_' * Xdigit)
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

let lexer = peg(tokens, data: PLexer):
  S <- Space - '\n'
  indentChar <- {' ', '\t'}
  spaced(rule) <- *S * rule * *S
  items(rule) <- ?spaced(rule * *(spaced(',') * rule) * ?',')

  tokens <- *token * EOF
  token <- *S * '\n' | pair

  EOF <- !1:
    data.addToken(EOF, $0, @0)

  comment <- '#' * *(1 - '\n')
  emptyLn <- *S * ?comment * endLn
  endLn <- newLn | !1
  newLn <- '\n':
    data.addToken(NL, $0, @0)

  pair <- inden * key * spaced(sep) * (obj | val * (emptyLn |
      E"new line or the end"))

  key <- +({'\x20'..'\xff'} - {'=', '\n', '#'}):
    data.addToken(KEY, $0, @0)

  sep <- '=' | E"separator '='":
    data.addToken(SEP, $0, @0)

  greater <- '>':
    data.addToken(GREATER, $0, @0)

  inden <- *indentChar * &1:
    data.addToken(INDEN, $0, @0)

  indin <- *indentChar:
    data.addToken(INDIN, $0, @0)

  indout <- *indentChar:
    data.addToken(INDOUT, $0, @0)

  obj <- greater * *S * ?comment * (newLn | E"new line") * &indin * (+token |
      E"one or more pairs") * &indout

  val <- (seq | num | char | bool | null | string | rawString | emptyObj |
      E"value") * *S * (comment | !(1 - '\n')) | E"only one value"

  null <- "nil":
    data.addToken(VAL, $0, @0)

  bool <- "true" | "false":
    data.addToken(BOOL, $0, @0)

  # Object
  emptyObj <- "{" * ?spaced(":") * "}":
    data.addToken(EMPTYOBJ, $0, @0)

  # Sequence
  seq <- seqOpen * items(val) * seqClose

  seqOpen <- ?"@" * "[":
    data.addToken(SEQOPEN, $0, @0)

  seqClose <- "]":
    data.addToken(SEQClOSE, $0, @0)

  # Strings and chars
  string <- '"' * str.strBody * '"':
    data.addToken(STRING, $0, @0)

  rawString <- i"r" * '"' * str.strBody * '"':
    data.addToken(RAWSTRING, $0, @0)

  char <- '\'' * str.charBody * '\'':
    data.addToken(CHAR, $0, @0)

  # Numbers
  num <- (float | float32 | float64) | int

  int <- dec | hex | oct | bin

  dec <- number.Dec:
    data.addToken(DEC, $0, @0)

  hex <- number.Hex:
    data.addToken(HEX, $0, @0)

  oct <- number.Oct:
    data.addToken(OCT, $0, @0)

  bin <- number.Bin:
    data.addToken(BIN, $0, @0)

  float <- number.Float:
    data.addToken(FLOAT, $0, @0)

  float32 <- number.Float32:
    data.addToken(FLOAT32, $0, @0)

  float64 <- number.Float64:
    data.addToken(FLOAT64, $0, @0)

proc scanPrefs(source: string): PLexer =
  result.source = source

  let output = lexer.match(source, result)

  result.ok = output.ok
  result.matchLen = output.matchLen
  result.matchMax = output.matchMax

proc readPrefs(path: string): PLexer =
  scanPrefs(readFile(path))

let result = readPrefs("prefs.niprefs")
echo result

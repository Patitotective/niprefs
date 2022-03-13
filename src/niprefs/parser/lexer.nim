import std/[strutils, strformat]
import npeg
import ../prefsnode
export prefsnode

type
  SyntaxError* = object of ValueError
  PTokenKind* = enum
    NL ## New line \n
    GREATER ## >
    EQUAL ## =
    COMMA ## ,
    COLON ## :
    SEQOPEN ## @[ or [
    SEQCLOSE ## ]
    TABLEOPEN ## {
    TABLECLOSE ## }

    KEY
    INDEN ## One or more spaces/tabs

    # Values
    NIL ## nil
    BOOL ## true or false
    CHAR ## 'a'
    OBJECT
    STRING ## "hello"
    RAWSTRING ## r"hello"

    # Numbers
    DEC ## Decimal int
    HEX ## Hex int (0x)
    BIN ## Bin int (0b)
    OCT ## Oct int (0o)

    FLOAT
    FLOAT32
    FLOAT64

    EOF # End Of File

  PTokenPos* = tuple[line: int, col: int, idx: int] ## Position of a token in the source string
  PToken* = object
    kind*: PTokenKind
    lexeme*: string
    pos*: PTokenPos

  PLexer = object ## Data used when scanning
    ok*: bool # Successful
    matchLen*: int
    matchMax*: int
    stack*: seq[PToken]
    source*: string
    indentLevel*: int


proc `$`*(lexer: PLexer): string =
  result.add &"{lexer.ok} {lexer.matchLen}/{lexer.matchMax}\n"
  
  for token in lexer.stack:
    case token.kind
    of NL:
      result.add "\n"
    of INDEN:
      result.add '-'.repeat(token.lexeme.len)
      result.add ' '
    else:
      result.add &"{token.kind} "


proc getPos(str: string, idx: int): PTokenPos =
  ## Get the line:col position of `idx` in `str` adn returns a tuple with the line, col, idx.

  # Split the lines until `idx`
  let lines = str[0..<idx].splitLines(keepEol = true)

  result = (lines.len, lines[^1].len+1, idx+1)

proc addToken(lexer: var PLexer, kind: PTokenKind, lexeme: string, idx: int) =
  let pos = lexer.source.getPos(idx)
  lexer.stack.add PToken(kind: kind, lexeme: lexeme, pos: pos)

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
  strChars <- {'\x20'..'\xff'} - {'"'} - {'\\'} # String valid characters
  rawStrChars <- {'\x20'..'\xff'} - {'"'} # Raw string valid characters
  charBody <- escapeChar | {0..255}
  strBody <- ?escape * *(+strChars * *escape)
  rawStrBody <- *("\"\"" | rawStrChars)

let lexer = peg(tokens, data: PLexer):
  S <- Space - '\n'
  indentChar <- {' ', '\t'}
  spaced(rule) <- *S * rule * *S
  items(rule) <- ?spaced(rule * *(spaced(comma) * rule) * ?comma)

  tokens <- *token * EOF
  token <- sep | greater | val | comment | inden | newLn | key | error

  EOF <- !1:
    data.addToken(EOF, $0, @0)

  error <- 1:
    let pos = data.source.getPos(@0)
    raise newException(SyntaxError, &"Unexpected character at {pos.line}:{pos.col} (#{pos.idx})")

  comment <- *S * '#' * *(1 - '\n')
  newLn <- '\n':
    data.addToken(NL, $0, @0)

  key <- +({'\x20'..'\xff'} - {'\n', '#', '/', '='}):
    data.addToken(KEY, $0, @0)

  sep <- '=':
    data.addToken(EQUAL, $0, @0)

  greater <- '>':
    data.addToken(GREATER, $0, @0)

  comma <- ',':
    data.addToken(COMMA, $0, @0)

  colon <- ':':
    data.addToken(COLON, $0, @0)

  inden <- +indentChar:
    data.addToken(INDEN, $0, @0)

  val <- seq | table | num | char | bool | null | string | rawString

  null <- "nil":
    data.addToken(NIL, $0, @0)

  bool <- "true" | "false":
    data.addToken(BOOL, $0, @0)

  # Table
  table <- tableOpen * spaced(colon | items(tablePair)) * tableClose

  tableOpen <- "{":
    data.addToken(TABLEOPEN, $0, @0)

  tableClose <- "}":
    data.addToken(TABLECLOSE, $0, @0)

  tablePair <- string * spaced(colon) * val

  # Sequences
  seq <- seqOpen * spaced(items(val)) * seqClose

  seqOpen <- ?"@" * "[":
    data.addToken(SEQOPEN, $0, @0)

  seqClose <- "]":
    data.addToken(SEQCLOSE, $0, @0)

  # Strings and chars
  string <- '"' * str.strBody * '"':
    data.addToken(STRING, $0, @0)

  rawString <- i"r" * '"' * str.rawStrBody * '"':
    data.addToken(RAWSTRING, $0, @0)

  char <- '\'' * str.charBody * '\'':
    data.addToken(CHAR, $0, @0)

  # Numbers
  num <- (float64 | float32 | float) | int

  int <- hex | oct | bin | dec

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

proc scanPrefs*(source: string): PLexer =
  ## Lexical analysis for a string representing a NiPrefs file. 
  result.source = source

  let output = lexer.match(source, result)

  result.ok = output.ok
  result.matchLen = output.matchLen
  result.matchMax = output.matchMax

proc scanPrefsFile*(path: string): PLexer =
  ## Lexical analysis for a NiPrefs file.
  scanPrefs(readFile(path))

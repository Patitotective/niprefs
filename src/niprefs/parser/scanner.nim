import std/[strutils, strformat]
import npeg
import ../prefsnode, escaper

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

type
  SyntaxError* = object of ValueError

  PTokenKind = enum
    PtkEqual,        # =
    PtkDQuote,       # Double quote "
    PtkSQuote,       # Single quote '
    PtkMinues,       # -
    PtkAtSign,       # @
    PtkLeSquare,     # [
    PtkRiSquare,     # ]
    PtkLeBrace,      # {
    PtkRiBrace,      # }
    PtkColon,        # :
    PtkHash,         # #

    PtkEqualGreater, # =>
    Ptkkey,
    PtkInt,
    PtkNil,
    PtkSeq,
    PtkBool,
    PtkChar,
    PtkFloat,
    PtkObject,
    PtkString,

    PtkEnd           # EOF

  PToken = object
    kind*: PTokenKind
    lexeme*: string
    literal*: PrefsNode
    line*: int
    column*: int

  PScanner = object
    source*: string
    tokens*: seq[PToken]
    start*: int
    current*: int
    line*: int
    column*: int

proc initPToken(kind: PTokenKind, lexeme: string, literal: PrefsNode, line: int,
    column: int): PToken =
  PToken(kind: kind, lexeme: lexeme, literal: literal, line: line,
      column: column)

proc initPScanner(source: string): PScanner =
  PScanner(source: source)

proc `isAtEnd`(scanner: PScanner): bool =
  scanner.current >= scanner.source.len

proc syntaxError(scanner: PScanner, info: string) =
  raise newException(SyntaxError, &"{info} at line {scanner.line}, column {scanner.current}")

proc incCurrent(scanner: var PScanner) =
  inc scanner.current
  inc scanner.column

proc incLine(scanner: var PScanner) =
  inc scanner.line
  scanner.column = 0

proc sub(scanner: PScanner, start: int = scanner.start,
    stop: int = scanner.current): string =
  scanner.source[start..stop]

proc peek(scanner: PScanner): char =
  if not scanner.isAtEnd:
    result = scanner.source[scanner.current]

proc peekNext(scanner: PScanner): char =
  if scanner.current+1 < scanner.source.len:
    result = scanner.source[scanner.current+1]

proc match(scanner: var PScanner, expected: char): bool =
  if not scanner.isAtEnd and scanner.source[scanner.current] == expected:
    result = true
    scanner.incCurrent()

proc advance(scanner: var PScanner): char =
  result = scanner.source[scanner.current]
  scanner.incCurrent()

proc addToken(scanner: var PScanner, kind: PTokenKind,
    lexeme: string = scanner.sub(), literal: PrefsNode = newPEmpty()) =

  scanner.tokens.add initPToken(kind, lexeme, literal, scanner.line,
      scanner.column)

##################
##---Analysis---##
##################

proc scanComment(scanner: var PScanner) =
  while scanner.peek() != '\n' and not scanner.isAtEnd:
    discard scanner.advance()

  # scanner.addToken(PtkHash)

proc scanKey(scanner: var PScanner) =
  while scanner.peek() != '=' and scanner.peek() != '\n' and
      not scanner.isAtEnd:

    # if scanner.peekNext() == '\n':
      # scanner.syntaxError("Expected separator '='")

    discard scanner.advance()

  if scanner.isAtEnd:
    scanner.syntaxError("Expected separator '='")

  scanner.addToken(PtkKey, lexeme = scanner.sub())

proc scanString(scanner: var PScanner) =
  while scanner.peek() != '"' and not scanner.isAtEnd:
    discard scanner.advance()

  if scanner.isAtEnd:
    scanner.syntaxError("Unterminated string")

  discard scanner.advance()

  scanner.addToken(PtkString, literal = newPString(scanner.sub(scanner.start+1,
      scanner.current-1)))

proc scanNumber(scanner: var PScanner) =
  if scanner.match('b'): # Bin
    discard
  elif scanner.match('x'): # Hex
    discard
  elif scanner.match('o'): # Oct
    discard

  while scanner.peek().isDigit:
    discard scanner.advance()

  if scanner.peek() == '.' and scanner.peekNext().isDigit:
    discard scanner.advance()

    while scanner.peek().isDigit:
      discard scanner.advance()

    scanner.addToken(PtkFloat, literal = newPFloat(scanner.sub().parseFloat()))

proc scanSeq(scanner: var PScanner) =
  discard

proc scanObj(scanner: var PScanner) =
  discard

proc scanValue(scanner: var PScanner) =
  let c = scanner.advance()
  case c
  of '>':
    scanner.scanObj()
  of '"':
    scanner.scanString()
  of '\'':
    scanner.addToken(PtkSQuote)
  of '@', '[':
    scanner.scanSeq()
  of '{':
    scanner.addToken(PtkLeBrace)
  of ' ', '\r':
    discard
  of '\n':
    scanner.incLine()
  of '-':
    scanner.scanNumber()
  elif c.isDigit:
    scanner.scanNumber()
  else:
    scanner.syntaxError("Unexpected character")

proc scanToken(scanner: var PScanner) =
  let c = scanner.advance
  case c
  of '#':
    scanner.scanComment()
  of '=':
    scanner.scanValue()
  of ' ', '\r':
    discard
  of '\n':
    scanner.incLine()
  elif c in '\x20'..'\xff':
    scanner.scanKey()
  else:
    scanner.syntaxError("Unexpected character")

proc scanTokens(scanner: var PScanner): seq[PToken] =
  while not scanner.isAtEnd:
    scanner.start = scanner.current
    scanner.scanToken()

  scanner.tokens.add initPToken(PtkEnd, "", newPEmpty(), scanner.line,
      scanner.current)

proc toString(token: PToken): string =
  &"{token.kind} {token.lexeme} {token.literal}"

proc parsePrefs*(source: string): PObjectType =
  ## Parse the given string as *Prefs* format.
  ## Any variation of int or float (uint, int8, float32, etc.) is implicitly converted to int and float, respectly.

  var scanner = initPScanner(source)
  discard scanner.scanTokens()
  echo scanner

proc readPrefs*(path: string): PObjectType =
  ## Reads the file at `path` and parses it.
  parsePrefs(readFile(path))

echo readPrefs("prefs.niprefs")

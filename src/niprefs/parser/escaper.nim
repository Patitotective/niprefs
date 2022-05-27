import std/[strutils, parseutils, unicode, tables]
import lexer

# https://nim-lang.org/docs/manual.html#lexical-analysis-string-literals
const escapedTable = {
  'p': "\p",
  'r': "\r", 'c': "\c",
  'n': "\n", 'l': "\l",
  'f': "\f",
  't': "\t",
  'v': "\v",
  '\\': "\\",
  '"': "\"",
  '\'': "'",
  # '0'..'9'+
  'a': "\a",
  'b': "\b",
  'e': "\e",
  # x HH
  # u HHHH
  # u {H+}
}.toTable

# https://nim-lang.org/docs/manual.html#lexical-analysis-character-literals
var escapedCharTable = escapedTable
escapedCharTable.del('p')

template nextIn(obj: untyped): bool =
  (not (pos == str.high)) and (str[pos + 1] in obj)

template nextIs(chr: char): bool =
  (not (pos == str.high)) and (str[pos + 1] == chr)

template nextIsSet(`set`: set[char]): bool =
  (not (pos == str.high)) and (str[pos + 1] in `set`)

proc parseEscapedChar*(str: string, start: Natural = 0): char =
  ## Parses an escaped string representing a char as it were unescaped.
  ##
  ## Check the [manual](https://nim-lang.org/docs/manual.html#lexical-analysis-character-literals) for valid character literals.
  runnableExamples:
    assert '\x23' == r"\x23".parseEscapedChar()

  if str.len == 0:
    return

  let pos = start
  if str[0] == '\\':
    if nextIn(escapedCharTable):
      result = escapedCharTable[str[pos+1]][0]

    elif nextIsSet(Digits):
      var num: int
      discard str.parseInt(num, pos+1)
      result = char(num)

    elif nextIs('x'):
      var hex: int
      if str.parseHex(hex, 2) != 2:
        raise newException(SyntaxError, r"Exactly 2 hex decimals are allowed after \x")

      result = char(hex)

    else:
      raise newException(SyntaxError, str & " invalid character constant")

  else:
    result = str[start]

proc parseEscaped*(str: string): string =
  ## Parses an escaped string as it were unescaped.
  ##
  ## Check the [manual](https://nim-lang.org/docs/manual.html#lexical-analysis-string-literals) for valid string literals.
  runnableExamples:
    assert "\u1235" == r"\u1235".parseEscaped()
    assert "\x00fd\x0asdsd" == r"\x00fd\x0asdsd".parseEscaped()

  var pos = 0

  while pos < str.len:
    var chr = str[pos]

    if chr == '\\':
      if nextIn(escapedTable):
        result &= escapedTable[str[pos+1]]
        pos.inc

      elif nextIsSet(Digits):
        var num: int
        pos += str.parseInt(num, pos+1)
        result &= char(num)

      elif nextIs('x'):
        var hex: int

        if str.parseHex(hex, pos+2, maxLen = 2) != 2:
          raise newException(SyntaxError, r"Exactly 2 hex decimals are allowed after \x")

        pos += 3 # 2 + 1
        result &= char(hex)

      elif str.continuesWith("u{", pos+1):
        var hex: int
        pos += str.parseHex(hex, pos+3) + 3
        if pos > str.high or str[pos] != '}':
          raise newException(SyntaxError, r"Missing closing } for \u{H+}")

        if hex > 0x10FFFF:
          raise newException(SyntaxError, "Unicode codepoint must be lower than 0x10FFFF, but was: " & $hex)
        result &= Rune(hex)

      elif nextIs('u'):
        var hex: int

        if str.parseHex(hex, pos+2, maxLen = 4) != 4:
          raise newException(SyntaxError, r"Exactly 4 hex decimals are allowed after \u")

        pos += 5 # 4 + 1
        result &= Rune(hex)

      else:
        raise newException(SyntaxError, str[pos..pos+1] & " invalid character constant")

    else:
      result &= chr

    pos.inc

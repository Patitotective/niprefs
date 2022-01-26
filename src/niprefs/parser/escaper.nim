import std/[tables, strutils, parseutils, unicode]

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
        raise newException(Exception, r"Exactly 2 hex decimals are allowed after \x")

      result = char(hex)

    else:
      raise newException(Exception, str & " invalid character constant")

  else:
    result = str[start]

proc parseEscaped*(str: string): string =
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

        if str.parseHex(hex, pos+2) != 2:
          raise newException(Exception, r"Exactly 2 hex decimals are allowed after \x")

        pos += 3 # 2 + 1
        result &= char(hex)

      elif str.continuesWith("u{", pos+1):
        var hex: int
        pos += str.parseHex(hex, pos+3) + 3
        if pos > str.high or str[pos] != '}':
          raise newException(Exception, r"Missing closing } for \u{H+}")

        result &= Rune(hex)

      elif nextIs('u'):
        var hex: int

        if str.parseHex(hex, pos+2) != 4:
          raise newException(Exception, r"Exactly 4 hex decimals are allowed after \u")

        pos += 5 # 4 + 1
        result &= Rune(hex)

      else:
        raise newException(Exception, str[pos..pos+1] & " invalid character constant")

    else:
      result &= chr

    pos.inc

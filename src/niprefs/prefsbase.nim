import std/[strutils, sequtils, strformat, options, tables, os]
import prefsnode, parser/parser, utils
export prefsnode, parser

const
  commentChar = '#'
  firstLine = &"{commentChar}NiPrefs"
  endChar = '\n'
  indentChar = "  "
  keyPathSep = '/'
  sepChar = '='
  continueChar = '>'
  invalidKeyChars = [commentChar, sepChar, keyPathSep]

type
  InvalidKey* = object of ValueError
  PrefsBase* = object of RootObj ## Base object to manage a *prefs* file.
    table*: PObjectType
    path*: string

proc checkKey(key: string) = 
  ## Checks if a key is valid and raises an error if it is not.
  if invalidKeyChars.anyIt(it in key):
    raise newException(InvalidKey, &"{key} must not contain any of {invalidKeyChars}")

proc initPrefsBase*(table: PObjectType, path: string): PrefsBase =
  PrefsBase(table: table, path: path)

proc initPrefsBase*(table: PrefsNode, path: string): PrefsBase =
  PrefsBase(table: table.getObject(), path: path)

proc read*(prefs: PrefsBase): PObjectType =
  ## Parses the file at `prefs.path` with [`readPrefs`](parser.html#readPrefs%2Cstring).
  readPrefs(prefs.path)

proc `content`*(prefs: PrefsBase): PObjectType =
  ## Calls `read` on `prefs`.
  prefs.read()

proc toPTree*(table: PObjectType, depth: int = 0): string =
  ## Given a `table` convert it to Prefs format and return it.
  runnableExamples:
    import std/strutils

    var table = toPrefs({"lang": "en", "theme": "dark"}).getObject()
    let str = """
    #NiPrefs
    lang="en"
    theme="dark"
    """

    assert table.toPTree() == str.dedent()

  if depth == 0: result.add &"{firstLine}{endChar}"
  let indent = indentChar.repeat depth

  for key, val in table.pairs:
    checkKey(key)
    if val.kind == PObject and val.objectV.len > 0:
      result.add &"{indent}{key.strip}{sepChar}{continueChar}{endChar}"
      result.add toPTree(val.objectV, depth = depth+1)
    else:
      if val.kind == PEmpty:
        let val = newPNil()

      result.add &"{indent}{key.strip}{sepChar}{val}{endChar}"

proc toPTree*(node: PrefsNode, depth: int = 0): string =
  ## Given a `table` convert it to Prefs format and return it.
  runnableExamples:
    import std/strutils

    var table = toPrefs({"lang": "en", "theme": "dark"})
    let str = """
    #NiPrefs
    lang="en"
    theme="dark"
    """

    assert table.toPTree() == str.dedent()

  toPTree(node.objectV, depth)

proc create*(prefs: PrefsBase, table = prefs.table) =
  ## Checks that all directories in `prefs.path` exists and writes `table.toPTree()` into it.

  checkPath(prefs.path)
  writeFile(prefs.path, table.toPTree())

proc checkFile*(prefs: PrefsBase) =
  ## If `prefs.path` does not exist, call `prefs.create()`.
  if not fileExists(prefs.path):
    prefs.create()

proc write*[T](prefs: PrefsBase, key: string, val: T) =
  ## Changes `key` for `newPNode(val)` in the *prefs* file.
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("theme", "light") # newPNode("light") is not needed

    assert prefs.get("theme") == "light"

  prefs.create(prefs.content.change(key, newPNode(val), keyPathSep))

proc write*(prefs: PrefsBase, key: string, val: PrefsNode) =
  ## Changes `key` for `val` in the *prefs* file.
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es"}),
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("keybindings", toPrefs @[{"keys": "Ctrl+C", "command": "copy"}])

  prefs.create(prefs.content.change(key, val, keyPathSep))

proc writeMany*(prefs: PrefsBase, items: PObjectType) =
  ## To efficiently write multiple prefs at once (by opening the file just once).
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.writeMany(toPrefs({"lang": "en",
        "theme": "light"}).getObject())

    assert prefs.get("lang") == "en"
    assert prefs.get("theme") == "light"

  var table = prefs.content

  for key, val in items.pairs():
    table = table.change(key, val, keyPathSep)

  prefs.create(table)

proc writeMany*(prefs: PrefsBase, items: PrefsNode) =
  ## To efficiently write multiple prefs at once (by opening the file just once).
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.writeMany(toPrefs({"lang": "en",
        "theme": "light"}))

    assert prefs.get("lang") == "en"
    assert prefs.get("theme") == "light"

  var table = prefs.content

  for key, val in items.getObject().pairs():
    table = table.change(key, val, keyPathSep)

  prefs.create(table)

proc delKey*(prefs: PrefsBase, key: string) =
  ## Deletes `key` from the *prefs* file.
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.delKey("theme") # newPNode("light") is not needed

    assert not prefs.hasKey("theme")

  var content = prefs.content

  if keyPathSep in key:
    var keys = key.split(keyPathSep)
    var table = content[keys[0]]
    keys.delete(0)

    for e, key in keys:
      if e == keys.len - 1:
        table.objectV.del(key)
      else:
        table = table[key]
  else:
    content.del(key)

  prefs.create(content)

proc get*(prefs: PrefsBase, key: string): PrefsNode =
  ## Access to `key` in the *prefs* file.
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    assert prefs.get("lang") == "es"

  prefs.content.get(key, keyPathSep)

proc hasKey*(prefs: PrefsBase, key: string): bool =
  ## Checks if `key` exists in the *prefs* file.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    assert prefs.hasKey("theme")

  try:
    discard prefs.get(key)
    result = true
  except KeyError:
    result = false

proc overwrite*(prefs: PrefsBase, key: string) =
  ## Overwrites `key` in the *prefs* file with it's default value (from `prefs.table`).
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("lang", "en")
    prefs.write("theme", "light")

    assert prefs.get("lang") == "en"

    prefs.overwrite("lang")

    assert prefs.get("lang") == "es" # "es" is the default value
    assert prefs.get("theme") == "light" # "theme" was not overwritten

  prefs.write(key, prefs.table.get(key, keyPathSep))

proc overwrite*(prefs: PrefsBase, table: PObjectType = prefs.table) =
  ## Overwrites the whole *prefs* file with `table`.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("lang", "en")
    prefs.write("theme", "light")

    prefs.overwrite()

    assert prefs.get("lang") == "es" # "es" is the default value
    assert prefs.get("theme") == "dark" # "dark" is the default value

  prefs.create(table)

proc delete*(prefs: PrefsBase) =
  ## Deletes the *prefs* file.
  removeFile(prefs.path)

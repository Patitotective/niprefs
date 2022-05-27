import std/[strutils, sequtils, strformat, options, tables, os]
import prefsnode, parser/parser, utils
export prefsnode, parser

const
  commentChar = '#'
  firstLine = &"{commentChar}NiPrefs"
  endChar = '\n'
  indentChar = "  "
  keyPathSep* = '/'
  sepChar = '='
  continueChar = '>'

type
  InvalidKey* = object of ValueError
  PrefsBase* = object of RootObj ## Base object to manage a *prefs* file.
    table*: PObjectType
    path*: string

proc get(table: PObjectType, key: string): PrefsNode = 
  if keyPathSep in key:
    table.getNested(key.split(keyPathSep))
  else:
    table[key.nimIdentNormalize()]

proc change(table: PObjectType, key: string, val: PrefsNode): PObjectType = 
  if keyPathSep in key:
    result = table.changeNested(key.split(keyPathSep), val)
  else:
    result = table
    result[key.nimIdentNormalize()] = val

proc validateKey(key: string) = 
  ## Validates if a key is a valid (Nim) identifier.  
  if not key.validIdentifier():
    raise newException(InvalidKey, &"{key} must be a valid identifer")

proc initPrefsBase*(table: PObjectType, path: string): PrefsBase =
  PrefsBase(table: table, path: path)

proc initPrefsBase*(table: PrefsNode, path: string): PrefsBase =
  ## Same as `initPrefsBase(table.getObject(), path)`.
  initPrefsBase(table.getObject(), path)

proc checkFile*(prefs: PrefsBase)

proc read*(prefs: PrefsBase): PObjectType =
  ## Parses the file at `prefs.path` with [`readPrefs`](parser.html#readPrefs,string).
  readPrefs(prefs.path)

proc `content`*(prefs: PrefsBase): PObjectType =
  ## Calls `read` on `prefs`.
  prefs.checkFile()
  prefs.read()

proc toString*(table: PObjectType, depth: int = 0): string =
  ## Given a `table` convert it to Prefs format and return it.
  runnableExamples:
    import std/strutils

    var table = toPrefs({"lang": "en", "theme": "dark"}).getObject()
    let str = """
    #NiPrefs
    lang="en"
    theme="dark"
    """

    assert table.toString() == str.dedent()

  if depth == 0: result.add &"{firstLine}{endChar}"
  let indent = indentChar.repeat depth

  for key, val in table.pairs:
    let key = key.strip().nimIdentNormalize()
    validateKey(key)
    if val.kind == PObject and val.objectV.len > 0:
      result.add &"{indent}{key}{sepChar}{continueChar}{endChar}"
      result.add toString(val.objectV, depth = depth+1)
    else:
      if val.kind == PEmpty:
        let val = newPNil()

      result.add &"{indent}{key}{sepChar}{val}{endChar}"

proc toString*(node: PrefsNode, depth: int = 0): string =
  ## Same as `toString(node.getObject(), depth)`.
  toString(node.getObject(), depth)

proc create*(prefs: PrefsBase, table = prefs.table) =
  ## Checks that all directories in `prefs.path` exists and writes `table.toString()` into it.
  prefs.path.splitPath.head.createDir()
  writeFile(prefs.path, table.toString())

proc checkFile*(prefs: PrefsBase) =
  ## If `prefs.path` does not exist, call `prefs.create()`.
  if not fileExists(prefs.path):
    prefs.create()

proc write*[T: not PrefsNode](prefs: PrefsBase, key: string, val: T) =
  ## Changes `key` for `newPNode(val)` in the *prefs* file.
  ##
  ## Supports *key path*.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("theme", "light") # newPNode("light") is not needed

    assert prefs.get("theme") == "light"

  prefs.create(prefs.content.change(key, newPNode(val)))

proc write*(prefs: PrefsBase, key: string, val: PrefsNode) =
  ## Changes `key` for `val` in the *prefs* file.
  ##
  ## Supports *key path*.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es"}),
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("keybindings", toPrefs @[{"keys": "Ctrl+C", "command": "copy"}])

  prefs.create(prefs.content.change(key, val))

proc write*[T: not PrefsNode](prefs: PrefsBase, keys: varargs[string], val: T) =
  ## Changes the last key from `keys`, the other elements being it's path, for `newPNode(val)` in the *prefs* file.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("theme", "light") # newPNode("light") is not needed

    assert prefs.get("theme") == "light"

  prefs.create(prefs.content.changeNested(keys, newPNode(val)))

proc write*(prefs: PrefsBase, keys: varargs[string], val: PrefsNode) =
  ## Changes the last key from `keys`, the other elements being it's path, for `val` in the *prefs* file.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es"}),
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.write("keybindings", toPrefs @[{"keys": "Ctrl+C", "command": "copy"}])

  prefs.create(prefs.content.changeNested(keys, val))

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
    table = table.change(key, val)

  prefs.create(table)

proc writeMany*(prefs: PrefsBase, items: PrefsNode) =
  ## Same as `prefs.writeMany(prefs, items.getObject())`
  prefs.writeMany(items.getObject())

proc delPath*(prefs: PrefsBase, keys: varargs[string]) =
  ## Deletes the last key from `keys`, the other elements being it's path, from the *prefs* file.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"scheme": {"theme": "dark"}}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.delPath("scheme", "theme")

    assert not prefs.hasPath("scheme", "theme")

  var content = prefs.content

  var keys = keys.toSeq().mapIt(it.nimIdentNormalize())
  var table = content[keys[0]]
  keys.delete(0)

  for e, key in keys:
    if e == keys.len - 1:
      table.objectV.del(key)
    else:
      table = table[key]

  prefs.create(content)

proc delKey*(prefs: PrefsBase, key: string) =
  ## Deletes `key` from the *prefs* file.
  ##
  ## Supports key path.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es", "theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    prefs.delKey("theme") # newPNode("light") is not needed

    assert not prefs.hasKey("theme")

  if keyPathSep in key:
    prefs.delPath(key.split(keyPathSep))
  else:
    var content = prefs.content
    content.del(key.nimIdentNormalize())
    prefs.create(content)

proc getPath*(prefs: PrefsBase, keys: varargs[string]): PrefsNode =
  ## Access to the last key from `keys`, the other elements being it's path, in the preferences file.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"scheme": {"theme": "dark"}}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    assert prefs.getPath("scheme", "theme") == "dark"

  prefs.content.getNested(keys)

proc get*(prefs: PrefsBase, key: string): PrefsNode =
  ## Access to `key` in the *prefs* file.
  ##
  ## Supports key path.

  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"lang": "es"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    assert prefs.get("lang") == "es"

  prefs.content.get(key)

proc hasPath*(prefs: PrefsBase, keys: varargs[string]): bool =
  ## Checks if the last key from `keys` exists the other elements being it's path in the *prefs* file.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"scheme": {"theme": "dark"}}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    assert prefs.hasPath("scheme", "theme")

  try:
    discard prefs.getPath(keys)
    result = true
  except KeyError:
    result = false

proc hasKey*(prefs: PrefsBase, key: string): bool =
  ## Checks if `key` exists in the *prefs* file.
  ##
  ## Supports key path.
  runnableExamples:
    var prefs = initPrefsBase(table = toPrefs({"theme": "dark"}), 
      path = "settings.niprefs")

    prefs.overwrite() # To avoid conflicts

    assert prefs.hasKey("theme")

  if keyPathSep in key:
    prefs.hasPath(key.split(keyPathSep))
  else:
    prefs.content.hasKey(key.nimIdentNormalize())

proc overwrite*(prefs: PrefsBase, key: string) =
  ## Overwrites `key` in the *prefs* file with it's default value (from `prefs.table`).
  ##
  ## Support key path.

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

  prefs.write(key, prefs.table.get(key))

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

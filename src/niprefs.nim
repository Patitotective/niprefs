## NiPrefs is a library that offers a dynamic preferences-system in a text file within a table-like structure.
## It stores the preferences in an `OrderedTable[string, PrefsNode]`, where `PrefsNode` is an object variation that supports the following types:  
## - `int`
## - `nil`
## - `seq` (there are no arrays)
## - `bool`
## - `char`
## - `float`
## - `string` (and raw strings)
## - `set[char]`
## - `set[byte]`
## - `OrderedTable[string, PrefsNode]` (nested tables)

## # Syntax
## NiPrefs writes the preferences down to a text file using a pretty straightforward syntax that goes like this:
## ```nim
## # Comment
## # key=val
## lang="en" # Keys do not require quotes
## dark=false
## scheme=> # Nested tables are defined with a greater than symbol and indentation-in
##   background="#ffffff" # background belongs to scheme
##   font=>
##     family="UbuntuMono" # scheme/font/family
##     size=15
##     color="#000000"
## users={"ElegantBeef": 28, "Rika": 22, "hmmm": 0x0} # Tables are also supported (and keys do require quotes inside tables)
## ```

## # Basic usage
## To generate a `OrderedTable[string, PrefsNode]` or a `PrefsNode` you may want to use the [toPrefs](prefsnode.html#toPrefs.m%2Cuntyped) macro.

runnableExamples:
  var prefs = toPrefs({
    "lang": "en", # Keys do not require quotes when using toPrefs macro.
    dark: true,
    keybindings: {:},
    scheme: {
      background: "#000000",
      font: {
        size: 15,
        family: "UbuntuMono",
        color: "#73D216"
      }
    }
  }).initPrefs(path = "settings.niprefs")

## After the above example, a new `settings.niprefs` file should be created:
## ```nim
## #NiPrefs
## lang="en"
## dark=true
## keybindings={:}
## scheme=>
##   background="#000000"
##   font=>
##     size=15
##     family="UbuntuMono"
##     color="#73D216"
## ```
## ### Why does the niprefs file doesn't change if I change the toPrefs macro?
## Well, niprefs is meant to be used as a preferences system, what that means is that the file is created with the default values if it doesn't exist.  
## If it does exist, it just reads it. If you want to reset the file with the default prefs manually, you may use [overwrite](prefsbase.html#overwrite%2CPrefsBase%2CPObjectType).  


## ## Reading
## To read a key from your preferences file you can access to it as it were a table:
## ```nim
## assert prefs["lang"] == "en"
## ```
## To read a nested key you must use something called *key paths*, which are in essence a path to a nested key separated by a slash `/`.
##
## Or you can pass the *key path* separated by a comma:
## ```nim
## assert prefs["scheme/font/family"] == "UbuntuMono" # Same as prefs["scheme"]["font"]["family"]
## assert prefs["scheme", "font", "family"] == "UbuntuMono"
## ```

## ## Writing
## To change the value of a key or create a new one you can do it as it were table:
## ```nim
## prefs["lang"] = "es"
## assert prefs["lang"] == "es"
## ```
## Same with nested keys:
## ```nim
## prefs["scheme/font/size"] = 20 # prefs["scheme"]["font"]["size"] = 20 wont' work
## assert prefs["scheme/font/size"] == 20
## prefs["scheme", "font", "size"] = 21
## assert prefs["scheme", "font", "size"] == 21
## ```

## ## Removing
## To remove a key from your preferences you can use either `del` or `pop`:
## - [del](#del%2CPrefs%2Cstring) deletes the `key` **if** it exists, does nothing if it does not.
## - [pop](#pop%2CPrefs%2Cstring%2CPrefsNode) deletes the `key`, returns true if it existed and sets `val` to the value that the `key` had. Otherwise, returns false, and `val` is unchanged.
## ```nim
## prefs.del("lang")
## assert "lang" notin prefs
## 
## var val: PrefsNode
## prefs.pop("scheme/font/size")
## assert val == 20
## ```

## ## More
## There are more useful procedures.
##
## Check them here:
## - [writeMany](prefsbase.html#writeMany%2CPrefsBase%2CPObjectType)
## - [clear](#clear%2CPrefs)
## - [overwrite](prefsbase.html#overwrite%2CPrefsBase%2Cstring)
## - [delete](prefsbase.html#delete%2CPrefsBase)
## - [parsePrefs](parser/parser.html#parsePrefs%2Cstring)
## - [readPrefs](parser/parser.html#readPrefs%2Cstring)

import std/tables
import niprefs/prefsbase
export prefsbase except keyPathSep
export tables

type
  Prefs* = object of PrefsBase ## Provides a table-like interface for the PrefsBase object

proc initPrefs*(table: PObjectType = default PObjectType, path: string = "prefs.niprefs"): Prefs =
  ## Creates a new Prefs object and checks if a file exists at `path` to create it if it doesn't.
  result = Prefs(table: table, path: path)
  result.checkFile()

proc initPrefs*(table: PrefsNode = newPObject(), path: string = "prefs.niprefs"): Prefs =
  ## Creates a new Prefs object and checks if a file exists at `path` to create it if it doesn't.
  initPrefs(table = table.getObject(), path = path)

proc len*(prefs: Prefs): int =
  ## Same as `prefs.content.len`.
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert prefs.len == 2

  result = prefs.content.len

proc `$`*(prefs: Prefs): string =
  ## Instead of printing the prefs object, print it's content
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert $prefs == "{\"lang\": \"en\", \"theme\": \"dark\"}"

  $prefs.content

proc `[]`*(prefs: Prefs, keys: varargs[string]): PrefsNode = 
  ## Get the last key from `keys`, the other elements being it's path, from the preferences file by separating the keys with a comma.

  runnableExamples:
    var prefs = toPrefs({"lang": "en", "scheme": {
        "font": "UbuntuMono"}}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert prefs["scheme", "font"] == "UbuntuMono"

  prefs.getPath(keys)

proc `[]`*(prefs: Prefs, key: string): PrefsNode =
  ## Get a key from the preferences file.
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = toPrefs({"lang": "en", "scheme": {
        "font": "UbuntuMono"}}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert prefs["lang"] == "en" # newPNode("en") is not required
    assert prefs["scheme/font"] == "UbuntuMono"

  prefs.get(key)

proc `[]=`*[T: not PrefsNode](prefs: Prefs, keys: varargs[string], val: T) = 
  ## Write the last key from `keys`, the other elements being it's path, in the preferences file.
  ##
  ## `newPNode` is called on `val`, meaning that for [structured types](https://nim-lang.org/docs/manual.html#types-structured-types) you may want to use the [toPrefs](prefsnode.html#toPrefs.m%2Cuntyped) macro.
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs

    prefs.overwrite() # To avoid conflicts

    prefs["lang"] = "es" # newPString("es") is not required, since `string` is not a structured type

  prefs.write(keys, newPNode(val))

proc `[]=`*[T: not PrefsNode](prefs: Prefs, key: string, val: T) =
  ## Write in the *prefs* file the given key-value pair.
  ##
  ## `newPNode` is called on `val`, meaning that only the [structured types](https://nim-lang.org/docs/manual.html#types-structured-types) require `PrefsNode` type.
  ##
  ## For structured types use [`[]=`(prefs: Prefs, key: string: val: PrefsNode)](#[]%3D%2CPrefs%2Cstring%2CPrefsNode).
  ##
  ## *(See the example below)*
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs

    prefs.overwrite() # To avoid conflicts

    prefs["lang"] = "es" # newPString("es") is not required, since `string` is not a structured type

  prefs.write(key, newPNode(val))

proc `[]=`*(prefs: Prefs, key: string, val: PrefsNode) =
  ## Write in the *prefs* file the given key-value pair.
  ##
  ## Use this procedure for [structured types](https://nim-lang.org/docs/manual.html#types-structured-types) with the [toPrefs](prefsnode.html#toPrefs.m%2Cuntyped) macro.
  ##
  ## *(See the example below)*
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = toPrefs({"lang": "en"}).initPrefs

    prefs["keybindings"] = toPrefs @[{"keys": "Ctrl+C",
        "command": "copy"}]

  prefs.write(key, val)

proc `[]=`*(prefs: Prefs, keys: varargs[string], val: PrefsNode) =
  ## Write the last key from `keys`, the other elements being it's path, in the preferences file.
  ##
  ## Use this procedure for [structured types](https://nim-lang.org/docs/manual.html#types-structured-types) with the [toPrefs](prefsnode.html#toPrefs.m%2Cuntyped) macro.
  ##
  ## *(See the example below)*

  runnableExamples:
    var prefs = toPrefs({"lang": "en"}).initPrefs

    prefs["keybindings"] = toPrefs @[{"keys": "Ctrl+C",
        "command": "copy"}]

  prefs.write(keys, val)

proc clear*(prefs: Prefs) =
  ## Clears the content of the file.
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs
    prefs.clear()
    assert prefs.content == default PObjectType # PObject stands for OrderedTable[string, PrefsNode]

  prefs.overwrite(default PObjectType)

proc contains*(prefs: Prefs, key: string): bool =
  ## Alias of [hasKey proc](prefsbase.html#hasKey%2CPrefsBase%2Cstring) for use with the `in` operator.
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs
    prefs.overwrite() # To avoid conflicts

    assert "lang" in prefs

  prefs.hasKey(key)

proc del*(prefs: Prefs, key: string) =
  ## Deletes `key` from the *prefs* file. Does nothing if the key does not exist.

  prefs.delKey(key)

proc pop*(prefs: Prefs, key: string, val: var PrefsNode): bool =
  ## Deletes the `key` from the *prefs* file.
  ## Returns `true`, if the `key` existed, and sets `val` to the
  ## mapping of the key. Otherwise, returns `false`, and the `val` is
  ## unchanged.

  runnableExamples:
    var
      prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs
      s: PrefsNode

    prefs.overwrite() # To avoid conflicts

    assert prefs.pop("lang", s) == true
    assert "lang" notin prefs
    assert s.getString() == "en"

  if key in prefs:
    val = prefs[key]
    result = true
    prefs.delKey(key)
  else:
    result = false

proc pop*(prefs: Prefs, keys: varargs[string], val: var PrefsNode): bool =
  ## Deletes the last key from `keys`, the other elements being it's path, from the *prefs* file.
  ## Returns `true`, if the key existed, and sets `val` to the
  ## mapping of the key. Otherwise, returns `false`, and `val` is
  ## unchanged.

  runnableExamples:
    var
      prefs = toPrefs({"scheme": {"theme": "dark"}}).initPrefs
      s: PrefsNode

    prefs.overwrite() # To avoid conflicts

    assert prefs.pop("scheme", "theme", s) == true
    assert "scheme/theme" notin prefs
    assert s == "dark"

  if prefs.hasPath(keys):
    val = prefs[keys]
    result = true
    prefs.delPath(keys)
  else:
    result = false

## NiPrefs is a library that offers a preferences-system in a text file within a table-like structure.
## It stores the preferences in an `OrderedTable[string, PrefsNode]` where `PrefsNode` is an object variation that supports the following types:  
## - `int`
## - `nil`
## - `seq` (there are no arrays)
## - `bool`
## - `char`
## - `float`
## - `string` (and raw strings)
## - `OrderedTable[string, PrefsNode]` (nested tables)

## # Syntax
## NiPrefs writes the preferences down to a text file using a pretty straightforward syntax that goes like this:
## ```nim
## # Comment
## lang="en" # Keys do not require quotes
## dark=false
## scheme=> # Nested tables are defined with a greater than symbol and indentation-in
##   background="#ffffff" # background belongs to scheme
##   font=>
##     family="UbuntuMono"
##     size=15
##     color="#000000"
## ```

## # Basic usage
runnableExamples:
  let defaultPrefs = toPrefs({
    "lang": "en",
    "dark": true,
    "keybindings": {:},
    "scheme": {
      "background": "#000000",
      "font": {
        "size": 15,
        "family": "UbuntuMono",
        "color": "#73D216"
    }
  }
})

  var prefs = initPrefs(defaultPrefs, "settings.niprefs")

## After the above example, a new `settings.niprefs` file should be created:
##
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

## ## Reading
## To read a key from your preferences file you can access to it as it were a table:
## ```nim
## echo prefs["lang"]
## >>> "en"
## ```
## To read a nested key you must use something called *key paths*, which are in essence a path to a nested key separated by a slash `/`:
## ```nim
## echo prefs["scheme/font/family"]
## >>> "UbuntuMono"
## ```

## ## Writing
## To change the value of a key or create a new one you can do it as it were table:
## ```nim
## prefs["lang"] = "es"
## echo prefs["lang"]
## >>> "es"
## ```
## Same with nested keys:
## ```nim
## prefs["scheme/font/size"] = 20
## echo prefs["scheme/font/size"]
## >>> 20
## ```

## ## Removing
## To remove a key from your preferences you can use either `del` or `pop`.
## [`del`]() deletes the `key` **if** it exists, does nothing if it does not.
## [`pop`]() deletes the `key`, returns true if it existed and sets `val` to the value that the `key` had. Otherwise, returns false, and `val` is unchanged.

import std/tables
import niprefs/prefsbase

export prefsbase, tables

type
  Prefs* = object of PrefsBase ## Provides a table-like interface for the PrefsBase object

proc initPrefs*(table: PObjectType = default PObjectType,
    path: string = "prefs.niprefs"): Prefs =
  ## Creates a new Prefs object and checks if a file exists at `path` to create it if it doesn't.
  result = Prefs(table: table, path: path)
  result.checkFile()

proc initPrefs*(table: PrefsNode = newPObject(),
    path: string = "prefs.niprefs"): Prefs =
  ## Creates a new Prefs object and checks if a file exists at `path` to create it if it doesn't.
  initPrefs(table = table.getObject(), path = path)

template len*(prefs: Prefs): int =
  ## Same as `prefs.content.len`.
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert prefs.len == 2

  prefs.content.len


template pairs*(prefs: Prefs) =
  ## Same as `prefs.content.pairs`
  prefs.content.pairs

template keys*(prefs: Prefs) =
  ## Same as `prefs.content.keys`
  prefs.content.keys

template values*(prefs: Prefs) =
  ## Same as `prefs.content.values`
  prefs.content.values

proc `$`*(prefs: Prefs): string =
  ## Instead of printing the prefs object, print it's content
  runnableExamples:
    var prefs = toPrefs({"lang": "en", "theme": "dark"}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert $prefs == "{\"lang\": \"en\", \"theme\": \"dark\"}"

  $prefs.content

proc `[]`*(prefs: Prefs, key: string): PrefsNode =
  ## Get a key from the *prefs* file reading it
  ##
  ## Supports *key path*.

  runnableExamples:
    var prefs = toPrefs({"lang": "en", "scheme": {
        "font": "UbuntuMono"}}).initPrefs

    prefs.overwrite() # To avoid conflicts

    assert prefs["lang"] == "en" # newPNode("en") is not required
    assert prefs["scheme/font"] == "UbuntuMono"

  prefs.get(key)

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
    # It is converted into
    # newPNode(@[newPNode(
    #   {
    #     "keys": newPNode("Ctrl+C"),
    #     "command": newPNode("copy")
    #   }.toOrderedTable
    # )])

  prefs.write(key, val)

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

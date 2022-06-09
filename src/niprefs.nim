## NiPrefs is a library that offers a dynamic preferences-system in a text file within a table-like structure.
## It stores the preferences in an `OrderedTable[string, PrefsNode]`, where `PrefsNode` is an object variation that supports the following types:  
## - `nil`
## - `int`
## - `seq` (there are no arrays)
## - `bool`
## - `char`
## - `float`
## - `string` (and raw strings)
## - `set[char]`
## - `set[byte]`
## - Objects and tables

## # Syntax
## NiPrefs writes the preferences down to a text file using a pretty straightforward syntax that goes like this:
## ```nim
## # Comment
## # key=val
## lang="en" # Keys do not require quotes
## dark=false
## scheme=> # Nested objects are defined with a greater than symbol and indentation-in
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
##
## ### Why does the niprefs file doesn't change if I change the toPrefs macro?
## Well, niprefs is meant to be used as a preferences system, what that means is that the file is created with the default values if it doesn't exist.  
## If it does exist, it just reads it. If you want to reset the file with the default prefs manually, you may use [overwrite](Prefs.html#overwrite%2CPrefs%2CPObjectType).  


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
## - [writeMany](Prefs.html#writeMany%2CPrefs%2CPObjectType)
## - [clear](#clear%2CPrefs)
## - [overwrite](Prefs.html#overwrite%2CPrefs%2Cstring)
## - [delete](Prefs.html#delete%2CPrefs)
## - [parsePrefs](parser/parser.html#parsePrefs%2Cstring)
## - [readPrefs](parser/parser.html#readPrefs%2Cstring)
import std/os
import toml_serialization

import niprefs/node
export node

type
  Prefs* = object
    path*: string
    default: TomlValueRef
    content*: TomlValueRef

proc save*(prefs: Prefs) =
  prefs.path.splitPath.head.createDir()
  Toml.saveFile(prefs.path, prefs.content)

proc initPrefs*(path: string, default: TomlValueRef): Prefs =
  ## Create a Prefs object and load the content from `path` if it exists otherwise create it with `default`.
  assert default.kind == TomlKind.Table

  result = Prefs(path: path, default: default.copy())

  if not path.fileExists:
    result.content = default
    result.save()

  result.content = Toml.loadFile(result.path, TomlValueRef)

proc remove*(prefs: Prefs) =
  ## Deletes the niprefs file if it exists.
  if fileExists(prefs.path):
    removeFile(prefs.path)

proc default*(prefs: Prefs): TomlValueRef = 
  prefs.default

proc `$`*(prefs: Prefs): string =
  ## Instead of printing the prefs object, print it's content
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    assert $prefs == "{\"lang\": \"en\", \"theme\": \"dark\"}"

  $prefs.content

proc `[]`*(prefs: Prefs, key: string): TomlValueRef =
  prefs.content[key]

proc `{}`*(prefs: Prefs, keys: varargs[string]): TomlValueRef =
  prefs.content{keys}

proc `[]=`*[T: not TomlValueRef](prefs: var Prefs, key: string, val: T) =
  prefs.content[key] = newTNode(val)

proc `{}=`*[T: not TomlValueRef](prefs: var Prefs, keys: varargs[string], val: T) =
  prefs.content{keys} = newTNode(val)

proc len*(prefs: Prefs): int =
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    assert prefs.len == 2

  prefs.content.len

proc delete*(prefs: var Prefs, key: string) =
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    prefs.delete("theme")

    assert "theme" notin prefs

  prefs.content.delete(key)

proc hasKey*(prefs: Prefs, key: string): bool =
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    assert prefs.hasKey("lang")

  prefs.content.hasKey(key)

proc contains*(prefs: Prefs, key: string): bool = 
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    assert "lang" in prefs

  prefs.hasKey(key)

proc overwrite*(prefs: var Prefs, key: string) =
  ## Overwrites `key` in the niprefs file with it's default value from `prefs.default`.
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    prefs["lang"] = "en"
    prefs["theme"] = "light"

    prefs.overwrite("lang")

    assert prefs["lang"] == "es" # "es" is the default value
    assert prefs["theme"] == "light" # "theme" was not overwritten

  assert key in prefs.default
  prefs.content[key] = prefs.default[key]

proc overwrite*(prefs: var Prefs, table: TomlValueRef = prefs.default) =
  ## Overwrites the whole niprefs file with `table`.
  runnableExamples:
    var prefs = initPrefs("settings.niprefs", toToml({lang: "es", theme: "dark"}))
    
    prefs.overwrite() # Ignore this line

    prefs.content["lang"] = "en"
    prefs.content["theme"] = "light"

    prefs.overwrite()

    assert prefs.get("lang") == "es" # "es" is the default value
    assert prefs.get("theme") == "dark" # "dark" is the default value

  prefs.content = table

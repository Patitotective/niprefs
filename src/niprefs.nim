## niprefs is a simple way to manage your application preferences (or configuration) using TOML.

## # TOML Syntax
## A config file format for humans. 
## ```toml
## # This is a TOML document
## 
## title = "TOML Example"
## 
## [owner]
## name = "Tom Preston-Werner"
## dob = 1979-05-27T07:32:00-08:00
## 
## [database]
## enabled = true
## ports = [ 8000, 8001, 8002 ]
## data = [ ["delta", "phi"], [3.14] ]
## temp_targets = { cpu = 79.5, case = 72.0 }
## 
## [servers]
## 
## [servers.alpha]
## ip = "10.0.0.1"
## role = "frontend"
## 
## [servers.beta]
## ip = "10.0.0.2"
## role = "backend"
## ```

## # Basic usage
## A `Prefs` object requires a `path` and a `default` preferences. A TOML file is created at `path` with `default` whenever it's not found, if it exists it will read it.  
## To access the actual preferences (not the default) you may want to use `Prefs.content` and at the end of your program call `Prefs.save()` to update the preferences file.
## 
## `toToml` is a helpful macro to define your default preferences.  
## Instead of having to write:
## ```nim
## {"a": [1.newTInt(), 2.newTInt()].newTArray()}.newTTable()
## ```
## Using the `toToml` it's just as easy as writing:
## ```nim
## toToml {a: [1, 2]}
## ```
runnableExamples:
  let prefs = initPrefs(
    path = "prefs.toml", 
    default = toToml {
      "lang": "en", # Keys do not require quotes when using toToml macro.
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
    }
  )
## After the above example, a new `prefs.toml` file should be created:
## ```nim
##   lang="en"
##   dark=true
##   scheme.background="#000000"
##   scheme.font.color="#73D216"
##   scheme.font.family="UbuntuMono"
##   scheme.font.size=15
## [keybindings]
## ```
##
## ## Reading
## You can access `prefs.content`
## ```nim
## assert prefs.content["lang"] == "en"
## ```
## But `Prefs` has some helper procedures to access `content` so you don't need to write `prefs.content[]` you can just `prefs[]`:
## ```nim
## assert prefs["lang"] == "en"
## ```
## To read a nested key you can use the `{}` operator:
## ```nim
## assert prefs{"scheme", "font", "family"} == "UbuntuMono" # This acceses prefs.content
## assert prefs["scheme"]["font"]["family"] == "UbuntuMono" # This acceses prefs.content
## ```
##
## ## Writing
## ```nim
## prefs["lang"] = "es" # Same as prefs.content["lang"] = "es"
## assert prefs["lang"] == "es"
## ```
## Same with nested keys:
## ```nim
## prefs{"scheme", "font", "size"} = 20 
## assert prefs{"scheme", "font", "size"} == 20
## 
## prefs["scheme"]["font"]["size"] = 10
## assert prefs["scheme"]["font"]["size"] == 10
## ```
##
## ## Removing
## ```nim
## assert "lang" in prefs
## 
## prefs.delete("lang")
## 
## assert "lang" notin prefs
## ```
## ## Overwriting
## To reset a key to its default value or reset the whole preferences use `Prefs.overwrite()`:
## ```nim
## assert prefs["lang"] == "en"
## prefs["lang"] = "es"
## prefs.overwrite("lang")
## assert prefs["lang"] == "en"
## ```
## Nested key:
## ```nim
## assert prefs{"scheme", "font", "size"} == 15
## prefs{"scheme", "font", "size"} = 20
## prefs.overwrite(["scheme", "font", "size"])
## assert prefs{"scheme", "font", "size"} == 15
## ```
## Whole file:
## ```nim
## prefs["lang"] = "es"
## prefs["dark"] = false
## 
## prefs.overwrite()
## 
## assert prefs["lang"] == "en"
## assert prefs["dark"] == true
## ```

import std/os
import toml_serialization

import niprefs/node

export node
export toml_serialization

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
    result.content = default.copy()
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

proc `[]=`*(prefs: Prefs, key: string, val: TomlValueRef) =
  prefs.content[key] = val

proc `{}=`*(prefs: Prefs, keys: varargs[string], val: TomlValueRef) =
  prefs.content{keys} = val

proc `[]=`*[T: not TomlValueRef](prefs: Prefs, key: string, val: T) =
  prefs.content[key] = newTNode(val)

proc `{}=`*[T: not TomlValueRef](prefs: Prefs, keys: varargs[string], val: T) =
  prefs.content{keys} = newTNode(val)

proc len*(prefs: Prefs): int =
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    assert prefs.len == 2

  prefs.content.len

proc delete*(prefs: Prefs, key: string) =
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

proc hasKey*(prefs: Prefs, keys: varargs[string]): bool =
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"scheme": {"font": "UbuntuMono"}}))

    prefs.overwrite() # Ignore this line

    assert prefs.hasKey("scheme", "font")

  prefs.content.hasKey(keys)

proc contains*(prefs: Prefs, key: string): bool = 
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "en", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    assert "lang" in prefs

  prefs.hasKey(key)

proc overwrite*(prefs: Prefs, key: string) =
  ## Overwrites `key` in the niprefs file with it's default value from `prefs.default`.
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"lang": "es", "theme": "dark"}))

    prefs.overwrite() # Ignore this line

    prefs["lang"] = "en"
    prefs["theme"] = "light"

    prefs.overwrite("lang")

    assert prefs["lang"] == "es" # "es" is the default value
    assert prefs["theme"] == "light" # "theme" was not overwritten

  assert key in prefs.default
  prefs.content[key] = prefs.default[key]

proc overwrite*(prefs: Prefs, keys: openArray[string]) =
  ## Traverses the node and overwrites the given value with it's default value from `prefs.default`.
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({"scheme": {"font": "UbuntuMono"}}))

    prefs.overwrite() # Ignore this line

    prefs{"scheme", "font"} = "ProggyClean Vector"

    prefs.overwrite(["scheme", "font"])

    assert prefs{"scheme", "font"} == "UbuntuMono" # "UbuntuMono" is the default value

  assert prefs.default.hasKey(keys)
  
  prefs.content{keys} = prefs.default{keys}

proc overwrite*(prefs: var Prefs, table: TomlValueRef = prefs.default) =
  ## Overwrites the whole niprefs file with `table`.
  runnableExamples:
    var prefs = initPrefs("prefs.toml", toToml({lang: "es", theme: "dark"}))
    
    prefs.overwrite() # Ignore this line

    prefs.content["lang"] = "en"
    prefs.content["theme"] = "light"

    prefs.overwrite()

    assert prefs["lang"] == "es" # "es" is the default value
    assert prefs["theme"] == "dark" # "dark" is the default value

  prefs.content = table.copy()

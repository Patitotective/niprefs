# NiPrefs
> _Store and manage preferences in a text file within a table-like structure._

## Installation
You can install _NiPrefs_ with [_nimble_](https://nimble.directory):
```sh
nimble install niprefs
```
Or directly from this repo:
```sh
nimble install https://github.com/Patitotective/niprefs
```

## Syntax
NiPrefs writes the preferences down to a text file using a pretty straightforward syntax that goes like this:
```nim
# Comment
# key=val
lang="en" # Keys do not require quotes
dark=false
scheme=> # Nested tables are defined with a greater than symbol and indentation-in
  background="#ffffff" # background belongs to scheme
  font=>
    family="UbuntuMono" # scheme/font/family
    size=15
    color="#000000"
users={"ElegantBeef": 28, "Rika": 22} # Tables are also supported (and keys do require quotes inside tables)
```

## Usage
_NiPrefs_ store your preferences in an `OrderedTable[string, PrefsNode]`, where `PrefsNode` is an object variation that supports the following types:
- `int`
- `nil`
- `seq` (there are no arrays)
- `bool`
- `char`
- `float`
- `string` (and raw strings)
- `OrderedTable[string, PrefsNode]` (nested tables)


```nim
import niprefs

# Default preferences are used the first time you run the program or whenever the file gets deleted.
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
}).initPrefs()

prefs["lang"] = "es"
assert prefs["lang"] == "es"

prefs.del("lang")

assert "lang" notin prefs
```

Check the [docs](https://patitotective.github.io/niprefs) for more.

***

## About
- Docs: https://patitotective.github.io/niprefs.
- Nimble: https://nimble.directory/pkg/niprefs.
- GitHub: https://github.com/Patitotective/niprefs.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: [**Patitotective#0127**](https://discord.com/users/762008715162419261).
- Twitter: [**@patitotective**](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.

***v0.1.0***

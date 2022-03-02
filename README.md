# NiPrefs
> _Store and manage preferences in a text file within a table-like structure._

## Installation
You can install _NiPrefs_ with [_nimble_](https://nimble.directory):
```sh
nimble install niprefs
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

let defaultPrefs = toPrefs {
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
}

var prefs = initPrefs(defaultPrefs)

prefs["lang"] = "es"
echo prefs["lang"]
>>> "es"

prefs.del("lang")
```

Check the [docs](https://patitotective.github.io/niprefs) for more.

***

## About
- Docs: https://patitotective.github.io/niprefs.
- GitHub: https://github.com/Patitotective/niprefs.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: **Patitotective#0127**.
- Tiwtter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.

***v.1.0***

# niprefs
A Nim library to manage preferences in a TOML file.

### This project is archived! Check out kdl-nim

## Installation
You can install niprefs with _nimble_:
```sh
nimble install niprefs
```
Or directly from this repo:
```sh
nimble install https://github.com/Patitotective/niprefs
```

## Usage
A `Prefs` object requires a `path` and a `default` preferences. A TOML file is created at `path` with `default` whenever it's not found, if it exists it will read it.  
To access the actual preferences (not the default) you may want to use `Prefs.content` and at the end of your program call `Prefs.save()` to update the preferences file.

`toToml` is a helpful macro to define your default preferences.  
Instead of having to write:
```nim
{"a": [1.newTInt(), 2.newTInt()].newTArray()}.newTTable()
```
Using the `toToml` it's just as easy as writing:
```nim
toToml {a: [1, 2]}
```

```nim
import niprefs

# Default preferences are used the first time you run the program or whenever the file gets deleted.
var prefs = initPrefs(
  path = "prefs.toml", 
  default = toToml {
  "lang": "en", # Keys do not require quotes when using toToml macro
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
})

prefs["lang"] = "es"
assert prefs["lang"] == "es"

prefs.delete("lang")

assert "lang" notin prefs

prefs.save()
```

Check the [docs](https://patitotective.github.io/niprefs) for more.

***

## About
- Docs: https://patitotective.github.io/niprefs.
- Nimble: https://nimble.directory/pkg/niprefs.
- GitHub: https://github.com/Patitotective/niprefs.
- Discord: https://discord.gg/gdcPVjazCG.

Contact me:
- Discord: [**Patitotective#0127**](https://discord.com/users/762008715162419261).
- Twitter: [**@patitotective**](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.

_Tested in Linux and Windows._  

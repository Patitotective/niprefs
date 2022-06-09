# To run these tests, simply execute `nimble test`.

import std/[unittest]
import niprefs

const path = "Prefs/subdir/settings.toml"

var defaultPrefs = toToml {
  lang: "en", 
  nums: [0b100001110011110101110100010001001101000101110100001011010000000f32, 0b100001110011110101110100010001001101000101110100001011010000000d, 0b100001110011110101110100010001001101000101110100001011010000000],
  dark: true,
  keybindings: [],
  users: {:},
  test: {
    c: [-1, 2, [3, {d: 4}], 5.2, -45.9d],
    d: ["a", "b"], 
  }, 
  scheme: {
    background: "#000000",
    font: {
      size: 15,
      family: "UbuntuMono",
      color: "#73D216", 
    }
  }
}

var prefs = initPrefs(path, defaultPrefs)
prefs.overwrite()

test "can write":
  prefs["lang"] = "es"
  defaultPrefs["lang"] = "es"

  prefs{"scheme", "font", "size"} = 20
  defaultPrefs{"scheme", "font", "size"} = 20

  check prefs.content == defaultPrefs

test "can remove":
  prefs.delete("lang")
  defaultPrefs.delete("lang")

  prefs["scheme"]["font"].delete("size")
  defaultPrefs["scheme"]["font"].delete("size")

  check prefs.content == defaultPrefs

test "contains and len":
  check ("keybindings" in prefs) == ("keybindings" in defaultPrefs)
  check prefs.len == defaultPrefs.len

test "can do stuff with nodes":
  var node = prefs["test"]

  node["c"][1] = 3
  node["c"][2] = newTInt(4)
  node["c"].add 5
  node["c"].add -6.newTInt()

  for i in node["c"]:
    discard

  for k, v in node:
    discard

  check node["c"] == toToml([-1, 3, 4, 5.2, -45.9, 5, -6])
  check "c" in node
  check 5.2 in node["c"]

test "can overwrite":
  prefs.overwrite("lang")
  defaultPrefs["lang"] = "en".newTNode()

  prefs.overwrite(["scheme", "font", "family"])
  defaultPrefs["scheme"]["font"]["family"] = "UbuntuMono".newTNode()

  check prefs.content == defaultPrefs

  prefs.overwrite(toToml({"theme": "dark"}))
  defaultPrefs = toToml({"theme": "dark"})

  check prefs.content == defaultPrefs

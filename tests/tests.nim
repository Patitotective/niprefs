# To run these tests, simply execute `nimble test`.

import std/[unittest]
import niprefs

const path = "Prefs/subdir/settings.toml"

let defaultPrefs = toToml {
  lang: "en", 
  nums: [0b100001110011110101110100010001001101000101110100001011010000000f32, 0b100001110011110101110100010001001101000101110100001011010000000d, 0b100001110011110101110100010001001101000101110100001011010000000],
  dark: true,
  keybindings: [],
  users: {:},
  test: {
    c: [-1, 2, [3, {d: 4}], 5.2, -45.9d],
    d: ["a", "b"], 
  }, 
  tables: toTTables [
    {a: 2, b: 2}, 
    {d: 0}
  ], 
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
var table = prefs.content.copy()

test "can write":
  prefs["lang"] = "es"
  prefs{"scheme", "font", "size"} = 20
  
  prefs["dark"] = false.newTBool()
  prefs{"scheme", "font", "family"} = "ProggyVector".newTString()

  table["lang"] = "es"
  table{"scheme", "font", "size"} = 20
  
  table["dark"] = false.newTBool()
  table{"scheme", "font", "family"} = "ProggyVector".newTString()

  check prefs.content == table

test "can remove":
  prefs.delete("lang")
  table.delete("lang")

  prefs["scheme"]["font"].delete("size")
  table["scheme"]["font"].delete("size")

  check prefs.content == table

test "contains and len":
  check ("keybindings" in prefs) == ("keybindings" in table)
  check prefs.len == table.len

test "can do stuff with nodes":
  let node = prefs["test"].copy()

  node["c"][1] = 3
  node["c"][2] = newTInt(4)
  node["lol"] = "a"

  node["c"].add 5
  node["c"].add -6.newTInt()

  node["lol"].add "b"

  for i in node["c"]:
    discard

  for k, v in node:
    discard

  check node["c"] == toToml([-1, 3, 4, 5.2, -45.9, 5, -6])
  check "c" in node
  check 5.2 in node["c"]
  check node["lol"] == "ab"

test "can overwrite":
  prefs.overwrite("lang")
  table["lang"] = "en".newTNode()

  prefs.overwrite(["scheme", "font", "family"])
  table["scheme"]["font"]["family"] = "UbuntuMono".newTNode()

  check prefs.content == table

  prefs.overwrite(toToml({"theme": "dark"}))
  table = toToml({"theme": "dark"})

  check prefs.content == table

# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[unittest, strutils]
import niprefs

const path = "settings.niprefs"

let defaultPrefs = toPrefs {
  lang: "en",
  dark: true,
  keybindings: [],
  users: {:},
  test: {
    c: [1, 2, [3, {d: 4}], 5]
  }, 
  scheme: {
    background: "#000000",
    font: {
      size: 15,
      family: "UbuntuMono",
      color: "#73D216"
    }
  }
}

var prefs = initPrefs(defaultPrefs, path)
prefs.overwrite()

test "can read":
  check prefs.content == prefs.table

test "can write":
  prefs["lang"] = "es"
  prefs.table["lang"] = "es".toPrefs

  prefs["scheme/font/size"] = 20
  prefs.table["scheme"]["font"]["size"] = 20.toPrefs

  check prefs.content == prefs.table

test "can write many":
  prefs.writeMany(toPrefs({"dark": false, "scheme/background": "#CF3030"}))
  
  prefs.table["dark"] = false.toPrefs
  prefs.table["scheme"]["background"] = "#CF3030".toPrefs
  
  check prefs.content == prefs.table

test "can remove":
  prefs.del("lang")
  prefs.table.del("lang")

  prefs.del("scheme/font/size")
  prefs.table["scheme"]["font"].del("size")

  check prefs.content == prefs.table

test "contains and len":
  check ("keybindings" in prefs) == ("keybindings" in prefs.table)
  check prefs.len == prefs.table.len

test "can parse":
  let text = """
  lang="en"
  dark=true
  float32=13f
  float64=69d
  scheme=>
    background="#ffffff"
    font="#000000"
  """.dedent()

  let content = toPrefs({
    "lang": "en", 
    "dark": true, 
    "float32": 13f,
    "float64": 69d,
    "scheme": {
      "background": "#ffffff", 
      "font": "#000000"
    }
  }).getObject()

  check text.parsePrefs() == content

test "can overwrite":
  prefs.table["lang"] = "en".toPrefs
  prefs.overwrite("lang")

  prefs.table["scheme"]["font"]["family"] = "UbuntuMono".toPrefs
  prefs.overwrite("scheme/font/family")

  check prefs.content == prefs.table

  prefs.overwrite(toPrefs({"theme": "dark"}).getObject())
  prefs.table = toPrefs({"theme": "dark"}).getObject()

  check prefs.content == prefs.table

# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import niprefs

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
prefs.overwrite()

test "can read":
  check prefs.content == prefs.table

test "can write":
  prefs["lang"] = "es"
  prefs.table["lang"] = "es".toPrefs

  prefs["scheme/font/size"] = 20
  prefs.table["scheme"]["font"] = 20.toPrefs

  # check prefs.content == prefs.table

test "can remove":
  prefs.del("lang")
  prefs.table.del("lang")

  prefs.del("scheme/font/size")
  # prefs.table["scheme"]["font"].del("size")

  # check prefs.content == prefs.table

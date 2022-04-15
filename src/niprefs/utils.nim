import std/[strutils, sequtils, tables, os]
import prefsnode

proc checkFile*(path: string) = 
  ## Iterate through `path.parentDir.parentDirs` from the root creating all the directories that do not exist.
  ## **Example:**
  ## ```nim
  ## checkFile("a/b/c") # Takes c as a file, not as a directory
  ## checkFile("a/b/c/d.png") # Only creates a/b/c directories
  ## ```
  for dir in path.parentDir.parentDirs(fromRoot=true):
    discard existsOrCreateDir(dir)

proc changeNested*(table: PObjectType, keys: varargs[string], val: PrefsNode): PObjectType =
  ## Changes nested `keys` for `val` in `table`.
  ## Returns a new table.
  
  assert keys.len > 0

  result = table
  var keys = keys.toSeq().mapIt(it.nimIdentNormalize())

  if keys[0] notin result:
    result[keys[0]] = newPObject()

  var scnDict = result[keys[0]]
  keys.delete(0)

  for e, key in keys:
    if e == keys.len - 1:
      scnDict[key] = val
    else:
      if key notin scnDict.objectV or (key in scnDict.objectV and scnDict[key].kind != PObject):
        scnDict[key] = newPObject()

      scnDict = scnDict[key]

proc getNested*(table: PObjectType, keys: varargs[string]): PrefsNode =
  ## Looks for the given nested `keys` in the `table`.

  assert keys.len > 0

  var keys = keys.toSeq().mapIt(it.nimIdentNormalize())
  result = table[keys[0]]
  keys.delete(0)

  for key in keys:
    if key in result.objectV:
      result = result[key]
    else:
      raise newException(KeyError, keys.join("/"))

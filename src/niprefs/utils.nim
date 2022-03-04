import std/[strutils, sequtils, tables, os]
import prefsnode

proc splitDir(path: string): seq[string] =
  ## Splits a directory path, normalizing, expanding the user and adding mount moint.
  var path = path.normalizedPath() # Remove redundant separators (A//B, A/B/, A/./B and A/foo/../B become A/B)
  path = path.expandTilde() # Convert "~" into the home user directory
  result = path.split(DirSep)

  if result[0] == "": # For unix systems
    result[0] = "/" # Add mount point if it got removed when spliting the result

  elif result[0].toLowerAscii == "c:":
    result[0] = r"C:\"

proc checkPath*(path: string) =
  ## Given a file path creates all the directories until the file if they don't exist.
  if fileExists(path):
    return

  let dirSeq = splitDir(splitFile(path).dir)
  var path = dirSeq[0]

  for e, dir in dirSeq:
    if dir.toLowerAscii notin [r"c:\", "/"]: # On Windows C:\ and / on Linux
      if e > 0:
        path = joinPath(path, dir) # joinPath("trial", "sub") -> "trial/sub" (on Windows "trial\sub")

      if not dirExists(path):
        createDir(path)

proc changeNested*(table: PObjectType, keys: varargs[string], val: PrefsNode): PObjectType =
  ## Changes nested `keys` for `val` in `table`.
  ## Returns a new table.
  
  assert keys.len > 0

  result = table
  var keys = keys.toSeq()

  if keys[0] notin result:
    result[keys[0]] = newPObject()

  var scnDict = result[keys[0]]
  keys.delete(0)

  for e, i in keys:
    if e == keys.len - 1:
      scnDict[i] = val
    else:
      if i notin scnDict.objectV or (i in scnDict.objectV and scnDict[
          i].kind != PObject):
        scnDict[i] = newPObject()

      scnDict = scnDict[i]

proc getNested*(table: PObjectType, keys: varargs[string]): PrefsNode =
  ## Looks for the given nested `keys` in the `table`.

  assert keys.len > 0

  var keys = keys.toSeq()
  result = table[keys[0]]
  keys.delete(0)

  for i in keys:
    if i in result.objectV:
      result = result[i]
    else:
      raise newException(KeyError, keys.join("/"))

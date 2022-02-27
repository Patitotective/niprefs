import std/[strutils, tables, os]
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

proc changeNested*(table: PObjectType, key: string, val: PrefsNode, keyPathSep: char): PObjectType =
  ## Changes the `val` of `key` in `table`, being `key`'s path separated by `keyPathSep`.
  ## If ``autoGenKeys`` is true, it will generated the missing keys in the path.
  ## Returns a new table.

  result = table
  var keyPath = key.split(keyPathSep)

  if keyPath[0] notin result:
    result[keyPath[0]] = newPObject()

  var scnDict = result[keyPath[0]]
  keyPath.delete(0)

  for e, i in keyPath:
    if e == keyPath.len - 1:
      scnDict[i] = val
    else:
      if i notin scnDict.objectV or (i in scnDict.objectV and scnDict[
          i].kind != PObject):
        scnDict[i] = newPObject()

      scnDict = scnDict[i]

proc change*(table: PObjectType, key: string, val: PrefsNode, keyPathSep: char): PObjectType =
  ## Changes `key` to the given `val`, if `keyPathSep` in `key`, calls `changeNested`.
  ## Returns a new table.

  if keyPathSep in key:
    result = table.changeNested(
      key,
      val,
      keyPathSep,
    )
  else:
    result = table
    result[key] = val

proc get*(table: PObjectType, key: string, keyPathSep: char): PrefsNode =
  ## Looks for the given `key` in the `table`,
  ## if `keyPathSep` in `key`, looks for nested tables.

  if keyPathSep in key:
    var keys = key.split(keyPathSep)
    result = table[keys[0]]
    keys.delete(0)

    for i in keys:
      if i in result.objectV:
        result = result[i]
      else:
        raise newException(KeyError, key)

  else:
    result = table[key]

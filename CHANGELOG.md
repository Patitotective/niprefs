# CHANGELOG

### v0.3.0
- Totally removed prefs parser, now using TOML.
- Not reading nor updating the file everytime you read it or write it anymore. Now using `content` field and the user must manually `save` it at the end to update the prefs file.

### v0.2.4
- Removed negative bin/bin/oct.
- Now using `int64` for `PInt`.
- Testing on i386.
- Fixed some floats parsing errors.

### v0.2.3
- Fixed `added` and `deleted` procs.
- Added `contains` for `PSeq`.

### v0.2.2
- Using `createDir` instead of `checkFile` to create the directories to the prefs path avoiding permission errors.

### v0.2.1
- Fixed bug with windows new lines.

### v0.2.0 (v0.1.7)
- Fixed error when parsing escaped sequences.

### v0.1.62
- Now normalizing keys on `contains` proc for `PObjectType` and `PrefsNode` (`kind=PObject`).

### v0.1.61
- Checks `PrefsBase` file path everytime it reads it.

### v0.1.6
- Better support for raw strings.
	- `newPString` and `newPNode` (string) now accept a `raw` parameter.

### v0.1.5
- Now keys are treated as Nim identifiers.
	- Only first letter is case-sensitive.
	- Case and underscore-insensitive.

### v0.1.4
- Added support for `set[char]` and `set[byte]`.

### v0.1.3
- Added compile-time support.
- Renamed `toPtree` -> `toString`.
- Now keys must be valid (Nim) identifiers.
- Renamed and improved `checkPath` -> `checkFile`

### v0.1.2
- Fixed bug when parsing negative numbers.
- Fixed bug when parsing float numbers.
- Removed `Prefs` iterator/templates.
- Added iterators for `PrefsNode` of kind `PSeq` and `PObject`
- Added `var` versions of all `getNode` procedures.
- Added `add` and `[]=` procedures for `PSeq`.
- Added `contains` for `PObject`.

### v0.1.1
- Now type suffixes do not require a single quote before them:
	- `13f == 13'f`
	- `69d64 == 69'd64`

### v0.1.0
- First (stable) version.

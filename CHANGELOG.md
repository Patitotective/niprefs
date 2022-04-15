# CHANGELOG

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

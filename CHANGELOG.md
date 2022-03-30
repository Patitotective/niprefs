# CHANGELOG

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

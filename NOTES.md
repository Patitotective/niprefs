# Notes

## To Generate Documentation
```sh
nim doc --project --outdir:docs src/niprefs.nim
```

## Parser
- Object start is detected by indentation in.
- Object end is detected by the difference between indentations.

## TODO
- Add table support to the parser.
- Generate the docs to test it.

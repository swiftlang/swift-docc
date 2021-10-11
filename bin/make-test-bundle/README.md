# make-test-bundle

A CLI tool that generates a Swift framework for testing with docc.

## Usage

```
swift run make-test-bundle --output path/to/folder --sizeFactor 10
```

 - `--output` the path to the output folder, `make-test-bundle` creates a sub-directory at that location called `TestFramework` and places its output inside.
 - `--sizeFactor` how many of each node to create. For example setting this parameter to 10 will create 10 protocols, 10 structs, 10 top-level functions, etc. Use a value greater than 1.
 
To preview the generated bundle documentation bundle run:
 
```
docc preview path/to/folder/TestFramework/Docs.docc
```

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

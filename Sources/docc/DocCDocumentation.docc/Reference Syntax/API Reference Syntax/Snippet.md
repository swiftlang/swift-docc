# ``docc/Snippet``

Embeds a code example from the project's code snippets.

```markdown
@Snippet(path: "my-package/Snippets/example-snippet", slice: "setup")
```

- Parameters:
    - path: A reference to the location of a code example.
    - slice: The name of a section within the code example that you annotate with comments in the snippet. **(optional)**

## Overview

Place the `Snippet` directive to embed a code example from the project's snippet directory. The path to the snippet is identified with three parts:

1. The package name as defined in `Package.swift`

2. The directory path to the snippet file, starting with "Snippets".

3. The name of your snippet file without the `.swift` extension

If the snippet had slices annotated within it, an individual slice of the snippet can be referenced with the `slice` option. Without the option defined, the directive embeds the entire snippet.

<!-- Copyright (c) 2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->


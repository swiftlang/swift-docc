# Adding Code Snippets to your Content

@Metadata {
    @Available("Swift", introduced: "5.7")
    @TitleHeading("Article")
 }

Create and include code snippets to illustrate and provide examples of how to use your API.

## Overview


DocC supports code listings in your code, as described in <doc:formatting-your-documentation-content>.
In addition to code listings written directly in the markup, Swift Package Manager and DocC supports compiler verified code examples called "snippets".

Swift Package Manager looks for, and builds, any code included in the `Snippets` directory for your package.
DocC supports referencing all, or parts, of those files to present as code listings.
In addition to snippets presenting your code examples, you can run snippets directly on the command line.
This allows you to verify that code examples, referenced in your documentation, continue to compile as you evolve you app or library.

### Add the Swift DocC plugin

To generate or preview documentation with snippets, add [swift-docc-plugin](https://github.com/apple/swift-docc-plugin) as a dependency to your package.

For example, use the command:

```bash
swift package add-dependency https://github.com/apple/swift-docc-plugin --from 1.1.0
```

Or edit your `Package.swift` to add the dependency:

```
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        // targets
    ]
)
```

### Create a code snippet

Swift Package Manager expects to find your code examples in the directory `Snippets` at the top of your project, parallel to the file `Package.swift` and the directory `Sources`. 
At the root of your project, create the directory `Snippets`.
Within the `Snippets` directory, create a file with your code snippet.

Your Swift package directory structure should resemble this:

```
YourProject
  ├── Package.swift
  ├── Snippets
  │   └── example-snippet.swift
  ├── Sources
  │   └── YourProject
  │       └── YourProject.swift
etc...
```

> Note: Snippets are a package-wide resource located in a "Snippets" directory next to the package's "Sources" and "Tests" directories.

The following example illustrates a code example in the file `Snippets/example-snippet.swift`:

```swift
import Foundation

print("Hello")
```

Your snippets can import targets defined in your local package, as well as products from its direct dependencies.
Each snippet is its own unit and can't access code from other snippet files.

Every time you build your project, the Swift Package Manager compiles any code snippets, and then fails if the build if they are unable to compile.

### Run the snippet

You and consumers of your library can run your snippets from the command line using `swift run snippet-name` where "snippet-name" corresponds to a file name in your Snippets directory without the ".swift" file extension.

Run the earlier code example file named `example-snippet.swift` using the following command:

```bash
swift run example-snippet
```

### Embed the snippet

To embed your snippet in an article or within the symbol reference pages, use the `@Snippet` directive.
```markdown
@Snippet(path: "my-package/Snippets/example-snippet")
```

The `path` argument has three parts:

1. The package name as defined in `Package.swift`

2. The directory path to the snippet file, starting with "Snippets".

3. The name of your snippet file without the `.swift` extension

In the example package above, the `YourProject.md` file might contain this markdown:

```markdown
# ``YourProject``

Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.

## Overview

Add one or more paragraphs that introduce your content overview.

This paragraph appears before the snippet.

@Snippet(path: "YourProject/Snippets/example-snippet")

This paragraph appears after the snippet.
```

If your snippet code requires setup — like imports or variable definitions — that distract from the snippet's main focus, you can add `// snippet.hide` and `// snippet.show` lines in the snippet code to exclude the lines in between from displaying in your documentation.
These comments act as a toggle to hide or show content from the snippet.

```swift
print("Hello")

// snippet.hide

print("Hidden")

// snippet.show

print("Shown")
```

Hide segments of your snippet for content such as license footers, test code, or unique setup code.
Generally, it is useful for things that you wouldn't want the reader to use as a starting point.

### Preview your content

Use the [swift-docc-plugin](https://github.com/swiftlang/swift-docc-plugin) to preview content that includes snippets.
To run the preview, use the following command from a terminal. 
Replace `YourTarget` with a target from your package to preview:

```bash
swift package --disable-sandbox preview-documentation --target YourTarget
```

### Slice up your snippet to break it up in your content.

Long snippets dropped into documentation can result in a wall of text that is harder to parse and understand.
Instead, annotate non-overlapping slices in the snippet, which allows you to reference and embed the slice portion of the example code.

Annotating slices in a snippet looks similiar to annotating `snippet.show` and `snippet.hide`.
You define the slice's identity in the comment, and that slice continues until the next instance of `// snippet.end` appears on a new line.
When selecting your identifiers, use URL-compatible path characters.

For example, to start a slice with an ID of `setup`, add the following comment on a new line.

```swift
// snippet.setup
```

Then end the `setup` slice with:

```swift
// snippet.end
```

Adding a new slice identifier automatically terminates an earlier slice.
For example, the follow code examples are effectively the same:

```swift
// snippet.setup
var item = MyObject.init()
// snippet.end

// snipppet.configure
item.size = 3
// snippet.end
```

```swift
// snippet.setup
var item = MyObject.init()

// snipppet.configure
item.size = 3
```

Use the `@Snippet` directive with the `slice` parameter to embed that slice as sample code on your documentation.
Extending the earlier snippet example, the slice `setup` would be referenced with 

```markdown
@Snippet(path: "my-package/Snippets/example-snippet", slice: "setup")
```

### Documenting the code in your snippet

DocC parses contiguous comments within the code of a snippet as markdown to annotate your code when embedded in documentation.
DocC will attempt to reference symbols from within these comments just like any other documentation content.
You can reference symbols from your API, which DocC converts into hyperlinks to that symbol when displaying the content.

## Topics

### Directives

- ``Snippet``

<!-- Copyright (c) 2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->

# Adding Code Snippets to your Content

Create and include code snippets to illustrate and provide examples of how to use your API.

## Overview

...tbd...
- Describe the problem and summarize the developer action.
- Explain why the problem is relevant and provide context for the task. Don't simply repeat the abstract; expand on it.
- Keep the Overview to one or two paragraphs.
- For very short articles that consist of just a couple of paragraphs, all of the content can be in the Overview.

...tbd...

### Create a code snippet

Swift Package Manager expects to find your code examples in the directory `Snippets` at the top of your project, parallel to the file `Package.swift` and the directory `Sources`. 
At the root of your project, create the directory `Snippets`.
Within the Snippets directory, create a file with your code snippet.

The following example illustrates a code example in the file `Snippets/example-snippet.swift`:

```swift
import Foundation

print("Hello")
```

Within your snippet, you can import your local module, as well as any module that your package depends on.

Every time you build your project, the Swift Package Manager compiles any code snippets, and then fails if the build if they are unable to compile.

### Run the snippet

Each code example file you create becomes it's own module.
The name of the code example file you create is the name of the module that Swift creates.
Use the `swift run` command in a terminal to compile and run the module to verify it compiles does what you expect.

Run the earlier code example file named `example-snippet.swift` using the following command:

```bash
swift run example-snippet
```

### Reference the snippet

To reference your snippet in an article or within the symbol reference pages, use the `@Snippet` directive.
```markdown
@Snippet(path: "my-package/Snippets/example-snippet")
```

The `path` argument has three parts:

1. The package name as defined in `Package.swift`

2. The directory path to the snippet file, starting with "Snippets".

3. The name of your snippet file without the `.swift` extension

Without any additional annotations in your snippet, Docc includes the entirety of your code example as the snippet.
To prevent parts of your snippet file from being rendered in documentation, add comments in your code in the format `// snippet.hide` and `// snippet.show` on new lines, surrounding the content you want to hide.
These comments act as a toggle to hide or show content from the snippet.

```swift
print("Hello")

// snippet.hide

print("Hidden")

// snippet.show

print("Shown")
```

Hide segments of your snippet for things like license footers, test code, or unique setup code.
Generally, it is mostly useful for things that you wouldn't want the reader to take with them as a starting point.

### Preview your content

Use the [swift-docc-plugin](https://github.com/swiftlang/swift-docc-plugin) to preview content that includes snippets.
To run the preview, use the following command from a terminal:

```bash
swift package --disable-sandbox preview-documentation 
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

DocC parses contiguous comments within your the code of a snippet as markdown to annotate your code when embedded in documentation.
DocC will attempt to reference symbols from within these comments just like any other documentation content.
You can reference symbols from your API, which DocC converts into hyperlinks to that symbol when displaying the content.

<!-- Copyright (c) 2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->


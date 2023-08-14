# Swift-DocC

Swift-DocC is a documentation compiler for Swift frameworks and packages aimed 
at making it easy to write and publish great developer documentation.

For an example of Swift-DocC in action, check out 
[developer.apple.com](https://developer.apple.com/documentation).
Much of Apple's developer documentation,
from [Reference documentation](https://developer.apple.com/documentation/GroupActivities)
to [Tutorials](https://developer.apple.com/tutorials/swiftui),
and [long-form content](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/)
is built using Swift-DocC.

To learn more about the essentials of this tool 
refer to the
[user documentation](https://www.swift.org/documentation/docc).

Swift-DocC is being actively developed. For more information about the
Swift-DocC project, see the introductory blog post
[here](https://swift.org/blog/swift-docc/).

The latest documentation for the Swift-DocC project is available
on [Swift.org](https://swift.org/documentation/docc).

The [Swift Forums](https://forums.swift.org/c/development/swift-docc) are
the best place to get help with Swift-DocC and discuss future plans.

## Getting Started with DocC

`docc` is the command line interface (CLI) for Swift-DocC and provides
support for converting and previewing DocC documentation.

There are multiple ways you can make use of DocC depending on your use case:

**1. For standalone documentation:**

If you have Xcode installed, it's recommended to generate documentation using the `xcrun` command.
You can get DocC working by invoking:
```
xcrun docc
```
in your terminal.
Swift-DocC is also included in the toolchain for both macOS and Linux.

**2. For documenting frameworks via SPM:**

If you want to generate documentation for your Swift package we recommend using the Swift-DocC Plugin. Please
refer to the Plugin's [documentation](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/) to get started with 
[building](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-a-specific-target), [previewing](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/previewing-documentation),
and publishing your documentation to your [website](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-hosting-online) or [GitHub Pages](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/publishing-to-github-pages).

**3. For documenting apps, frameworks, and packages using Xcode:**

If you want to generate an API reference for your project you can use DocC via the Xcode GUI.
Please refer to the Xcode [documentation](https://developer.apple.com/documentation/xcode/documenting-apps-frameworks-and-packages)
to learn the essentials of how to get started.

## Writing and Publishing Documentation with Swift-DocC

The Starter Template provides the quickest, and easiest way to create a new article-only documentation website making use of DocC. 
To get started just click "[use the template](https://github.com/sofiaromorales/DocC-Starter-Template)"!

If you want to learn how to write and format your documentation please refer to
[Formatting Your Documentation Content](https://www.swift.org/documentation/docc/formatting-your-documentation-content).
For publishing go to [Distributing Documentation to Other Developers](https://www.swift.org/documentation/docc/distributing-documentation-to-other-developers).

## Technical Overview and Related Projects

Swift-DocC builds documentation by combining _Symbol Graph_ files containing API information 
with a `.docc` Documentation Catalog containing articles and tutorials
to create a final archive containing the compiled documentation.

More concretely, Swift-DocC understands the following kinds of inputs:

 1. _Symbol Graph_ files with the `.symbols.json` extension.
   _Symbol Graph_ files are a machine-readable representation of a module's APIs, 
   including their documentation comments and relationship with one another.

 2. A Documentation Catalog with the `.docc` extension. 
   Documentation Catalogs can include additional documentation content like the following:
  
   - Documentation markup files with the `.md` extension. Documentation markup files can
    be used to extend documentation for symbols and to write free-form articles.
 
   - Tutorial files with the `.tutorial` extension. Tutorial files are used to author
    step-by-step instructions on how to use a framework.
 
   - Additional documentation assets with known extensions like `.png`, `.jpg`, `.mov`,
    and `.zip`.
 
   - An `Info.plist` file containing metadata such as the name of the documented module. 
    This file is optional and the information it contains can be passed via the command line.

Swift-DocC outputs a machine-readable archive of the compiled documentation.
This archive contains _render JSON_ files, which fully describe the contents
of a documentation page and can be processed by a renderer such as
[Swift-DocC-Render](https://github.com/apple/swift-docc-render).

For more in-depth technical information about Swift-DocC, please refer to the
project's technical documentation:

- [`SwiftDocC` framework documentation](https://apple.github.io/swift-docc/documentation/swiftdocc/)
- [`SwiftDocCUtilities` framework documentation](https://apple.github.io/swift-docc/documentation/swiftdoccutilities/)

### Related Projects

 - As of Swift 5.5, the [Swift Compiler](https://github.com/apple/swift) is able to 
  emit _Symbol Graph_ files as part of the compilation process.
   
 - [SymbolKit](https://github.com/apple/swift-docc-symbolkit) is a Swift package containing
  the specification and reference model for the _Symbol Graph_ File Format.
  
 - [Swift Markdown](https://github.com/apple/swift-markdown) is a 
  Swift package for parsing, building, editing, and analyzing 
  Markdown documents. It includes support for the Block Directive elements
  that Swift-DocC's tutorial files rely on.
   
 - [Swift-DocC-Render](https://github.com/apple/swift-docc-render) 
  is a web application that understands and renders
  Swift-DocC's _render JSON_ format.
   
 - [Xcode](https://developer.apple.com/xcode/) consists of a suite of
  tools that developers use to build apps for Apple platforms.
  Beginning with Xcode 13, Swift-DocC is integrated into Xcode
  with support for building and viewing documentation for your framework and
  its dependencies.

## Versioning

Swift-DocC's CLI tool (`docc`) will be integrated into the Swift toolchain 
and follows the Swift compiler's versioning scheme.

The `SwiftDocC` library is versioned separately from `docc`. `SwiftDocC` is under
active development and source stability is not guaranteed.

## Bug Reports and Feature Requests

### Submitting a Bug Report

Swift-DocC tracks all bug reports with 
[GitHub Issues](https://github.com/apple/swift-docc/issues).
When you submit a bug report we ask that you follow the
[provided template](https://github.com/apple/swift-docc/issues/new?assignees=&labels=bug&template=BUG_REPORT.yml)
and provide as many details as possible.

> **Note:** You can use the [`environment`](bin/environment) script
> in this repository to gather helpful environment information to paste
> into your bug report by running the following:
> 
> ```sh
> bin/environment
> ```

If you can confirm that the bug occurs when using the latest commit of Swift-DocC
from the `main` branch (see [Building Swift-DocC](/CONTRIBUTING.md#building-swift-docc)),
that will help us track down the bug faster.

### Submitting a Feature Request

For feature requests, please feel free to file a
[GitHub issue](https://github.com/apple/swift-docc/issues/new?assignees=&labels=enhancement&template=FEATURE_REQUEST.yml)
or start a discussion on the [Swift Forums](https://forums.swift.org/c/development/swift-docc).

Don't hesitate to submit a feature request if you see a way
Swift-DocC can be improved to better meet your needs.

All user-facing features must be discussed
in the [Swift Forums](https://forums.swift.org/c/development/swift-docc)
before being enabled by default.

## Contributing to Swift-DocC

As an open-source project, we value any contribution made to this tool.
Please see the [contributing guide](/CONTRIBUTING.md) for more information on how to 
contribute and build DocC from source.

The [Swift Forums](https://forums.swift.org/c/development/swift-docc) are
the best place to get help with Swift-DocC and discuss future plans.

<!-- Copyright (c) 2021-2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->

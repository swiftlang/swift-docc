# Swift-DocC

Swift-DocC is a documentation compiler for Swift frameworks and packages aimed 
at making it easy to write and publish great developer documentation.

For an example of Swift-DocC in action, check out 
[developer.apple.com](https://developer.apple.com/documentation).
Much of Apple's developer documentation,
from [Reference documentation](https://developer.apple.com/documentation/GroupActivities)
to [Tutorials](https://developer.apple.com/tutorials/swiftui),
is built using Swift-DocC.

Swift-DocC is being actively developed. For more information about the
Swift-DocC project, see the introductory blog post
[here](https://swift.org/blog/swift-docc/).

The latest documentation for the Swift-DocC project is available
on [Swift.org](https://swift.org/documentation/docc).

The [Swift Forums](https://forums.swift.org/c/development/swift-docc) are
the best place to get help with Swift-DocC and discuss future plans.

## Writing and Publishing Documentation with Swift-DocC

If you're looking to write and publish documentation with Swift-DocC, 
the best way to get started is with Swift-DocC's
[user documentation](https://www.swift.org/documentation/docc).

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
  
## Getting started with developing `docc`

`docc` is the command line interface (CLI) for Swift-DocC and provides
support for converting and previewing DocC documentation.

### Prerequisites

DocC is a Swift package. If you're new to Swift package manager,
the [documentation here](https://swift.org/getting-started/#using-the-package-manager)
provides an explanation of how to get started and the software you'll need
installed.

DocC requires Swift 5.5 which is included in Xcode 13.

### Build

1. Checkout this repository using:

    ```bash
    git clone https://github.com/apple/swift-docc.git
    ```

2. Navigate to the root of the repository with:

    ```bash
    cd swift-docc
    ```

3. Finally, build DocC by running:

    ```bash
    swift build
    ```

### Run

To run `docc`, run the following command:

  ```bash
  swift run docc
  ```
  
### Installing into Xcode

You can test a locally built version of Swift-DocC in Xcode 13 or later by setting
the `DOCC_EXEC` build setting to the path of your local `docc`:

  1. Select the project in the Project Navigator.
  
  2. In the Build Settings tab, click '+' and then 'Add User-Defined Setting'. 
  
  3. Create a build setting `DOCC_EXEC` with the value set to `/path/to/docc`. 

The next time you invoke a documentation build with the "Build Documentation"
button in Xcode's Product menu, your custom `docc` will be used for the build.
You can confirm that your custom `docc` is being used by opening the latest build
log in Xcode's report navigator and expanding the "Compile documentation" step.

### Invoking `docc` from Swift Package Manager

You can also test a locally built version of Swift-DocC using the Swift Package
Manager from the command line. The Swift-DocC SwiftPM plugin will try to read
`DOCC_EXEC` environment variable value, and use the path you provded if it's set.

  1. In your project's `Package.swift`, add a dependency on the [`Swift-DocC Plugin`](https://github.com/apple/swift-docc-plugin).
  2. Set the `DOCC_EXEC` environment variable and run the documentation generation
     command:

        ```bash
        DOCC_EXEC=/path/to/docc swift package generate-documentation
        ```

## Using `docc` to build and preview documentation

The preferred way of building documentation for your Swift package is by using
the Swift-DocC Plugin, or if you're using Xcode, using the "Build Documentation" command. 

Refer to instructions in the plugin's 
[documentation](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/)
to get started with [building](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-a-specific-target), [previewing](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/previewing-documentation),
and publishing your documentation to your [website](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-hosting-online) or [GitHub Pages](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/publishing-to-github-pages).

Alternatively, you can manually generate symbol graph files and invoke `docc` directly. 
Refer to instructions in [CONTRIBUTING.md](/CONTRIBUTING.md#assembling-symbol-graphs-and-building-with-docc-directly).
  
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

Please see the [contributing guide](/CONTRIBUTING.md) for more information.

<!-- Copyright (c) 2021-2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->

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
  
## Getting Started with `docc`

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
  
## Using `docc` to build and preview documentation

You can use `docc` directly to build documentation for your Swift framework
or package. The below instructions use this repository as an example but
apply to any Swift package. Just replace any reference to `SwiftDocC` below
with the name of your package.

### 1. Generate a symbol graph file

Begin by navigating to the root of your Swift package.

```sh
cd ~/Developer/swift-docc
```

Then run the following to generate _Symbol Graph_ files for your target:

```sh
mkdir -p .build/symbol-graphs && \
  swift build --target SwiftDocC \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs
```

You should now have a number of `.symbols.json` files in `.build/symbol-graphs`
representing the provided target and its dependencies. You can copy out the files representing
just the target itself with:

```sh
mkdir .build/swift-docc-symbol-graphs \
  && mv .build/symbol-graphs/SwiftDocC* .build/swift-docc-symbol-graphs
```

### 2. Set the path to your renderer

The best place to get started with Swift-DocC-Render is with the
instructions in the [project's README](https://github.com/apple/swift-docc-render).

If you have Xcode 13 or later installed, you can use the version of Swift-DocC-Render
that comes included in Xcode with:

```sh
export DOCC_HTML_DIR="$(dirname $(xcrun --find docc))/../share/docc/render"
```

Alternatively, you can clone the 
[Swift-DocC-Render-Artifact repository](https://github.com/apple/swift-docc-render-artifact)
and use a recent pre-built copy of the renderer:

```sh
git clone https://github.com/apple/swift-docc-render-artifact.git
```

Then point the `DOCC_HTML_DIR` environment variable
to the repository's `/dist` folder.

```sh
export DOCC_HTML_DIR="/path/to/swift-docc-render-artifact/dist"
```

### 3. Preview your documentation

The `docc preview` command performs a conversion of your documentation and
starts a local web server to allow for easy previewing of the built documentation.
It monitors the provided Documentation Catalog for changes and updates the preview
as you're working.

```sh
docc preview Sources/SwiftDocC/SwiftDocC.docc \
  --fallback-display-name SwiftDocC \
  --fallback-bundle-identifier org.swift.SwiftDocC \
  --fallback-bundle-version 1.0.0 \
  --additional-symbol-graph-dir .build/swift-docc-symbol-graphs
```

You should now see the following in your terminal:

```
Input: ~/Developer/swift-docc/Sources/SwiftDocC/SwiftDocC.docc
Template: ~/Developer/swift-docc-render-artifact/dist
========================================
Starting Local Preview Server
   Address: http://localhost:8080/documentation/swiftdocc
========================================
Monitoring ~/Developer/swift-docc/Sources/SwiftDocC/SwiftDocC.docc for changes...
```

And if you navigate to <http://localhost:8080/documentation/swiftdocc> you'll see
the rendered documentation for `SwiftDocC`.
  
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

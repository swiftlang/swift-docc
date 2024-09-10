# Contributing to Swift-DocC

## Introduction

### Welcome

Thank you for considering contributing to Swift-DocC.

Please know that everyone is welcome to contribute to Swift-DocC.
Contributing doesn’t just mean submitting pull requests—there are 
many different ways for you to get involved,
including answering questions on the 
[Swift Forums](https://forums.swift.org/c/development/swift-docc),
reporting or screening bugs, and writing documentation. 

No matter how you want to get involved,
we ask that you first learn what’s expected of anyone who participates in
the project by reading the [Swift Community Guidelines](https://swift.org/community/)
as well as our [Code of Conduct](/CODE_OF_CONDUCT.md).

This document focuses on how to contribute code and documentation to
this repository.

### Legal

By submitting a pull request, you represent that you have the right to license your
contribution to Apple and the community, and agree by submitting the patch that your 
contributions are licensed under the Apache 2.0 license (see [`LICENSE.txt`](/LICENSE.txt)).

## Contributions Overview

Swift-DocC is an open source project and we encourage contributions
from the community.

### Contributing Code and Documentation

Before contributing code or documentation to Swift-DocC,
we encourage you to first open a 
[GitHub issue](https://github.com/swiftlang/swift-docc/issues/new/choose) 
for a bug report or feature request.
This will allow us to provide feedback on the proposed change.
However, this is not a requirement. If your contribution is small in scope,
feel free to open a PR without first creating an issue.

All changes to Swift-DocC source must go through the PR review process before
being merged into the `main` branch.
See the [Code Contribution Guidelines](#code-contribution-guidelines) below for
more details.

## Building Swift-DocC

`docc` is the command line interface (CLI) for Swift-DocC and provides
support for generating and previewing documentation.

### Prerequisites

Swift-DocC is a Swift package. If you're new to Swift package manager,
the [documentation here](https://swift.org/getting-started#using-the-package-manager)
provides an explanation of how to get started and the software you'll need
installed.

### Build Steps

1. Checkout this repository using:

    ```bash
    git clone git@github.com:apple/swift-docc.git
    ```

2. Navigate to the root of your cloned repository with:

    ```bash
    cd swift-docc
    ```

3. Create a new branch off of `main` for your change using:

    ```bash
    git checkout -b branch-name-here
    ```

    Note that `main` (the repository's default branch) will always hold the most
    recent approved changes. In most cases, you should branch off of `main` when
    starting your work and open a PR against `main` when you're ready to merge
    that work.

4. Build Swift-DocC from the command line by running:

    ```bash
    swift build
    ```

    Alternatively, to use Xcode, open the `Package.swift` file
    at the repository's root. Then, build it by pressing Command-B.

### Run Steps

You can run your newly built version of `docc` with:

  ```bash
  swift run docc
  ```

Or, in Xcode, run the `docc`
[scheme](https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project).

### Miscellaneous

The JSON output of Swift-DocC is optimized for file size. If you need to inspect it
for debugging purposes set the `DOCC_JSON_PRETTYPRINT` environment variable
to "YES" to enable pretty printing.

  ```bash
  export DOCC_JSON_PRETTYPRINT="YES"
  ```

## Code Contribution Guidelines

### Overview

- Do your best to keep the git history easy to understand.
  
- Use informative commit titles and descriptions.
  - Include a brief summary of changes as the first line.
  - Describe everything that was added, removed, or changed, and why.

- All changes must go through the pull request review process.

- Follow the [Swift API Design guidelines](https://swift.org/documentation/api-design-guidelines/).

### Pull Request Preparedness Checklist

When you're ready to have your change reviewed, please make sure you've completed the following
requirements:

- [x] Add tests to cover any new functionality or to prevent regressions of a bug fix.

- [x] Run the `/bin/test` script and confirm that the test suite passes.
  (See [Testing Swift-DocC](#testing-swift-docc).)

- [x] Add source code documentation to all added or modified APIs that explains
  the new behavior.

### Opening a Pull Request

When opening a pull request, please make sure to fill out the pull request template
and complete all tasks mentioned there.

Your PR should mention the number of the GitHub issue your work is addressing.
  
Most PRs should be against the `main` branch. If your change is intended 
for a specific release, you should also create a separate branch 
that cherry-picks your commit onto the associated release branch.

### Code Review Process

All PRs will need approval from someone on the core team
(someone with write access to the repository) before being merged.

All PRs must pass the required continuous integration tests as well.
If you have commit access, you can run the required tests by commenting the following on your PR:

```
@swift-ci Please smoke test
```

If you do not have commit access, please ask one of the code owners to trigger them for you.
For more details on Swift-DocC's continuous integration, see the
[Continous Integration](#continuous-integration) section below.

### Introducing source breaking changes

We try to avoid source breaking changes, for example:

- removing or renaming public API
- adding protocol requirements to public API
- renaming Render JSON keys or adding new required Render JSON keys

That said, sometimes there are good reasons to make these changes. In those cases we make an effort to offer
a backwards compatible transition by deprecating the old API, alongside the new API, and keeping the deprecated
API for at least one full minor release. For example, if we deprecate an API sometime after the 5.5 release we
keep the deprecated API for the remainder of the upcoming release (5.6) and the entirety of the next release (5.7).   

To indicate to API consumers how long the deprecated API will be available, include the version when we'll remove
that API in the deprecation message. For example:

```swift
@available(*, deprecated, message: "Use 'UpdatedSymbolName' instead. This deprecated API will be removed after 5.7 is released")
```

## Testing Swift-DocC

Swift-DocC is committed to maintaining a high level of code quality.
Before opening a pull request, we ask that you:

1. Run the full test suite and confirm that it passes.

2. Write new tests to cover any changes you made.

The test suite can be run with the provided [`test`](/bin/test) script
by navigating to the root of the repository and running the following:

  ```bash
  bin/test
  ```

By running tests locally with the `test` script you will be best prepared for
automated testing in CI as well.

### Testing in Xcode

You can test a locally built version of Swift-DocC in Xcode 13 or later by setting
the `DOCC_EXEC` build setting to the path of your local `docc`:

1. Select the project in the Project Navigator.
2. In the Build Settings tab, click '+' and then 'Add User-Defined Setting'. 
3. Create a build setting `DOCC_EXEC` with the value set to `/path/to/docc`. 

The next time you invoke a documentation build with the "Build Documentation"
button in Xcode's Product menu, your custom `docc` will be used for the build.
You can confirm that your custom `docc` is being used by opening the latest build
log in Xcode's report navigator and expanding the "Compile documentation" step.

### Assembling symbol graphs and building with `docc` directly

Another option is to pass additional flags to the Swift compiler and invoking `docc` directly. 
The below instructions use this repository as an example but apply to any Swift package. Just 
replace any reference to `SwiftDocC` below with the name of your package.

#### 1. Generate a symbol graph file

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

#### 2. Set the path to your renderer

The best place to get started with Swift-DocC-Render is with the
instructions in the [project's README](https://github.com/swiftlang/swift-docc-render).

If you have Xcode 13 or later installed, you can use the version of Swift-DocC-Render
that comes included in Xcode with:

```sh
export DOCC_HTML_DIR="$(dirname $(xcrun --find docc))/../share/docc/render"
```

Alternatively, you can clone the 
[Swift-DocC-Render-Artifact repository](https://github.com/swiftlang/swift-docc-render-artifact)
and use a recent pre-built copy of the renderer:

```sh
git clone https://github.com/swiftlang/swift-docc-render-artifact.git
```

Then point the `DOCC_HTML_DIR` environment variable
to the repository's `/dist` folder.

```sh
export DOCC_HTML_DIR="/path/to/swift-docc-render-artifact/dist"
```

#### 3. Preview your documentation

The `docc preview` command performs a conversion of your documentation and
starts a local web server to allow for easy previewing of the built documentation.
It monitors the provided documentation catalog for changes and updates the preview
as you're working.

```sh
swift run docc preview Sources/SwiftDocC/SwiftDocC.docc \
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

### Using Docker to Test Swift-DocC for Linux

Today, Swift-DocC supports both macOS and Linux. While most Swift APIs are
cross-platform, there are some minor differences.
Because of this, all PRs will be automatically tested in both macOS
and Linux environments.

macOS users can test that their changes are compatible with Linux
by running the test suite in a Docker environment that simulates Swift on Linux.

1. Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop).

2. Build Swift-DocC (see [Building Swift-DocC](#building-swift-docc)).

3. Run the following command from the root of this repository
   to build the Swift-DocC Docker image:

    ```bash
    docker build -t swift-docc:latest .
    ```

4. Run the following command to run the test suite:

    ```bash
    docker run -v `pwd`:/swift-docc swift-docc sh -c 'swift test --package-path /swift-docc --parallel --skip-update'
    ```

5. To interactively test the command line interface,
   first log into the container with:

    ```bash
    docker run -i -t -v `pwd`:/swift-docc swift-docc /bin/bash
    ```

    And then run `docc` within the container:

    ```bash
    cd swift-docc
    swift run docc
    ```
    
## Continuous Integration

Swift-DocC uses [swift-ci](https://ci.swift.org) infrastructure for its continuous integration
testing. The tests can be triggered on pull-requests if you have commit access. 
If you do not have commit access, please ask one of the code owners to trigger them for you.

1. **Smoke Test _(required)_:** Run the project's unit tests on macOS and Linux by commenting the
   following:

    ```
    @swift-ci Please smoke test
    ```

    This is **required** before a pull-request can be merged.
    
    <details>
     <summary>Platform specific instructions:</summary>
     
     1. Run the project's unit tests on **macOS** by commenting the following:
     
         ```
         @swift-ci Please smoke test macOS platform
         ```
     
     2. Run the project's unit tests on **Linux** by commenting the following:
     
         ```
         @swift-ci Please smoke test Linux platform
         ```
     
    </details>

2. **Test:** Run the project's unit tests on macOS and Linux, along with a selection
   of compatibility suite tests on macOS by commenting the following:

    ```
    @swift-ci Please test
    ```
    
    <details>
     <summary>Platform specific instructions:</summary>
     
     1. Run the project's unit tests on **macOS**, along with a selection of compatibility suite
        tests by commenting the following:
     
         ```
         @swift-ci Please test macOS platform
         ```
     
     2. Run the project's unit tests on **Linux** by commenting the following:
     
         ```
         @swift-ci Please test Linux platform
         ```
         
         > **Note**: This is equivalent to running smoke tests for the Linux platform.
     
    </details>
    
3. **Compatibility Test:** Run the Swift compatibility suite tests in both Release and Debug 
   configuration by commenting the following:
   
     ```
     @swift-ci Please test source compatibility
     ```
   
    <details>
      <summary>Build configuration specific instructions:</summary>
      
      1. Run the Swift compatibility suite tests in **Release** configuration
         by commenting the following:
      
          ```
          @swift-ci Please test source compatibility Release
          ```
      
      2. Run the Swift compatibility suite tests in **Debug** configuration
         by commenting the following:
      
          ```
          @swift-ci Please test source compatibility Debug
          ```
      
     </details>

4. **Performance Smoke Test:** Test compiler performance on macOS with **a selection** of Swift
   compatibility suite projects by commenting the following:

    ```
    @swift-ci Please smoke test compiler performance
    ```

5. **Performance Test:** Test compiler performance on macOS with **all** Swift compatibility
   suite projects by commenting the following:

    ```
    @swift-ci Please test compiler performance
    ```
    
## Your First Contribution

Unsure of where to begin contributing to Swift-DocC? You can start by looking at
the issues on the [good first issue](https://github.com/swiftlang/swift-docc/contribute)
page.

Once you've found an issue to work on,
follow the above instructions for [Building Swift-DocC](#building-swift-docc).

## Technical Overview and Related Projects

Swift-DocC builds documentation by combining _Symbol Graph_ files that contains API information 
with a `.docc` documentation catalog that contains articles and tutorials
to create a final archive with the compiled documentation.

More concretely, Swift-DocC understands the following kinds of inputs:

 1. _Symbol Graph_ files with the `.symbols.json` extension.
   _Symbol Graph_ files are a machine-readable representation of a module's APIs, 
   including their documentation comments and relationship with one another.

 2. A documentation catalog directory with the `.docc` extension. 
   Documentation catalogs can include additional documentation content like the following:
  
   - Documentation markup files with the `.md` extension. Documentation markup files can
    be used to write articles and to extend documentation for symbols.
 
   - Tutorial files with the `.tutorial` extension. Tutorial files are used to author
    step-by-step instructions on how to use a framework.
 
   - Additional documentation assets with known extensions like `.png`, `.jpg`, `.mov`,
    and `.zip`.
 
   - An `Info.plist` file containing metadata such as the name of the documented module. 
    This file is optional and the information it contains can be passed via the command line.

Swift-DocC outputs a machine-readable archive of the compiled documentation.
This archive contains _render JSON_ files, which fully describe the contents
of a documentation page and can be processed by a renderer such as
[Swift-DocC-Render](https://github.com/swiftlang/swift-docc-render).

For more in-depth technical information about Swift-DocC, please refer to the
project's technical documentation:

- [`SwiftDocC` framework documentation](https://swiftlang.github.io/swift-docc/documentation/swiftdocc/)
- [`SwiftDocCUtilities` framework documentation](https://swiftlang.github.io/swift-docc/documentation/swiftdoccutilities/)

### Related Projects

 - As of Swift 5.5, the [Swift Compiler](https://github.com/apple/swift) is able to 
  emit _Symbol Graph_ files as part of the compilation process.
   
 - [SymbolKit](https://github.com/swiftlang/swift-docc-symbolkit) is a Swift package containing
  the specification and reference model for the _Symbol Graph_ File Format.
  
 - [Swift Markdown](https://github.com/apple/swift-markdown) is a 
  Swift package for parsing, building, editing, and analyzing 
  Markdown documents. It includes support for the Block Directive elements
  that Swift-DocC's tutorial files rely on.
   
 - [Swift-DocC-Render](https://github.com/swiftlang/swift-docc-render) 
  is a web application that understands and renders
  Swift-DocC's _render JSON_ format.
   
 - [Xcode](https://developer.apple.com/xcode/) consists of a suite of
  tools that developers use to build apps for Apple platforms.
  Beginning with Xcode 13, Swift-DocC is integrated into Xcode
  with support for building and viewing documentation for your framework and
  its dependencies.

<!-- Copyright (c) 2021-2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->

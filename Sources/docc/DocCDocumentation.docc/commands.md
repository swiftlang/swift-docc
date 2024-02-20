# Commands

Run DocC in build scripts or build workflows.

## Overview

To build documentation for your Swift package, it is recommended to use a higher level tool like the Swift Package Manager or Xcode. Those higher level tools are responsible for integrating DocC in the larger build workflow and communicating with the Swift and Clang compilers to extract information for your source code and pass that information to DocC.
To learn more about building documentation with the Swift Package Manager, see [the Swift-DocC Plugin documentation](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/).

If you are building your project using a custom build workflow, you can call the `docc` executable---that's included with the Swift toolchain---yourself from your build scripts. Note that your build scripts are also responsible for communicating with the Swift and Clang compilers to extract information for your source code and pass that information to DocC.

## Topics

### Build documentation

- ``convert``

### Locally preview documentation

- ``preview``

### Process documentation archives

- ``index``
- ``transform-for-static-hosting``

### Process documentation catalogs

- ``emit-generated-curation``

### Get started

- ``init``

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->

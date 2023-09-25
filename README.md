# Swift-DocC

Swift-DocC is a documentation compiler for Swift frameworks and packages aimed 
at making it easy to write and publish great developer documentation

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

## Getting Started with DocC

`docc` is the command line interface (CLI) for Swift-DocC and provides
support for generating and previewing documentation.

There are multiple ways you can make use of DocC depending on your use case:

**1. For documenting packages via SwiftPM:**

If you want to generate documentation for your Swift package we recommend using the Swift-DocC Plugin. Please
refer to the Plugin's [documentation](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/) to get started with 
[building](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-a-specific-target), [previewing](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/previewing-documentation),
and publishing your documentation to your [website](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-hosting-online) or [GitHub Pages](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/publishing-to-github-pages).

**2. For standalone documentation:**

If you have Xcode installed, it's recommended to generate documentation using the `xcrun` command.
You can get DocC working by invoking `xcrun docc` in your terminal.

Swift-DocC is also included in the Swift toolchain for both macOS and Linux.

To see instructions on how to use DocC from the CLI run
```
docc --help
```

**3. For documenting apps, frameworks, and packages using Xcode:**

If you want to generate an API reference for your project you can use DocC via Xcode.
Please refer to the Xcode [documentation](https://developer.apple.com/documentation/xcode/writing-documentation)
to learn the essentials of how to get started.

## Writing and Publishing Documentation with Swift-DocC

If you want to learn how to write and format your documentation please refer to
[Formatting Your Documentation Content](https://www.swift.org/documentation/docc/formatting-your-documentation-content).
For publishing go to [Distributing Documentation to Other Developers](https://www.swift.org/documentation/docc/distributing-documentation-to-other-developers).

To learn more about how Swift-DocC works internally please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Versioning

Swift-DocC's CLI tool (`docc`) is integrated into the Swift toolchain 
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
it will help us track down the bug faster..

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

The [Swift Forums](https://forums.swift.org/c/development/swift-docc) are
the best place to get help with Swift-DocC and discuss future plans.

As an open-source project, we value any contribution made to this tool.
Please see the [contributing guide](/CONTRIBUTING.md) for more information on how to 
contribute and build DocC from source.

<!-- Copyright (c) 2021-2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->

# ``SwiftDocCUtilities``

Build custom documentation workflows by leveraging the DocC compiler pipeline.

## Overview

SwiftDocCUtilities provides a default, command-line workflow for DocC, powered by Swift [Argument Parser](https://apple.github.io/swift-argument-parser/documentation/argumentparser/). `docc` commands, such as `convert` and `preview`, are conformant ``Action`` types that use DocC to perform documentation tasks.

Use SwiftDocCUtilities to build a custom, command-line interface and extend it with additional commands. To add a new sub-command called `example`, create an conformant ``Action`` type, `ExampleAction`, that performs the desired work, and add it as a sub-command. Optionally, you can also reuse any of the provided actions like ``ConvertAction``.

```swift
import ArgumentParser

public struct MyDocumentationTool: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "My custom documentation tool",
        subcommands: [ConvertAction.self, ExampleAction.self]
    )
    
    public init() {
    }
}

MyDocumentationTool.main()
```

Adding a new sub-command automatically adds routing and execution of its code, adds its description to the command-line help menu, and ensures validation for its expected arguments.

## Topics 

### Compiler Workflow
- ``Docc``
- ``ConvertAction``
- ``PreviewAction``
- ``IndexAction``

### Actions Design
- ``Action``
- ``ActionResult``
- ``RecreatingContext``

### Execution Workflow
- ``Throttle``
- ``Signal``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

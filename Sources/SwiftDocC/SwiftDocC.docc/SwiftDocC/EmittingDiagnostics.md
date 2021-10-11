# Emitting Diagnostics

Vend warnings and errors as part of an operation's result.

## Overview

When running a compilation from the command line `docc` prints all diagnostics as output. Emitting rich diagnostics is important for integrating the compilation output with automation tools or development environments.

The diagnostics emitted during discovery, loading, and processing documentation are available via the context ``DocumentationContext/problems``.

Returning a diagnostic when a callback or a method expects it is straight-forward:

```swift
let explanation = "Level-1 headings are reserved for titles."
let diagnostic = Diagnostic(
    source: sourceURL, 
    severity: .warning, 
    range: heading.range, 
    identifier: "org.swift.docc.InvalidAdditionalTitle", 
    summary: "Invalid use of level-1 heading.", 
    explanation: explanation)

return Problem(diagnostic: diagnostic, possibleSolutions: [])
```

## Topics

### Diagnostics

- ``Problem``
- ``Diagnostic``
- ``DiagnosticSeverity``
- ``DiagnosticNote``
- ``DiagnosticEngine``
- ``DiagnosticConsumer``

### Suggested Recovery Solutions

- ``Solution``
- ``Replacement``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

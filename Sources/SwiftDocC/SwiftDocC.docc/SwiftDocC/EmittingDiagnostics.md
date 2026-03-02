# Emitting Diagnostics

Vend warnings and errors as part of an operation's result.

## Overview

When running a compilation from the command line `docc` prints all diagnostics as output. Emitting rich diagnostics is important for integrating the compilation output with automation tools or development environments.

The diagnostics emitted during discovery, loading, and processing documentation are available via the context ``DocumentationContext/problems``.

## Topics

### Essentials

- <doc:Adding-Diagnostics> 

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

<!-- Copyright (c) 2021-2026 Apple Inc and the Swift Project authors. All Rights Reserved. -->

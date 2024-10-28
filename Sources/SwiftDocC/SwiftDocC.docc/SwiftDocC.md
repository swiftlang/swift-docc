# ``SwiftDocC``

Combine code comments with markup prose to produce structured, semantic documentation.

## Overview

DocC comes with built-in support for several types of input files. You organize these files by placing them in a folder with a `.docc` extension. This folder is called a documentation bundle, and can include these file types:
 
 - Lightweight markdown files that contain free-form articles or additional symbol documentation, with an `.md` extension.
 - Tutorial files that include dynamic learning content, with a `.tutorial` extension.
 - Asset files like images, videos, and archived projects for download, with known extensions like `.png`, `.jpg`, `.mov`, and `.zip`.
 - Symbol-graph files that describe the symbols of your API, with an `.symbols.json` extension.
 - An `Info.plist` file with optional metadata about the documentation.
 - A `theme-settings.json` with theming customizations for the rendered output.


## Topics 

### Essentials

- <doc:CompilerPipeline>

### Content Discovery

- <doc:InputDiscovery>
- <doc:DocumentationContextGroup>

### Resolving documentation links

- <doc:LinkResolution>

### Rendering
Converting in-memory documentation into rendering nodes and persisting them on disk as JSON.

- <doc:RenderingModel>
- <doc:PersistingDocumentation>

### Indexing

- <doc:DocumentationIndexing>

### Diagnostics and Analysis

- <doc:EmittingDiagnostics>
- <doc:StaticAnalysis>
- <doc:Benchmarking>

### Utilities and Communication

- <doc:Concurrency>
- <doc:Utilities>
- <doc:Communication>

### Development

- <doc:Features>
- <doc:AddingFeatureFlags>

<!-- Copyright (c) 2021-2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->

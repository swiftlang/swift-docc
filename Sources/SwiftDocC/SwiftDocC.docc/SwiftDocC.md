# ``SwiftDocC``

Combine code comments with markup prose to produce structured, semantic documentation.

## Overview

DocC comes with built-in support for several types of input files. You organize these files by placing them in a folder with a `.docc` extension. This folder is called a documentation bundle, and can include these file types:
 
 - Symbol-graph files, in JSON format, that describe available symbols in a framework.
 - Lightweight markdown files that contain free-form articles and more.
 - Tutorial files that include dynamic, learning content.
 - Asset files like images, videos, and archived projects for download.
 - An `Info.plist` file that contains metadata about the bundle.

SwiftDocC provides the APIs you use to load a bundle, parse the symbol-graph meta-information, extract symbol documentation, and optionally pair that symbol documentation with external file content. DocC represents the compiled documentation in an in-memory model that you can further convert in a persistable representation for writing to disk.

## Topics 

### Essentials

- <doc:CompilerPipeline>

### Content Discovery

- <doc:DocumentationWorkspaceGroup>
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

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

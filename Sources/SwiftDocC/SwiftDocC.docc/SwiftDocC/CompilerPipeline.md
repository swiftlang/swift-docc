# The Swift-DocC Pipeline

Get to know the steps involved in documentation compilation.

## Overview

This article describes the discrete and sequential steps of compiling documentation with DocC.

DocC starts with input discovery by categorizing the documentation sources in your documentation catalog. Next, it loads and parses the those inputs to create in-memory models of the documentation pages. Once the in-memory model is finalized, DocC converts each topic into a persistable, render-friendly representation it can store on disk.

### Discovery

DocC starts by creating a ``DocumentationContext/InputsProvider`` to discover the inputs from the user-provided command line arguments. These inputs are:

 - Markup files, tutorial files, and assets (for example images)
 - Symbol graph files, describing the symbols in a given module (types, functions, variables, etc.) and their relationships (inheritance, conformance, etc.)
 - Meta information about this "unit" of documentation (for example a custom display name)
 - Customizations to the render template.

Markup, tutorials, assets, and render-template-customization can only be discovered as files inside of a documentation catalog (`.docc` directory).
Symbol graph files can either be discovered as files inside of a documentation catalog or as additional files provided via user-provided command line arguments.
Meta information can either be discovered from an optional top-level `Info.plist` file inside of a documentation catalog or as provided values via user-provided command line arguments. All meta information is optional.

You can organize the files inside the documentation catalog according to your preference, 
as long as the optional `Info.plist`--containing optional meta information--and the optional render customization files are top-level.
For example, this catalog groups files based on their topic with an additional directory for shared asset files:

```none
SwiftDocC.docc
├ Info.plist
├ SwiftDocC.md
├ SwiftDocC.symbols.json
├ Essentials
│ ├ ActionManager.md
│ ├ Action.md
│ ╰ Getting Started with SwiftDocC.md
├ Migration to DocC
│ ├ DocumentationContext.md
│ ╰ ...
╰ Shared Assets
  ├ Diagram@2x.png
  ├ Diagram@3x.png
  ├ ...
  ╰ Overview.mov
```

### Analysis and Registration

This phase starts with creating a ``DocumentationContext`` using the discovered inputs from the previous phase. 
This begins loading and registering the inputs with the context.

The first input that the context registers is the symbol information. The symbol information comes from "symbol graph files" which are machine generated and describe all available symbols in a framework (types, functions, variables, etc.) and their relationships (inheritance, conformance, etc.).

Each symbol becomes a documentation node in the topic graph and thus a documentation *topic* (an entity in the documentation model). The symbol's topic could optionally be extended with authored documentation from a markup file.

> Note: For Swift projects use the Swift compiler to produce a symbol-graph file for your code.

Next, all the remaining markup files are analyzed and converted to documents (for example articles and tutorials) and are added to the topic graph as well.

Finally, if you reference any symbols from another framework, and DocC knows how to resolve those, the symbols are fetched and added to the graph too.

#### Curation

At this point the in-memory topic graph accurately represents the machine generated description of the documented framework. However, documentation is often better consumed when it's curated into logical groups and into an incremental learning experience.

Authors, therefore, can curate documentation topics into a custom learning and discovery experience, independent of the actual framework structure. They are able to do that by adding *Topics* and *See Also* sections to any article or authored symbol documentation.

During this phase of the compilation a crawler starts at each documentation root topic and descends through any authored topic groups, curating any linked symbols as children of the current topic.

The phase ends with automatic curation for any symbols that haven't been curated manually. The documentation topic graph is complete and DocC tries to resolve all references to detect any potentially dead links.

You can, at this point, query the in-memory model via ``DocumentationContext`` to fetch symbol data and explore various relationships between the model nodes.

### Rendering

To render the in-memory model on disk, DocC converts each ``DocumentationNode`` to a ``RenderNode`` using a ``RenderNodeTranslator``. A render node represents the data needed to render the documentation for a single topic. This includes hierarchy information, meta information, resolved documentation links, linked symbols, and processed markup.

`JSONEncodingRenderNodeWriter` encodes the resulting render nodes into JSON and writes them on disk.

The file hierarchy under the output path represents the complete, compiled documentation; each JSON file documenting a single topic in its entirety:

```none
.docc-build
├ data
│ ╰ documentation
│   ├ SwiftDocC.json
│   ╰ SwiftDocC
│     ├ Article.json
│     ├ Article
│     │ ├ ==(_:_:).json
│     │ ├ abstract.json
│     │ ├ accept(_:).json
│     │ ├ Analyses.json
│     │ ├ discussion.json
│     │ ├ dump().json
│     │ ├ init().json
│     │ ╰ ...
│     ├ ArticleSection.json
│     ├ ArticleSection
│     │ ╰ ...
│     ╰ ...
├ downloads
├ images
╰ videos
```

<!-- Copyright (c) 2021-2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->

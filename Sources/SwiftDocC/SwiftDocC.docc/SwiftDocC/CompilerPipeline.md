# The Swift-DocC Pipeline

Get to know the steps involved in documentation compilation.

## Overview

This article describes the discrete and sequential steps of compiling documentation with DocC.

DocC starts with content discovery by parsing the documentation sources in your documentation bundle. Next, it validates and semantically analyzes them and then builds an in-memory model of the compiled documentation. Once the in-memory model is finalized, DocC converts each topic into a persistable representation it can store on disk.

To use the compiled documentation, either query the in-memory model directly or convert its nodes to their render-friendly representation. For example, the `SwiftDocCUtilities` framework enumerates all the nodes in DocC's in-memory model, converts each node for rendering, and finally writes the complete documentation to the disk.

### Discovery

DocC starts discovery by creating a ``DocumentationWorkspace`` to interact with the file system and a ``DocumentationContext`` that manages the in-memory model for the built documentation.

When a documentation bundle is found in the workspace by a ``DocumentationWorkspaceDataProvider``, the following files are recognized and processed (others are ignored):

- An `Info.plist` file containing meta information like the bundle display name.
- Symbol-graph files with the `.symbols.json` extension.
- Authored markup files with an `.md` extension
- Authored tutorial files with a `.tutorial` extension
- Additional documentation assets with known extensions like `.png`, `.jpg`, `.mov`, and `.zip`.

You can organize the files in any way, as long as `Info.plist` is in the root of the directory tree. Here is an example of a bundle, that groups topic files in logical groups with an additional directory for shared asset files:

```none
SwiftDocC.docc
├ Info.plist
├ SwiftDocC.md
├ SwiftDocC.symbols.json
├ Essentials
│ ├ ActionManager.md
│ ├ Action.md
│ ╰ Getting Started with SwiftDocCUtilities.md
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

This phase starts with registering all symbols from the available symbol graphs into a documentation *topic graph* in memory. 

The symbol graph files are machine generated and describe all available symbols in a framework (types, functions, variables, etc.) and their relationships, for example, inheritance and conformance.

Each symbol becomes a documentation node in the topic graph and thus a documentation *topic* (an entity in the documentation model). The symbol's topic could optionally be extended with authored documentation from a markup file.

> Note: For Swift projects use the Swift compiler to produce a symbol-graph file for your code.

Next, all the remaining markup files are analyzed and converted to documents (for example articles and tutorials) and are added to the topic graph as well.

Finally, if you reference any symbols from another framework, and DocC knows how to resolve those, the symbols are fetched and added to the graph too.

### Curation

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

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

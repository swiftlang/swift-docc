# Rendering Model

Convert documentation nodes into render nodes and save them to disk.

## Overview

A representation of the in-memory model's documentation nodes when compiled into self-contained rendering nodes.

A documentation node represents a single documentation topic and it might reference a variety of resources within the documentation context. Unlike a documentation node, a rendering node is a self-contained entity that includes any and all data necessary to display a single page of documentation.

Hereto a rendering node contains data not only about a single specific topic (a tutorial, an article, or a framework symbol) but also data about its hierarchy in the documentation bundle, the titles and abstracts of any linked symbols, and any other metadata needed to display a single documentation page.

``RenderNodeTranslator`` is the type that converts a ``DocumentationNode`` into a ``RenderNode`` and ``PresentationURLGenerator`` is the one that automatically determines the location of the resulting rendering node within the compiled documentation.

## Topics

### Render Nodes

- ``RenderNodeTranslator``
- ``RenderNode``
- ``RenderTree``
- ``RenderSection``
- ``RenderSectionKind``
- ``RenderMetadata``
- ``RenderHierarchy``

### Render Node URLs

- ``PresentationURLGenerator``

### Render Elements

- ``RenderBlockContent``
- ``RenderInlineContent``
- ``RenderContentMetadata``

### Semantic Structures

- <doc:SymbolReferenceRendering>
- <doc:TutorialsRendering>

### References

- ``RenderReference``
- ``RenderReferenceCache``
- ``URLReference``
- ``RenderReferenceType``

### Reference Types

- ``FileReference``
- ``FileTypeReference``
- ``ImageReference``
- ``LinkReference``
- ``MediaReference``
- ``RenderReferenceIdentifier``
- ``TopicRenderReference``
- ``UnresolvedRenderReference``
- ``VideoReference``

### Variants

- ``RenderNode/variantOverrides``
- ``VariantOverrides``
- ``VariantOverride``
- ``VariantCollection``
- ``VariantContainer``
- ``VariantPatchOperation``
- ``JSONPatch``
- ``JSONPatchOperation``
- ``JSONPointer``

### Others

- ``SemanticVersion``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

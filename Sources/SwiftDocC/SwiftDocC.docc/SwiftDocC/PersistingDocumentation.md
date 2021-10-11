# Persisting Documentation

Save compiled documentation to disk.

## Overview

Once the in-memory documentation model is finalized each of its graph nodes can be converted to a rendering node and persisted on disk or elsewhere via the `Codable` protocol.

The ``Converter`` type converts documentation nodes to rendering nodes:

```swift
let converter = DocumentationNodeConverter(bundle: myBundle, context: myContext)
let renderNode = converter.convert(documentationNode, 
    at: sourceURL, from: bundle)
```

The render nodes can be persisted on disk as JSON files via `JSONEncodingRenderNodeWriter`:

```swift
let writer = JSONEncodingRenderNodeWriter(targetFolder: outputURL, 
    fileManager: FileManager.default)
try writer.write(renderNode)
```

The precise path inside the output folder where resulting JSON file is saved is automatically determined by the node type (article, symbol reference, etc.).

## Topics

### Node Persistence

- ``Converter``
- ``LinkDestinationSummary``

### Render Node Rewriter

- ``RenderNodeTransforming``
- ``RemoveAutomaticallyCuratedSeeAlsoSectionsTransformation``
- ``RemoveUnusedReferencesTransformation``
- ``RenderNodeTransformationComposition``
- ``RenderNodeTransformationContext``
- ``RenderNodeTransformer``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

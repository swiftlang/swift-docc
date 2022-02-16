# Documentation Context

Build and query the in-memory documentation model.

## Discussion

The documentation context generally manages the in-memory documentation including:
 
 - Analyzing bundle file contents and converting to semantic models.
 - Managing a graph of documentation nodes (a single node representing one documentation topic).
 - Processing assets like media files or download archives.
 - Resolving links to external documentation via ``ExternalReferenceResolver`` and resolving external symbols via ``ExternalSymbolResolver``.
 - Random access to documentation data including walking the graph and path finding.

### Creating a Context

```swift
let workspace = DocumentationWorkspace()
let context = try DocumentationContext(dataProvider: workspace)
```

During initialization the context will inspect the available bundles in the workspace and load any symbol graph files and markup files.

### Accessing Documentation

Use ``DocumentationContext/entity(with:)`` to access a documentation node by its topic reference:

```swift
let reference = ResolvedTopicReference(
    bundleIdentifier: "com.mybundle",
    path: "/documentation/ValidationKit/EmailValidator",
    fragment: nil,
    sourceLanguage: .swift)
let node = try context.entity(with: reference)
```

To find out the location of the source file for a given documentation node use:

```swift
let sourceFileURL = try context.documentURL(for: reference)
```

And finally to print all known paths in the context:

```swift
context.knownIdentifiers.forEach({ print($0) })
```

## Topics

### Documentation Context

- ``DocumentationContext``
- ``DocumentationContextDataProvider``
- ``DocumentationContextDataProviderDelegate``
- ``AutomaticCuration``

### Documentation Nodes

- ``DocumentationNode``
- ``Section``
- ``TaskGroup``
- ``TopicReference``
- ``ResourceReference``
- ``SymbolReference``

### Rendering URLs

- ``NodeURLGenerator``

### External Documentation

- ``ExternalReferenceResolver``
- ``ExternalSymbolResolver``
- ``OutOfProcessReferenceResolver``

### Code Listings

- ``AttributedCodeListing``
- ``UnresolvedCodeListingReference``
- ``CodeColorsPreferenceKey``
- ``SRGBColor``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

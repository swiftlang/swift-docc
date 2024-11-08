# Documentation Context

Build and query the in-memory documentation model.

## Discussion

A documentation context is the the in-memory representation of a "unit" of documentation (for example a module, package, or technology). 
The context is generally responsible for:

 - Analyzing bundle file contents and converting to semantic models.
 - Managing a graph of documentation nodes (a single node representing one documentation topic).
 - Processing assets like media files or download archives.
 - Resolving links to external documentation sources via ``ExternalDocumentationSource`` and resolving external symbols via ``GlobalExternalSymbolResolver``.
 - Random access to documentation data including walking the graph and path finding.

### Creating a Context

Use ``DocumentationContext/init(bundle:dataProvider:diagnosticEngine:configuration:)`` to create a context for a given bundle:

```swift
let inputsProvider = DocumentationContext.InputsProvider()
let (bundle, dataProvider) = try inputsProvider.inputsAndDataProvider(
    startingPoint: catalogURL, 
    options: bundleDiscoveryOptions
)

let context = try DocumentationContext(bundle: bundle, dataProvider: dataProvider)
```

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

## Topics

### Documentation Context

- ``DocumentationContext``
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

### External Documentation Sources

- ``ExternalDocumentationSource``
- ``GlobalExternalSymbolResolver``
- ``OutOfProcessReferenceResolver``

### Code Listings

- ``AttributedCodeListing``
- ``UnresolvedCodeListingReference``
- ``CodeColorsPreferenceKey``
- ``SRGBColor``

<!-- Copyright (c) 2021-2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->

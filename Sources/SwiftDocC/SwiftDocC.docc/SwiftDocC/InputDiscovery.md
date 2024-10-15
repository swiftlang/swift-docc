# Input Discovery

Learn how to discover documentation inputs on the file system.

## Discussion

A ``DocumentationContext/InputsProvider`` discovers documentation catalogs on the file system and creates a ``DocumentationBundle`` from the discovered catalog content.

```swift
let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)

guard let catalogURL = try inputProvider.findCatalog(startingPoint: startingPoint) else {
    return
}
let bundle = try inputProvider.makeInputs(contentOf: catalogURL, options: BundleDiscoveryOptions())

print("A bundle with ID: \(bundle.identifier)")
```

You can also create documentation inputs, without a documentation catalog, from a list of symbol graph files: 

```swift
let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)

guard let (bundle, dataProvider) = try inputProvider.makeInputsFromSymbolGraphs(
    options: BundleDiscoveryOptions(
        additionalSymbolGraphFiles: listOfSymbolGraphLocations
    )
) else {
    return
}

print("A bundle with ID: \(bundle.identifier)")
```

> Note: use the returned `dataProvider` to create a ``DocumentationContext`` from this ``DocumentationBundle``. 

It's common to want combine these two strategies and require that they discover a ``DocumentationBundle``. 
For this use-case, use the
``DocumentationContext/InputsProvider/inputsAndDataProvider(startingPoint:allowArbitraryCatalogDirectories:options:)`` method:

```swift
let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)

let (bundle, dataProvider) = try inputProvider.inputsAndDataProvider(
    startingPoint: maybeStartingPoint,
    options: BundleDiscoveryOptions(
        additionalSymbolGraphFiles: listOfSymbolGraphLocations
    )
)

print("A bundle with ID: \(bundle.identifier)")
```

### Bundle Contents

A ``DocumentationBundle`` represents the list of "discovered" input files--categorized by their kind--to use as documentation inputs.

Use a ``DataProvider`` that the ``DocumentationContext/InputsProvider`` returned alongside the bundle to read the files in the bundle.

## Topics

### Input Discovery

- ``DocumentationContext/InputsProvider``
- ``DocumentationContext/InputsProvider/inputsAndDataProvider(startingPoint:allowArbitraryCatalogDirectories:options:)``

### Documentation Bundle

- ``DocumentationBundle``
- ``BundleIdentifier``
- ``DocumentationBundleFileTypes``

### Bundle Assets

- ``DataTraitCollection``
- ``DataAsset``
- ``BundleData``

### Bundle Metadata

- ``ExternalMetadata``
- ``DefaultAvailability``
- ``PlatformVersion``

<!-- Copyright (c) 2021-2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->

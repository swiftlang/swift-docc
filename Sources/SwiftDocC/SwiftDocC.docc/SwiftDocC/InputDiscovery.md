# Input Discovery

Learn how to discover documentation inputs on the file system.

## Discussion

A ``DocumentationContext/InputsProvider`` discovers documentation catalogs on the file system and creates a ``DocumentationContext/Inputs`` from the discovered catalog content.

```swift
let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)

guard let catalogURL = try inputProvider.findCatalog(startingPoint: startingPoint) else {
    return
}
let inputs = try inputProvider.makeInputs(contentOf: catalogURL, options: CatalogDiscoveryOptions())

print("Documentation inputs with ID: \(inputs.identifier)")
```

You can also create documentation inputs, without a documentation catalog, from a list of symbol graph files: 

```swift
let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)

guard let (inputs, dataProvider) = try inputProvider.makeInputsFromSymbolGraphs(
    options: CatalogDiscoveryOptions(
        additionalSymbolGraphFiles: listOfSymbolGraphLocations
    )
) else {
    return
}

print("Documentation inputs with ID: \(inputs.identifier)")
```

> Note: use the returned `dataProvider` to create a ``DocumentationContext`` from this ``DocumentationContext/Inputs``. 

It's common to want combine these two strategies and require that they discover a ``DocumentationContext/Inputs``. 
For this use-case, use the
``DocumentationContext/InputsProvider/inputsAndDataProvider(startingPoint:allowArbitraryCatalogDirectories:options:)`` method:

```swift
let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)

let (inputs, dataProvider) = try inputProvider.inputsAndDataProvider(
    startingPoint: maybeStartingPoint,
    options: CatalogDiscoveryOptions(
        additionalSymbolGraphFiles: listOfSymbolGraphLocations
    )
)

print("Documentation inputs with ID: \(inputs.identifier)")
```

### Input files

A ``DocumentationContext/Inputs`` represents the list of "discovered" input files--categorized by their kind--to use as documentation inputs.

Use a ``DataProvider`` that the ``DocumentationContext/InputsProvider`` returned alongside the inputs to its files.

## Topics

### Input Discovery

- ``DocumentationContext/InputsProvider``
- ``DocumentationContext/InputsProvider/inputsAndDataProvider(startingPoint:allowArbitraryCatalogDirectories:options:)``

### Inputs

- ``DocumentationContext/Inputs``
- ``DocumentationContext/Inputs/Identifier``
- ``DocumentationInputFileTypes``

### Assets

- ``DataTraitCollection``
- ``DataAsset``
- ``BundleData``

### Inputs Metadata

- ``ExternalMetadata``
- ``DefaultAvailability``
- ``PlatformVersion``

<!-- Copyright (c) 2021-2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->

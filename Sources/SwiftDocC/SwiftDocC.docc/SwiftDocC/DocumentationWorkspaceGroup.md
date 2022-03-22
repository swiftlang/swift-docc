# Catalog Discovery

Learn how to explore a documentation workspace and discover catalogs.

## Discussion

A ``DocumentationWorkspace`` manages a list of data providers that discover, register, and provide data access to documentation catalogs. The data provider protocol ``DocumentationWorkspaceDataProvider`` does not make any assumptions regarding the documentation storage medium as long as the provider can identify those resources by their `URL`.

A common case is to use the pre-defined ``LocalFileSystemDataProvider`` that loads any documentation catalogs found in a given directory on disk:

```swift
let workspace = DocumentationWorkspace()
let dataProvider = try LocalFileSystemDataProvider(rootURL: sourceDirectoryURL)
try workspace.registerProvider(dataProvider)

guard let firstCatalog = workspace.catalogs.values.first else {
  fatalError("No documentation catalog found")
}

print("A catalog with ID: \(firstCatalog.identifier)")

print("Symbol graph files:")
print(firstCatalog.symbolGraphURLs)
```

### Catalog Contents

A ``DocumentationCatalog`` offers the information needed to load its contents into memory for processing. A catalog is uniquely identified by its ``CatalogIdentifier`` identifier.

Use the catalog data to load symbol graphs, markup files, assets like images or videos, and catalog metadata.

```swift
catalog.miscResourceURLs
    .filter { $0.lastPathComponent.hasSuffix(".zip") }
    .forEach {
      print("Download archive: \($0.lastPathComponent)")
    }
```

## Topics

### Workspaces

- ``DocumentationWorkspace``
- ``DocumentationWorkspaceDataProvider``

### File Data Providers

- ``FileSystemProvider``
- ``LocalFileSystemDataProvider``
- ``PrebuiltLocalFileSystemDataProvider``
- ``FSNode``

### Documentation Catalogs

- ``DocumentationCatalog``
- ``CatalogIdentifier``
- ``DocumentationCatalogFileTypes``

### Catalog Assets

- ``DataTraitCollection``
- ``DataAsset``
- ``CatalogData``

### Catalog Metadata

- ``ExternalMetadata``
- ``DefaultAvailability``
- ``PlatformVersion``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

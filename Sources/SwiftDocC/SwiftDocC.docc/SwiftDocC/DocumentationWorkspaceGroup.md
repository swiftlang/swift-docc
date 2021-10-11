# Bundle Discovery

Learn how to explore a documentation workspace and discover bundles.

## Discussion

A ``DocumentationWorkspace`` manages a list of data providers that discover, register, and provide data access to documentation bundles. The data provider protocol ``DocumentationWorkspaceDataProvider`` does not make any assumptions regarding the documentation storage medium as long as the provider can identify those resources by their `URL`.

A common case is to use the pre-defined ``LocalFileSystemDataProvider`` that loads any documentation bundles found in a given directory on disk:

```swift
let workspace = DocumentationWorkspace()
let dataProvider = try LocalFileSystemDataProvider(rootURL: sourceDirectoryURL)
try workspace.registerProvider(dataProvider)

guard let firstBundle = workspace.bundles.values.first else {
  fatalError("No documentation bundle found")
}

print("A bundle with ID: \(firstBundle.identifier)")

print("Symbol graph files:")
print(firstBundle.symbolGraphURLs)
```

### Bundle Contents

A ``DocumentationBundle`` offers the information needed to load its contents into memory for processing. A bundle is uniquely identified by its ``BundleIdentifier`` identifier.

Use the bundle data to load symbol graphs, markup files, assets like images or videos, and bundle metadata.

```swift
bundle.miscResourceURLs
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

### Documentation Bundles

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

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->

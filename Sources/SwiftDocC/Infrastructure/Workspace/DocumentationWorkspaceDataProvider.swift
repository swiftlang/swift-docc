/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that vends catalogs and responds to requests for data.
public protocol DocumentationWorkspaceDataProvider {
    /// A string that uniquely identifies this data provider.
    ///
    /// Unless your implementation needs a stable identifier to associate with an external system, it's reasonable to
    /// use `UUID().uuidString`  for the provider's identifier.
    var identifier: String { get }

    /// Returns the data backing one of the files that this data provider provides.
    ///
    /// Your implementation can expect to only receive URLs that it provides. It's acceptable to assert if you receive
    /// a URL that wasn't provided by your data provider, because this indicates a bug in the ``DocumentationWorkspace``.
    ///
    /// - Parameter url: The URL of a file to return the backing data for.
    func contentsOfURL(_ url: URL) throws -> Data
    
    /// Returns the documentation catalogs that your data provider provides.
    ///
    /// - Parameter options: Configuration that controls how the provider discovers documentation catalogs.
    ///
    /// If your data provider also conforms to ``FileSystemProvider``, there is a default implementation of this method
    /// that traverses the ``FileSystemProvider/fileSystem`` to find all documentation catalogs in it.
    func catalogs(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog]
}

public extension DocumentationWorkspaceDataProvider {
    /// Returns the documentation catalogs that your data provider provides; discovered with the default options.
    ///
    /// If your data provider also conforms to ``FileSystemProvider``, there is a default implementation of this method
    /// that traverses the ``FileSystemProvider/fileSystem`` to find all documentation catalogs in it.
    func catalogs() throws -> [DocumentationCatalog] {
        return try catalogs(options: CatalogDiscoveryOptions())
    }
    
    @available(*, deprecated, renamed: "catalogs()")
    func bundles() throws -> [DocumentationCatalog] {
        return try catalogs()
    }
}

/// Options to configure the discovery of documentation catalogs
public struct CatalogDiscoveryOptions {
    // When adding new configuration, remember to include a default value in the initializer so that an options
    // value can be created without passing any arguments, resulting in the "default" configuration.
    //
    // The provider uses the default configuration in the `DocumentationWorkspaceDataProvider.catalogs()` function.
    
    /// Fallback values for information that's missing in the catalog's Info.plist file.
    public let infoPlistFallbacks: [String: Any]
    
    /// Additional symbol graph files that the provider should include in the discovered catalogs.
    public let additionalSymbolGraphFiles: [URL]
    
    /// Creates a new options value with the given configurations.
    ///
    /// - Parameters:
    ///   - infoPlistFallbacks: Fallback values for information that's missing in the catalog's Info.plist file.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files that the provider should include in the discovered catalogs.
    public init(
        infoPlistFallbacks: [String: Any] = [:],
        additionalSymbolGraphFiles: [URL] = []
    ) {
        self.infoPlistFallbacks = infoPlistFallbacks
        self.additionalSymbolGraphFiles = additionalSymbolGraphFiles
    }
    
    /// Creates new catalog discovery options with the provided documentation catalog info
    /// as Info.plist fallback values.
    ///
    /// - Parameters:
    ///   - fallbackInfo: Fallback documentation catalog information to use if any discovered catalogs are missing an Info.plist.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files to augment any discovered catalogs.
    public init(
        fallbackInfo: DocumentationCatalog.Info,
        additionalSymbolGraphFiles: [URL] = []
    ) throws {
        // Use JSONEncoder to dynamically create the Info.plist fallback
        // dictionary the `CatalogDiscoveryOption`s expect from given DocumentationCatalog.Info
        // model.
        
        let data = try JSONEncoder().encode(fallbackInfo)
        let serializedFallbackInfo = try JSONSerialization.jsonObject(with: data)
        
        guard let fallbackInfoDictionary = serializedFallbackInfo as? [String: Any] else {
            throw DocumentationCatalog.Info.Error.wrongType(
                expected: [String: Any].Type.self,
                actual: type(of: serializedFallbackInfo)
            )
        }
        
        self.init(
            infoPlistFallbacks: fallbackInfoDictionary,
            additionalSymbolGraphFiles: additionalSymbolGraphFiles
        )
    }
}

@available(*, deprecated, renamed: "CatalogDiscoveryOptions")
public typealias BundleDiscoveryOptions = CatalogDiscoveryOptions
